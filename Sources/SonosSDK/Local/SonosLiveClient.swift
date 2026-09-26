//
//  SonosLiveClient.swift
//  SonosSDK
//
//  Real-time state for one household over the players' local WebSockets.
//
//  Routing rules of the local API:
//  - group namespaces (playback, playbackMetadata, groupVolume) only work on
//    the socket of the group's coordinator,
//  - playerVolume only works on the player's own socket,
//  - groups (household) works on any socket.
//  The client keeps one socket per player, places every subscription on the
//  right socket, moves them when the topology changes, and re-subscribes
//  (plus fetches a fresh snapshot) after every reconnect. State is delivered
//  through `events`.
//

import Foundation

/// A state change pushed by a player.
public enum SonosLiveEvent: Sendable {
    /// Current groups and players of the household.
    case topology(groups: [Group], players: [Player])
    case playbackStatus(groupId: String, status: PlaybackStatus)
    case metadataStatus(groupId: String, metadata: PlaybackMetadata)
    case groupVolume(groupId: String, volume: GroupVolume)
    case playerVolume(playerId: String, volume: PlayerVolume)
    case playbackError(groupId: String, errorCode: String, reason: String?)
    /// Connection state of one player's socket.
    case connection(playerId: String, state: SonosLiveConnectionState)
}

struct SonosLiveSubscription: Hashable, Sendable {
    let namespace: String
    let target: SonosLocalTarget

    static func groups(_ householdId: String) -> Self { .init(namespace: "groups", target: .household(householdId)) }
    static func playback(_ groupId: String) -> Self { .init(namespace: "playback", target: .group(groupId)) }
    static func metadata(_ groupId: String) -> Self { .init(namespace: "playbackMetadata", target: .group(groupId)) }
    static func groupVolume(_ groupId: String) -> Self { .init(namespace: "groupVolume", target: .group(groupId)) }
    static func playerVolume(_ playerId: String) -> Self { .init(namespace: "playerVolume", target: .player(playerId)) }
}

