//
//  SonosCloudLiveClient.swift
//  SonosSDK
//
//  Real-time state for one household through the Sonos cloud, for apps that
//  may not use the players' local API. The current state comes from the
//  Control API; changes come from the integration's event subscriptions,
//  which Sonos posts to the app's event server and the server relays back
//  over a WebSocket (`SonosEventRelaying`).
//
//  Every (re)connection subscribes again and reads the state once, because
//  events don't replay what happened while disconnected. Only the groups and
//  players in focus are subscribed and read, which keeps the app well inside
//  Sonos' quota of 1,000 requests a minute for all its users together.
//
//  A player counts as connected while events for it can reach the app: the
//  relay is open and the player is in focus (or shares a group with one).
//

import Foundation

public actor SonosCloudLiveClient {

    public nonisolated let householdId: String
    /// Single-consumer stream of state changes. Ends after `stop()`.
    public nonisolated let events: AsyncStream<SonosLiveEvent>

    private let eventContinuation: AsyncStream<SonosLiveEvent>.Continuation
    private let cloud: HTTPClientProtocol
    private let relay: any SonosEventRelaying
    private let token: @Sendable () async throws -> String
    private let configuration: SonosLiveConfiguration

    private var groups: [Group] = []
    private var players: [Player] = []
    private var runTask: Task<Void, Never>?
    private var isSuspended = false
    private var isOpen = false
    /// Subscriptions made on the current connection, as "namespace@target".
    private var subscribed: Set<String> = []
    /// Players announced as connected on the current connection.
    private var announced: Set<String> = []
    /// Last sequence number per "namespace@target", to drop late events.
    private var lastSeq: [String: Int] = [:]

    /// - Parameter token: A valid Sonos access token, refreshed as needed.
    init(householdId: String, cloud: HTTPClientProtocol, relay: any SonosEventRelaying,
         token: @escaping @Sendable () async throws -> String, configuration: SonosLiveConfiguration) {
        self.householdId = householdId
        self.cloud = cloud
        self.relay = relay
        self.token = token
        self.configuration = configuration
        (events, eventContinuation) = AsyncStream.makeStream(of: SonosLiveEvent.self)
    }

    // MARK: - Lifecycle

    public func start(groups: [Group], players: [Player]) {
        self.groups = groups
        self.players = players
        run()
    }

    public func stop() {
        runTask?.cancel()
        runTask = nil
        isOpen = false
        eventContinuation.finish()
    }

    /// Closes the relay but keeps the state (app in the background).
    public func suspend() {
        guard !isSuspended else { return }
        isSuspended = true
        runTask?.cancel()
        runTask = nil
        closeConnection(as: .suspended)
    }

    /// Reconnects after `suspend()`, subscribes again and reads the current state.
    public func resume() {
        guard isSuspended else { return }
        isSuspended = false
        run()
    }

    private func run() {
        runTask?.cancel()
        runTask = Task { [weak self] in await self?.loop() }
    }

    private func loop() async {
        var failures = 0
        while !Task.isCancelled {
            do {
                let token = try await token()
                for try await message in relay.connect(token: token) {
                    switch message {
                    case .opened:
                        failures = 0
                        isOpen = true
                        log("relay open")
                        await refreshTopology()
                    case .event(let data):
                        await handle(data)
                    }
                }
                log("relay closed")
            } catch {
                log("relay failed: \(error.localizedDescription)")
            }
            guard !Task.isCancelled else { return }
            failures += 1
            let delay = min(configuration.initialReconnectDelay * pow(2, Double(failures - 1)), configuration.maxReconnectDelay)
            closeConnection(as: .disconnected(retryIn: delay))
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }

    private func closeConnection(as state: SonosLiveConnectionState) {
        isOpen = false
        subscribed = []
        lastSeq = [:]
        for playerId in announced {
            emit(.connection(playerId: playerId, state: state))
        }
        announced = []
    }

    // MARK: - Focus

    private func inFocus(_ group: Group) -> Bool {
        guard let focus = configuration.focusPlayerIds else { return true }
        return group.playerIds.contains(where: focus.contains)
    }

    private func inFocus(_ player: Player) -> Bool {
        configuration.focusPlayerIds?.contains(player.id) ?? true
    }

    /// Players whose events reach the app: the focus and everyone grouped with it.
    private var reachablePlayerIds: Set<String> {
        var ids = Set(players.filter(inFocus).map(\.id))
        for group in groups where inFocus(group) {
            ids.formUnion(group.playerIds)
        }
        return ids
    }

    // MARK: - Topology

    private func refreshTopology() async {
        await subscribe(.subscribeToGroups(householdId: householdId), key: "groups@\(householdId)")
        do {
            let response: GroupsResponse = try await cloud.request(.getGroups(householdId: householdId))
            await applyTopology(groups: response.groups, players: response.players)
        } catch {
            log("getGroups failed: \(error.localizedDescription)")
        }
    }

    private func applyTopology(groups newGroups: [Group], players newPlayers: [Player]) async {
        groups = newGroups
        players = newPlayers
        emit(.topology(groups: newGroups, players: newPlayers))
        guard isOpen else { return }

        let reachable = reachablePlayerIds
        for playerId in announced.subtracting(reachable) {
            emit(.connection(playerId: playerId, state: .disconnected(retryIn: nil)))
        }
        for playerId in reachable.subtracting(announced) {
            emit(.connection(playerId: playerId, state: .connected))
        }
        announced = reachable

        for group in newGroups where inFocus(group) {
            await follow(group)
        }
        for player in newPlayers where inFocus(player) {
            await follow(player)
        }
    }

    /// Subscribes to a group's playback, metadata and volume and reads them once.
    private func follow(_ group: Group) async {
        let groupId = group.id
        if await subscribe(.subscribeToPlayback(groupId: groupId), key: "playback@\(groupId)"),
           let status: PlaybackStatus = await read(.getPlaybackStatus(groupId: groupId)) {
            emit(.playbackStatus(groupId: groupId, status: status))
        }
        if await subscribe(.subscribeToPlaybackMetadata(groupId: groupId), key: "playbackMetadata@\(groupId)"),
           let metadata: PlaybackMetadata = await read(.getMetadataStatus(groupId: groupId)) {
            emit(.metadataStatus(groupId: groupId, metadata: metadata))
        }
        if await subscribe(.subscribeToGroupVolume(groupId: groupId), key: "groupVolume@\(groupId)"),
           let volume: GroupVolume = await read(.getGroupVolume(groupId: groupId)) {
            emit(.groupVolume(groupId: groupId, volume: volume))
        }
    }

    private func follow(_ player: Player) async {
        let playerId = player.id
        if await subscribe(.subscribeToPlayerVolume(playerId: playerId), key: "playerVolume@\(playerId)"),
           let volume: PlayerVolume = await read(.getPlayerVolume(playerId: playerId)) {
            emit(.playerVolume(playerId: playerId, volume: volume))
        }
    }

    /// True when the subscription is new on this connection (and succeeded).
    @discardableResult
    private func subscribe(_ endpoint: SonosAPIEndpoint, key: String) async -> Bool {
        guard !subscribed.contains(key) else { return false }
        do {
            try await cloud.request(endpoint)
            subscribed.insert(key)
            return true
        } catch {
            log("subscribe \(key) failed: \(error.localizedDescription)")
            return false
        }
    }

    private func read<T: Decodable>(_ endpoint: SonosAPIEndpoint) async -> T? {
        do {
            return try await cloud.request(endpoint)
        } catch {
            log("read \(endpoint) failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Events

    private func handle(_ data: Data) async {
        guard let event = SonosRelayedEvent(data), event.householdId == householdId else { return }
        let key = "\(event.type)@\(event.targetValue)"
        if event.seq > 0 {
            if let last = lastSeq[key], event.seq <= last { return }
            lastSeq[key] = event.seq
        }
        do {
            switch event.type {
            case "groups":
                let body = try event.decodeBody(GroupsResponse.self)
                await applyTopology(groups: body.groups, players: body.players)
            case "playbackStatus":
                emit(.playbackStatus(groupId: event.targetValue, status: try event.decodeBody(PlaybackStatus.self)))
            case "metadataStatus":
                emit(.metadataStatus(groupId: event.targetValue, metadata: try event.decodeBody(PlaybackMetadata.self)))
            case "groupVolume":
                emit(.groupVolume(groupId: event.targetValue, volume: try event.decodeBody(GroupVolume.self)))
            case "playerVolume":
                emit(.playerVolume(playerId: event.targetValue, volume: try event.decodeBody(PlayerVolume.self)))
            case "playbackError":
                let body = try event.decodeBody(SonosLocalFrameCodec.ErrorBody.self)
                emit(.playbackError(groupId: event.targetValue, errorCode: body.errorCode, reason: body.reason))
            case "groupCoordinatorChanged":
                await refreshTopology()
            default:
                break
            }
        } catch {
            log("dropped \(event.type) event: \(error.localizedDescription)")
        }
    }

    private func emit(_ event: SonosLiveEvent) {
        eventContinuation.yield(event)
    }

    private func log(_ message: String) {
        configuration.logger?("[Sonos cloud] \(message)")
    }
}
