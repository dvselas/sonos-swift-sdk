//
//  SonosLiveStore.swift
//  SonosLive
//
//  App-wide owner of Sonos state. Started at launch once the user is signed
//  in: loads the household from the cloud once, then keeps it current over
//  the players' local WebSockets (`SonosLiveSession`). Views render
//  `state` and call the intent methods; they never poll.
//
//  Footprint: one socket per player (one ping per player every 45 s while
//  idle), no timers per card. Cloud polling only runs for groups whose
//  coordinator can't be reached, and only while a Sonos view is visible.
//

import Foundation
import Observation
import SonosSDK

@MainActor
@Observable
public final class SonosLiveStore {

    public enum Phase: Equatable {
        /// Signed out, disabled, or not started yet.
        case idle
        /// Loading the household.
        case connecting
        /// Household loaded. Per-group liveness is `SonosGroupModel.isLive`;
        /// groups without a live socket are refreshed over the cloud.
        case ready
        /// Sonos couldn't be reached at all; retried every minute.
        case offline(String)
    }

    /// User-facing text the store produces itself. Apps pass localized copies.
    public struct Messages: Sendable {
        /// The account has no Sonos household.
        public var noHousehold: String
        /// A favorite couldn't be queued (`499 ERROR_FAILURE_TO_ENQUEUE`).
        public var enqueueFailed: String

        public init(
            noHousehold: String = "No Sonos system is linked to this account.",
            enqueueFailed: String = "The music service couldn't start this right now. Try again in a moment."
        ) {
            self.noHousehold = noHousehold
            self.enqueueFailed = enqueueFailed
        }
    }

    /// UserDefaults key of the "live updates" setting (on by default).
    /// Off means cloud-only: no local sockets, polling while visible.
    public nonisolated static let enabledKey = "sonosLiveUpdates"

    public let state = SonosLiveState()
    public private(set) var phase: Phase = .idle
    public private(set) var householdId: String?
    /// Error to show to the user; the view clears it after presenting.
    public var alertMessage: String?

    @ObservationIgnored public let backend: any SonosLiveBackend
    @ObservationIgnored let messages: Messages
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored let log: @Sendable (String) -> Void
    @ObservationIgnored let now: () -> Date
    @ObservationIgnored private let traceFrames: Bool
    @ObservationIgnored private var client: (any SonosLiveSession)?
    @ObservationIgnored private var connectTask: Task<Void, Never>?
    @ObservationIgnored private var eventsTask: Task<Void, Never>?
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var fallbackTask: Task<Void, Never>?
    @ObservationIgnored private var visibleViewCount = 0
    @ObservationIgnored private var volumeSenders: [String: SonosThrottledSender] = [:]
    @ObservationIgnored private var cachedTopologySignature: String?
    /// Sign-in and system lifecycle observers (see `activate()`).
    @ObservationIgnored var systemObservers: [AnyObject] = []
    @ObservationIgnored var isActivated = false
    @ObservationIgnored public var fallbackInterval: Duration = .seconds(15)
    @ObservationIgnored public var retryInterval: Duration = .seconds(60)
    /// How often `isolate(_:)` reads the topology until it shows the room on its own.
    @ObservationIgnored public var topologyPollInterval: Duration = .milliseconds(250)

    /// - Parameters:
    ///   - traceFrames: Logs every raw socket frame.
    public init(
        backend: any SonosLiveBackend,
        defaults: UserDefaults = .standard,
        messages: Messages = Messages(),
        traceFrames: Bool = false,
        log: @escaping @Sendable (String) -> Void = { _ in },
        now: @escaping () -> Date = Date.init
    ) {
        self.backend = backend
        self.defaults = defaults
        self.messages = messages
        self.traceFrames = traceFrames
        self.log = log
        self.now = now
    }