public actor SonosLiveClient {

    public nonisolated let householdId: String
    /// Single-consumer stream of state changes. Ends after `stop()`.
    public nonisolated let events: AsyncStream<SonosLiveEvent>

    private let eventContinuation: AsyncStream<SonosLiveEvent>.Continuation
    private let apiKey: String
    private let factory: any SonosLocalTransportFactory
    private let configuration: SonosLiveConfiguration

    private var isRunning = false
    private var isSuspended = false
    private var groups: [String: Group] = [:]
    private var players: [String: Player] = [:]
    private var connections: [String: SonosLocalConnection] = [:]
    private var consumers: [String: Task<Void, Never>] = [:]
    private var states: [String: SonosLiveConnectionState] = [:]
    private var generations: [String: Int] = [:]
    private var active: [String: Set<SonosLiveSubscription>] = [:]
    private var inFlight: [String: Set<SonosLiveSubscription>] = [:]
    private var householdHost: String?
    private var retryTasks: [String: Task<Void, Never>] = [:]
    private var topologyRefresh: Task<Void, Never>?

    public init(householdId: String, apiKey: String, configuration: SonosLiveConfiguration = SonosLiveConfiguration()) {
        self.init(householdId: householdId, apiKey: apiKey, configuration: configuration,
                  factory: URLSessionSonosLocalTransportFactory())
    }

    init(householdId: String, apiKey: String, configuration: SonosLiveConfiguration, factory: any SonosLocalTransportFactory) {
        self.householdId = householdId
        self.apiKey = apiKey
        self.configuration = configuration
        self.factory = factory
        var continuation: AsyncStream<SonosLiveEvent>.Continuation!
        self.events = AsyncStream(bufferingPolicy: .unbounded) { continuation = $0 }
        self.eventContinuation = continuation
    }

    // MARK: - Lifecycle

    /// Connects to every player. `groups` and `players` come from the cloud
    /// `getGroups` call (or a cached copy); afterwards the players keep the
    /// topology current through `groups` events.
    public func start(groups: [Group], players: [Player]) async {
        guard !isRunning else { return }
        isRunning = true
        log("starting live updates for \(players.count) player(s)")
        await applyTopology(groups: groups, players: players)
    }

    /// Closes every socket and ends `events`. A stopped client can't restart.
    public func stop() async {
        guard isRunning else { return }
        isRunning = false
        topologyRefresh?.cancel()
        topologyRefresh = nil
        retryTasks.values.forEach { $0.cancel() }
        retryTasks.removeAll()
        for connection in connections.values {
            await connection.stop(finish: true)
        }
        consumers.values.forEach { $0.cancel() }
        consumers.removeAll()
        connections.removeAll()
        states.removeAll()
        active.removeAll()
        inFlight.removeAll()
        householdHost = nil
        eventContinuation.finish()
    }

    /// Closes every socket without forgetting them (system sleep).
    public func suspend() async {
        guard isRunning, !isSuspended else { return }
        isSuspended = true
        for connection in connections.values {
            await connection.suspend()
        }
    }

    /// Reconnects after `suspend()`.
    public func resume() async {
        guard isRunning, isSuspended else { return }
        isSuspended = false
        for connection in connections.values {
            await connection.reconnectNow()
        }
    }

    /// Call when the network path changed: dead sockets reconnect at once,
    /// live ones are verified with a ping.
    public func networkChanged() async {
        guard isRunning, !isSuspended else { return }
        for connection in connections.values {
            if states[connection.playerId]?.isConnected == true {
                await connection.probe()
            } else {
                await connection.reconnectNow()
            }
        }
    }

    // MARK: - Queries

    public func connectionStates() -> [String: SonosLiveConnectionState] {
        states
    }

    /// True when commands and events for this group flow over the LAN.
    public func isLive(groupId: String) -> Bool {
        guard let coordinator = coordinatorId(for: groupId) else { return false }
        return states[coordinator]?.isConnected == true
    }

    public func isLive(playerId: String) -> Bool {
        states[playerId]?.isConnected == true
    }

    // MARK: - Commands

    /// Executes a Control API endpoint over the owning player's socket and
    /// returns the raw reply frame. Throws `SonosLocalError.noRoute` or
    /// `.notConnected` when it can't be sent locally.
    func perform(_ endpoint: SonosAPIEndpoint) async throws -> Data {
        guard isRunning, !isSuspended, let route = endpoint.localRoute else {
            throw SonosLocalError.noRoute(String(describing: endpoint))
        }
        let command = SonosLocalCommand(namespace: route.namespace, command: route.command,
                                        target: route.target, householdId: householdId, body: route.body)
        let connection = try connection(for: route.target)
        return try await connection.send(command)
    }

    private func connection(for target: SonosLocalTarget) throws -> SonosLocalConnection {
        let playerId: String?
        switch target {
        case .household:
            playerId = householdHost ?? electHouseholdHost()
        case .group(let groupId):
            playerId = coordinatorId(for: groupId)
        case .player(let id):
            playerId = id
        }
        guard let playerId, let connection = connections[playerId] else {
            throw SonosLocalError.noRoute(target.id)
        }
        guard states[playerId]?.isConnected == true else {
            throw SonosLocalError.notConnected
        }
        return connection
    }

    private func coordinatorId(for groupId: String) -> String? {
        groups[groupId]?.coordinatorId ?? Self.coordinatorId(fromGroupId: groupId)
    }

    /// Group ids have the form `<coordinator player id>:<sequence>`.
    static func coordinatorId(fromGroupId groupId: String) -> String? {
        guard let colon = groupId.firstIndex(of: ":"), colon != groupId.startIndex else { return nil }
        return String(groupId[..<colon])
    }

    // MARK: - Topology

    private func applyTopology(groups newGroups: [Group], players newPlayers: [Player]) async {
        groups = newGroups.reduce(into: [:]) { $0[$1.id] = $1 }
        players = newPlayers.reduce(into: [:]) { $0[$1.id] = $1 }

        let endpoints: [String: URL] = newPlayers.reduce(into: [:]) { result, player in
            if let url = URL(string: player.websocketUrl), url.host != nil {
                result[player.id] = url
            }
        }
        factory.setTrustedHosts(Set(endpoints.values.compactMap { $0.host }))

        for (playerId, url) in endpoints {
            if let existing = connections[playerId] {
                await existing.update(url: url)
            } else {
                let connection = SonosLocalConnection(playerId: playerId, url: url, apiKey: apiKey,
                                                      factory: factory, configuration: configuration)
                connections[playerId] = connection
                consume(connection)
                if isRunning && !isSuspended {
                    await connection.start()
                }
            }
        }
        for (playerId, connection) in connections where endpoints[playerId] == nil {
            log("player \(playerId) left the household")
            await connection.stop(finish: true)
            connections.removeValue(forKey: playerId)
            consumers.removeValue(forKey: playerId)?.cancel()
            states.removeValue(forKey: playerId)
            active.removeValue(forKey: playerId)
            inFlight.removeValue(forKey: playerId)
        }

        emit(.topology(groups: newGroups, players: newPlayers))
        await updateHouseholdHost()
        for playerId in connections.keys.sorted() where states[playerId]?.isConnected == true {
            await reconcile(playerId)
        }
    }

    private func scheduleTopologyRefresh() {
        guard topologyRefresh == nil, isRunning else { return }
        topologyRefresh = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            await self?.refreshTopology()
        }
    }

    private func refreshTopology() async {
        defer { topologyRefresh = nil }
        guard !Task.isCancelled else { return }
        do {
            let frame = try await connection(for: .household(householdId))
                .send(SonosLocalCommand(namespace: "groups", command: "getGroups",
                                        target: .household(householdId), householdId: householdId))
            let body = try SonosLocalFrameCodec.decodeBody(GroupsResponse.self, from: frame)
            await applyTopology(groups: body.groups, players: body.players)
        } catch {
            log("topology refresh failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Connections

    private func consume(_ connection: SonosLocalConnection) {
        let playerId = connection.playerId
        consumers[playerId] = Task { [weak self] in
            for await output in connection.outputs {
                await self?.handle(output, from: playerId)
            }
        }
    }

    private func handle(_ output: SonosLocalConnectionOutput, from playerId: String) async {
        guard isRunning else { return }
        switch output {
        case .state(let state):
            states[playerId] = state
            // A new socket starts without subscriptions; a closed one lost them.
            active[playerId] = []
            inFlight[playerId] = []
            generations[playerId, default: 0] += 1
            emit(.connection(playerId: playerId, state: state))
            await updateHouseholdHost()
            if state.isConnected {
                await reconcile(playerId)
            }
        case .event(let header, let frame):
            await handleEvent(header, frame: frame)
        }
    }

    private func electHouseholdHost() -> String? {
        if let host = householdHost, states[host]?.isConnected == true {
            return host
        }
        return states.filter { $0.value.isConnected }.keys.sorted().first
    }

    /// Keeps the household `groups` subscription on exactly one live socket.
    private func updateHouseholdHost() async {
        let newHost = electHouseholdHost()
        guard newHost != householdHost else { return }
        let previous = householdHost
        householdHost = newHost
        if let previous { await reconcile(previous) }
        if let newHost { await reconcile(newHost) }
    }

    // MARK: - Subscriptions

    func desiredSubscriptions(for playerId: String) -> Set<SonosLiveSubscription> {
        var desired: Set<SonosLiveSubscription> = []
        if players[playerId] != nil {
            desired.insert(.playerVolume(playerId))
        }
        for group in groups.values where group.coordinatorId == playerId {
            desired.insert(.playback(group.id))
            desired.insert(.metadata(group.id))
            desired.insert(.groupVolume(group.id))
        }
        if householdHost == playerId {
            desired.insert(.groups(householdId))
        }
        return desired
    }

    private func reconcile(_ playerId: String) async {
        guard isRunning, !isSuspended,
              let connection = connections[playerId],
              states[playerId]?.isConnected == true else { return }

        let desired = desiredSubscriptions(for: playerId)
        let current = active[playerId, default: []]

        for subscription in current.subtracting(desired) {
            active[playerId]?.remove(subscription)
            let command = SonosLocalCommand(namespace: subscription.namespace, command: "unsubscribe",
                                            target: subscription.target, householdId: householdId)
            Task { _ = try? await connection.send(command) }
        }

        let missing = desired.subtracting(current).subtracting(inFlight[playerId, default: []])
        // Household topology first, then groups, then volumes: the order the UI needs them.
        for subscription in missing.sorted(by: Self.subscriptionOrder) {
            await subscribe(subscription, on: connection, playerId: playerId)
        }
    }

    private static func subscriptionOrder(_ lhs: SonosLiveSubscription, _ rhs: SonosLiveSubscription) -> Bool {
        let rank = ["groups": 0, "playback": 1, "playbackMetadata": 2, "groupVolume": 3, "playerVolume": 4]
        let left = rank[lhs.namespace, default: 9], right = rank[rhs.namespace, default: 9]
        return left != right ? left < right : lhs.target.id < rhs.target.id
    }

    private func subscribe(_ subscription: SonosLiveSubscription, on connection: SonosLocalConnection, playerId: String) async {
        let generation = generations[playerId, default: 0]
        inFlight[playerId, default: []].insert(subscription)
        let command = SonosLocalCommand(namespace: subscription.namespace, command: "subscribe",
                                        target: subscription.target, householdId: householdId)
        do {
            _ = try await connection.send(command)
            // The socket was replaced while we waited: the new one resubscribes itself.
            guard generations[playerId, default: 0] == generation else { return }
            inFlight[playerId]?.remove(subscription)
            active[playerId, default: []].insert(subscription)
            guard desiredSubscriptions(for: playerId).contains(subscription) else {
                await reconcile(playerId)
                return
            }
            await fetchSnapshot(for: subscription, via: connection)
        } catch {
            guard generations[playerId, default: 0] == generation else { return }
            inFlight[playerId]?.remove(subscription)
            handleSubscriptionFailure(error, subscription: subscription, playerId: playerId)
        }
    }

    private func handleSubscriptionFailure(_ error: Error, subscription: SonosLiveSubscription, playerId: String) {
        if case SonosLocalError.commandFailed(let code, _) = error, code.lowercased().contains("coordinator") {
            // The group moved to another coordinator: re-read the topology.
            log("\(subscription.namespace) for \(subscription.target.id) moved (\(code)); refreshing groups")
            scheduleTopologyRefresh()
            return
        }
        if let local = error as? SonosLocalError, local == .notConnected || local == .closed {
            return // the reconnect resubscribes
        }
        log("subscribe \(subscription.namespace) \(subscription.target.id) failed: \(error.localizedDescription)")
        guard retryTasks[playerId] == nil else { return }
        let delay = configuration.subscriptionRetryDelay
        retryTasks[playerId] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await self?.retrySubscriptions(for: playerId)
        }
    }

    private func retrySubscriptions(for playerId: String) async {
        retryTasks[playerId] = nil
        await reconcile(playerId)
    }

    /// Subscribing doesn't replay the current state, so read it once.
    private func fetchSnapshot(for subscription: SonosLiveSubscription, via connection: SonosLocalConnection) async {
        let command: String
        switch subscription.namespace {
        case "groups": command = "getGroups"
        case "playback": command = "getPlaybackStatus"
        case "playbackMetadata": command = "getMetadataStatus"
        case "groupVolume", "playerVolume": command = "getVolume"
        default: return
        }
        do {
            let frame = try await connection.send(SonosLocalCommand(namespace: subscription.namespace, command: command,
                                                                    target: subscription.target, householdId: householdId))
            if subscription.namespace != "groups" {
                try deliver(namespace: subscription.namespace, target: subscription.target, frame: frame)
            } else {
                let body = try SonosLocalFrameCodec.decodeBody(GroupsResponse.self, from: frame)
                await applyTopology(groups: body.groups, players: body.players)
            }
        } catch {
            log("snapshot \(subscription.namespace) \(subscription.target.id) failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Events

    private func handleEvent(_ header: SonosLocalHeader, frame: Data) async {
        guard let type = header.type else { return }
        do {
            switch type {
            case "groups":
                let body = try SonosLocalFrameCodec.decodeBody(GroupsResponse.self, from: frame)
                await applyTopology(groups: body.groups, players: body.players)
            case "playbackStatus":
                if let groupId = header.groupId { try deliver(namespace: "playback", target: .group(groupId), frame: frame) }
            case "metadataStatus":
                if let groupId = header.groupId { try deliver(namespace: "playbackMetadata", target: .group(groupId), frame: frame) }
            case "groupVolume":
                if let groupId = header.groupId { try deliver(namespace: "groupVolume", target: .group(groupId), frame: frame) }
            case "playerVolume":
                if let playerId = header.playerId { try deliver(namespace: "playerVolume", target: .player(playerId), frame: frame) }
            case "playbackError":
                if let groupId = header.groupId {
                    let body = try SonosLocalFrameCodec.decodeBody(SonosLocalFrameCodec.ErrorBody.self, from: frame)
                    emit(.playbackError(groupId: groupId, errorCode: body.errorCode, reason: body.reason))
                }
            case "groupCoordinatorChanged":
                scheduleTopologyRefresh()
            default:
                break
            }
        } catch {
            log("dropped \(type) event: \(error.localizedDescription)")
        }
    }

    /// Decodes a playback/metadata/volume body and emits it.
    private func deliver(namespace: String, target: SonosLocalTarget, frame: Data) throws {
        switch (namespace, target) {
        case ("playback", .group(let groupId)):
            emit(.playbackStatus(groupId: groupId, status: try SonosLocalFrameCodec.decodeBody(PlaybackStatus.self, from: frame)))
        case ("playbackMetadata", .group(let groupId)):
            emit(.metadataStatus(groupId: groupId, metadata: try SonosLocalFrameCodec.decodeBody(PlaybackMetadata.self, from: frame)))
        case ("groupVolume", .group(let groupId)):
            emit(.groupVolume(groupId: groupId, volume: try SonosLocalFrameCodec.decodeBody(GroupVolume.self, from: frame)))
        case ("playerVolume", .player(let playerId)):
            emit(.playerVolume(playerId: playerId, volume: try SonosLocalFrameCodec.decodeBody(PlayerVolume.self, from: frame)))
        default:
            break
        }
    }

    private func emit(_ event: SonosLiveEvent) {
        eventContinuation.yield(event)
    }

    private func log(_ message: String) {
        configuration.logger?("[Sonos WS] \(message)")
    }
}