    public var isEnabled: Bool {
        defaults.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    // MARK: - Lifecycle

    /// Loads the household and opens the local sockets. Safe to call repeatedly.
    public func connect() {
        guard householdId == nil, connectTask == nil else { return }
        retryTask?.cancel()
        retryTask = nil
        phase = .connecting
        connectTask = Task { [weak self] in
            await self?.performConnect()
            // A cancelled attempt was replaced by a newer one; leave its handle alone.
            guard !Task.isCancelled else { return }
            self?.connectTask = nil
        }
    }

    /// Closes every socket and forgets the household (sign-out, setting off).
    public func disconnect() async {
        connectTask?.cancel()
        connectTask = nil
        retryTask?.cancel()
        retryTask = nil
        eventsTask?.cancel()
        eventsTask = nil
        fallbackTask?.cancel()
        fallbackTask = nil
        volumeSenders.values.forEach { $0.cancel() }
        volumeSenders = [:]
        // Reset before the first await so a connect() right after this starts fresh.
        let previousClient = client
        client = nil
        state.reset()
        householdId = nil
        favorites = []
        favoritesPhase = .idle
        phase = .idle
        if let previousClient {
            await backend.stopLiveSession(previousClient)
        }
    }

    public func reconnect() async {
        await disconnect()
        connect()
    }

    /// System sleep or app in the background: close sockets but keep state.
    public func suspend() async {
        await client?.suspend()
    }

    /// Wake or back in the foreground: reconnect at once.
    public func resume() async {
        await client?.resume()
    }

    private func performConnect() async {
        do {
            let households = try await backend.getHouseholds()
            guard let household = households.first else {
                phase = .offline(messages.noHousehold)
                return
            }
            if households.count > 1 {
                log("[Sonos] \(households.count) households linked; showing the first")
            }
            let (groups, players) = try await backend.getGroups(householdId: household.id, useCache: false)
            guard !Task.isCancelled else { return }
            persistTopology(householdId: household.id, groups: groups, players: players)
            await begin(householdId: household.id, groups: groups, players: players)
        } catch {
            guard !Task.isCancelled else { return }
            log("[Sonos] Could not load the household from the cloud: \(error.localizedDescription)")
            if let cached = SonosTopologyCache.load(from: defaults) {
                log("[Sonos] Starting from the last known speakers")
                await begin(householdId: cached.householdId, groups: cached.groups, players: cached.players)
            } else {
                phase = .offline(error.localizedDescription)
                scheduleRetry()
            }
        }
    }

    private func begin(householdId: String, groups: [Group], players: [Player]) async {
        self.householdId = householdId
        state.apply(.topology(groups: groups, players: players), at: now())
        phase = .ready
        defer { updateFallbackPolling() }
        guard isEnabled else {
            log("[Sonos] Live updates are off; using the cloud")
            return
        }

        let log = self.log
        let configuration = SonosLiveConfiguration(
            logger: { log($0) },
            traceFrames: traceFrames
        )
        let client = await backend.startLiveSession(
            householdId: householdId,
            groups: groups,
            players: players,
            configuration: configuration
        )
        guard !Task.isCancelled else {
            await backend.stopLiveSession(client)
            return
        }
        self.client = client
        eventsTask = Task { [weak self] in
            for await event in client.events {
                self?.handle(event)
            }
        }
    }

    private func handle(_ event: SonosLiveEvent) {
        state.apply(event, at: now())
        if case .topology(let groups, let players) = event, let householdId {
            persistTopology(householdId: householdId, groups: groups, players: players)
        }
    }

    private func scheduleRetry() {
        retryTask?.cancel()
        let interval = retryInterval
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: interval)
            guard !Task.isCancelled else { return }
            self?.retryTask = nil
            self?.connect()
        }
    }

    private func persistTopology(householdId: String, groups: [Group], players: [Player]) {
        let cache = SonosTopologyCache(householdId: householdId, groups: groups, players: players)
        let signature = cache.signature
        guard signature != cachedTopologySignature else { return }
        cachedTopologySignature = signature
        cache.save(to: defaults)
    }

    // MARK: - Fallback polling

    /// A Sonos view reports its visibility; cloud fallback only runs while visible.
    public func viewAppeared() {
        visibleViewCount += 1
        updateFallbackPolling()
    }

    public func viewDisappeared() {
        visibleViewCount = max(visibleViewCount - 1, 0)
        updateFallbackPolling()
    }

    private func updateFallbackPolling() {
        let shouldPoll = visibleViewCount > 0 && householdId != nil
        if shouldPoll, fallbackTask == nil {
            let interval = fallbackInterval
            fallbackTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: interval)
                    guard !Task.isCancelled else { return }
                    await self?.pollUnreachable()
                }
            }
        } else if !shouldPoll {
            fallbackTask?.cancel()
            fallbackTask = nil
        }
    }

    /// Refreshes the groups and players whose socket is down (over the cloud).
    public func pollUnreachable() async {
        guard let householdId else { return }
        let hasStaleGroups = state.groups.contains { !$0.isLive }
        let hasStalePlayers = state.players.values.contains { !$0.isLive }
        guard hasStaleGroups || hasStalePlayers else { return }

        if hasStaleGroups, let topology = try? await backend.getGroups(householdId: householdId, useCache: false) {
            state.apply(.topology(groups: topology.0, players: topology.1), at: now())
        }
        for group in state.groups where !group.isLive {
            let groupId = group.groupId
            let knownItem = group.playback.status?.itemId
            if let status = try? await backend.getGroupPlaybackStatus(groupId: groupId, useCache: false) {
                state.apply(.playbackStatus(groupId: groupId, status: status), at: now())
                if group.metadata == nil || status.itemId != knownItem,
                   let metadata = try? await backend.getGroupPlaybackMetadata(groupId: groupId, useCache: false) {
                    state.apply(.metadataStatus(groupId: groupId, metadata: metadata), at: now())
                }
            }
            if let volume = try? await backend.getGroupVolume(groupId: groupId, useCache: false) {
                state.apply(.groupVolume(groupId: groupId, volume: volume), at: now())
            }
        }
        for player in state.players.values where !player.isLive {
            if let volume = try? await backend.getPlayerVolume(playerId: player.id, useCache: false) {
                state.apply(.playerVolume(playerId: player.id, volume: volume), at: now())
            }
        }
    }

    // MARK: - Playback intents

    public func togglePlayPause(_ group: SonosGroupModel) {
        let target: SonosPlaybackState = group.isPlaying ? .paused : .playing
        group.beginPlayIntent(target, at: now())
        scheduleExpiry(for: group, after: SonosIntentTiming.playState)
        let groupId = group.groupId
        perform({ [backend] in
            // Explicit play/pause (not toggle) so a repeated tap can't invert the intent.
            if target == .playing {
                try await backend.play(groupId: groupId)
            } else {
                try await backend.pause(groupId: groupId)
            }
        }, onFailure: { group.cancelPlayIntent() })
    }

    public func skip(_ group: SonosGroupModel, forward: Bool) {
        group.beginSkip(at: now())
        scheduleExpiry(for: group, after: SonosIntentTiming.skip)
        let groupId = group.groupId
        perform({ [backend] in
            if forward {
                try await backend.skipToNextTrack(groupId: groupId)
            } else {
                try await backend.skipToPreviousTrack(groupId: groupId)
            }
        }, onFailure: { group.cancelSkip() })
    }

    public func seek(_ group: SonosGroupModel, toMillis millis: Double) {
        let target = max(millis, 0)
        group.beginSeekIntent(to: target, at: now())
        scheduleExpiry(for: group, after: SonosIntentTiming.seek)
        let groupId = group.groupId
        perform({ [backend] in
            try await backend.seek(groupId: groupId, positionMillis: UInt(target))
        }, onFailure: { group.cancelSeekIntent() })
    }

    public func toggleShuffle(_ group: SonosGroupModel) {
        let groupId = group.groupId
        let enable = !group.playModes.shuffle
        perform({ [backend] in
            try await backend.setPlayModes(groupId: groupId, playModes: PlayModesBody(shuffle: enable))
        })
    }

    public func toggleRepeat(_ group: SonosGroupModel) {
        let groupId = group.groupId
        let enable = !group.playModes.repeat
        perform({ [backend] in
            try await backend.setPlayModes(groupId: groupId, playModes: PlayModesBody(repeat: enable))
        })
    }

    // MARK: - Volume intents

    /// Group volume. Call with `isFinal: false` while dragging (throttled)
    /// and `true` on release.
    public func setGroupVolume(_ group: SonosGroupModel, to volume: Int, isFinal: Bool) {
        group.beginVolumeIntent(volume, dragging: !isFinal, at: now())
        if isFinal { scheduleExpiry(for: group, after: SonosIntentTiming.volumeSettle) }
        let groupId = group.groupId
        let backend = self.backend
        var onFailure: (@MainActor () -> Void)?
        if isFinal { onFailure = { group.cancelVolumeIntent() } }
        sender(for: "group:\(group.coordinatorId)").submit(min(max(volume, 0), 100), isFinal: isFinal) { [weak self] value in
            self?.perform({
                try await backend.setGroupVolume(groupId: groupId, volume: value)
            }, onFailure: onFailure, silent: !isFinal)
        }
    }

    public func setGroupMuted(_ group: SonosGroupModel, _ muted: Bool) {
        group.beginMuteIntent(muted, at: now())
        scheduleExpiry(for: group, after: SonosIntentTiming.mute)
        let groupId = group.groupId
        perform({ [backend] in
            try await backend.setGroupMuted(groupId: groupId, muted: muted)
        }, onFailure: { group.cancelMuteIntent() })
    }

    public func setPlayerVolume(_ player: SonosPlayerModel, to volume: Int, isFinal: Bool) {
        player.beginVolumeIntent(volume, dragging: !isFinal, at: now())
        if isFinal { scheduleExpiry(for: player, after: SonosIntentTiming.volumeSettle) }
        let playerId = player.id
        let backend = self.backend
        var onFailure: (@MainActor () -> Void)?
        if isFinal { onFailure = { player.cancelVolumeIntent() } }
        sender(for: "player:\(playerId)").submit(min(max(volume, 0), 100), isFinal: isFinal) { [weak self] value in
            self?.perform({
                try await backend.setPlayerVolume(playerId: playerId, volume: value)
            }, onFailure: onFailure, silent: !isFinal)
        }
    }

    public func setPlayerMuted(_ player: SonosPlayerModel, _ muted: Bool) {
        player.beginMuteIntent(muted, at: now())
        scheduleExpiry(for: player, after: SonosIntentTiming.mute)
        let playerId = player.id
        perform({ [backend] in
            try await backend.setPlayerMuted(playerId: playerId, muted: muted)
        }, onFailure: { player.cancelMuteIntent() })
    }

    // MARK: - Grouping

    /// Adds and removes rooms. The resulting topology arrives as an event.
    public func modifyGroup(_ group: SonosGroupModel, adding: [String] = [], removing: [String] = []) async throws {
        _ = try await backend.modifyGroupMembers(
            groupId: group.groupId,
            playerIdsToAdd: adding,
            playerIdsToRemove: removing
        )
        await refreshTopologyIfNotLive()
    }

    /// Leaves only the coordinator in the group; the other rooms become
    /// groups of their own.
    public func ungroup(_ group: SonosGroupModel) async throws {
        let others = group.playerIds.filter { $0 != group.coordinatorId }
        guard !others.isEmpty else { return }
        try await modifyGroup(group, removing: others)
    }

    /// Joins `groups` into the first one.
    public func merge(_ groups: [SonosGroupModel]) async throws {
        guard let target = groups.first, groups.count > 1 else { return }
        let others = groups.dropFirst().flatMap(\.playerIds)
        try await modifyGroup(target, adding: Array(others))
    }

    /// Without a live socket no `groups` event arrives, so read the result.
    func refreshTopologyIfNotLive() async {
        guard let householdId, state.liveCount.live == 0 else { return }
        if let topology = try? await backend.getGroups(householdId: householdId, useCache: false) {
            state.apply(.topology(groups: topology.0, players: topology.1), at: now())
        }
    }

    // MARK: - Favorites

    public enum FavoritesPhase: Equatable {
        case idle, loading, loaded
        case failed(String)
    }

    /// The household's favorites, kept so an overlay opens at once.
    public private(set) var favorites: [Favorite] = []
    public private(set) var favoritesPhase: FavoritesPhase = .idle
    @ObservationIgnored private var isLoadingFavorites = false
    @ObservationIgnored public var favoriteRetryDelay: Duration = .milliseconds(600)

    /// Loads the favorites; later calls refresh them while the last list
    /// stays on screen.
    public func loadFavorites() async {
        guard let householdId, !isLoadingFavorites else { return }
        isLoadingFavorites = true
        defer { isLoadingFavorites = false }
        if favorites.isEmpty { favoritesPhase = .loading }
        do {
            favorites = try await backend.getFavorites(householdId: householdId)
            favoritesPhase = .loaded
        } catch {
            log("[Sonos] Could not load favorites: \(error.localizedDescription)")
            if favorites.isEmpty { favoritesPhase = .failed(error.localizedDescription) }
        }
    }

    /// Plays a favorite on `group`, with one retry: the Sonos cloud now and
    /// then answers `499 ERROR_FAILURE_TO_ENQUEUE` while a music service's
    /// session needs a refresh. Track and play state arrive as live events.
    public func playFavorite(_ favoriteId: String, on group: SonosGroupModel) async throws {
        do {
            try await backend.loadFavorite(groupId: group.groupId, favoriteId: favoriteId)
            return
        } catch {
            log("[Sonos] loadFavorite first attempt failed: \(error.localizedDescription)")
        }
        try? await Task.sleep(for: favoriteRetryDelay)
        do {
            try await backend.loadFavorite(groupId: group.groupId, favoriteId: favoriteId)
        } catch {
            log("[Sonos] loadFavorite retry failed: \(error.localizedDescription)")
            throw SonosFavoriteError(underlying: error, enqueueFailedMessage: messages.enqueueFailed)
        }
    }

    // MARK: - Helpers

    private func sender(for key: String) -> SonosThrottledSender {
        if let sender = volumeSenders[key] { return sender }
        let sender = SonosThrottledSender()
        volumeSenders[key] = sender
        return sender
    }

    private func perform(
        _ operation: @escaping () async throws -> Void,
        onFailure: (@MainActor () -> Void)? = nil,
        silent: Bool = false
    ) {
        Task { [weak self] in
            do {
                try await operation()
            } catch {
                onFailure?()
                self?.log("[Sonos] Command failed: \(error.localizedDescription)")
                if !silent { self?.present(error) }
            }
        }
    }

    private func present(_ error: Error) {
        guard alertMessage == nil else { return }
        alertMessage = error.localizedDescription
    }

    private func scheduleExpiry(for group: SonosGroupModel, after seconds: TimeInterval) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds + 0.05))
            guard let self else { return }
            group.expireIntents(at: self.now())
        }
    }

    private func scheduleExpiry(for player: SonosPlayerModel, after seconds: TimeInterval) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds + 0.05))
            guard let self else { return }
            player.expireIntents(at: self.now())
        }
    }
}

// MARK: - Errors

/// Replaces the cloud's cryptic enqueue failure with copy the user can act on.
public struct SonosFavoriteError: LocalizedError {
    public let underlying: Error
    let enqueueFailedMessage: String

    public init(underlying: Error, enqueueFailedMessage: String = SonosLiveStore.Messages().enqueueFailed) {
        self.underlying = underlying
        self.enqueueFailedMessage = enqueueFailedMessage
    }

    public var isEnqueueFailure: Bool {
        let raw = underlying.localizedDescription
        return raw.contains("ERROR_FAILURE_TO_ENQUEUE") || raw.contains("499")
    }

    public var errorDescription: String? {
        isEnqueueFailure ? enqueueFailedMessage : underlying.localizedDescription
    }
}

// MARK: - Throttling

/// Sends at most one value per `minimumInterval` while a slider moves and
/// always sends the last value.
@MainActor
public final class SonosThrottledSender {
    private let minimumInterval: TimeInterval
    private var lastSent: Date?
    private var trailing: Task<Void, Never>?

    public init(minimumInterval: TimeInterval = 0.15) {
        self.minimumInterval = minimumInterval
    }

    public func submit(_ value: Int, isFinal: Bool, send: @escaping @MainActor (Int) -> Void) {
        trailing?.cancel()
        trailing = nil
        let current = Date()
        let elapsed = lastSent.map { current.timeIntervalSince($0) } ?? .infinity
        if isFinal || elapsed >= minimumInterval {
            lastSent = current
            send(value)
            return
        }
        let wait = minimumInterval - elapsed
        trailing = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled, let self else { return }
            self.lastSent = Date()
            send(value)
        }
    }

    public func cancel() {
        trailing?.cancel()
        trailing = nil
    }
}

// MARK: - Topology cache

/// Last known household, so live updates can start while the cloud is down.
public struct SonosTopologyCache: Codable {
    public static let defaultsKey = "sonosTopologyCache"

    public let householdId: String
    public let groups: [Group]
    public let players: [Player]

    public init(householdId: String, groups: [Group], players: [Player]) {
        self.householdId = householdId
        self.groups = groups
        self.players = players
    }

    /// Changes when ids, names or player addresses change.
    public var signature: String {
        let groupPart = groups.map { "\($0.id)=\($0.name)=\($0.playerIds.joined(separator: ","))" }.sorted()
        let playerPart = players.map { "\($0.id)=\($0.name)=\($0.websocketUrl)" }.sorted()
        return ([householdId] + groupPart + playerPart).joined(separator: "|")
    }

    public func save(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }

    public static func load(from defaults: UserDefaults) -> SonosTopologyCache? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(SonosTopologyCache.self, from: data)
    }
}
