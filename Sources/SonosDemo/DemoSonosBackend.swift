//
//  DemoSonosBackend.swift
//  SonosDemo
//
//  A simulated Sonos household behind `SonosLiveBackend`, for demo mode
//  (App Review has no Sonos system), UI tests and previews. Commands change
//  the household in memory and come back as live events, like real players:
//  rooms group and ungroup with Sonos' rules, a coordinator that leaves
//  hands the music to a new paused group, `loadContent` falls back to a
//  service's default account for an unknown account id, favorites and
//  playlists load in order, and a skip with shuffle on lands on a random
//  track.
//

import Combine
import Foundation
import SonosLive
import SonosSDK

@MainActor
public final class DemoSonosBackend: SonosLiveBackend {

    public struct Room: Hashable, Sendable {
        public let id: String
        public let name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }

    public struct Track: Hashable, Sendable {
        public let title: String
        public let artist: String
        public let album: String
        /// 0 for radio.
        public let durationMillis: Int
        public let imageUrl: String?

        public init(title: String, artist: String, album: String, durationMillis: Int, imageUrl: String? = nil) {
            self.title = title
            self.artist = artist
            self.album = album
            self.durationMillis = durationMillis
            self.imageUrl = imageUrl
        }
    }

    /// What a group plays: a queue from one service account.
    public struct Content: Hashable, Sendable {
        public let name: String
        public let serviceId: String
        public let serviceName: String
        public let objectId: String
        public let accountId: String
        public let tracks: [Track]

        public init(name: String, serviceId: String, serviceName: String, objectId: String, accountId: String, tracks: [Track]) {
            self.name = name
            self.serviceId = serviceId
            self.serviceName = serviceName
            self.objectId = objectId
            self.accountId = accountId
            self.tracks = tracks
        }
    }

    struct GroupState {
        var id: String
        var coordinatorId: String
        var playerIds: [String]
        var content: Content?
        var index = 0
        var playback: SonosPlaybackState = .idle
        var baseMillis: Double = 0
        var anchor: Date
        var shuffle = false
        var `repeat` = false

        var track: Track? {
            guard let tracks = content?.tracks, tracks.indices.contains(index) else { return nil }
            return tracks[index]
        }
    }

    public nonisolated static let householdId = "Sonos_DEMO_HOUSEHOLD"

    public nonisolated var isAuthenticated: Bool { true }
    public nonisolated var authenticationPublisher: AnyPublisher<Bool, Never> {
        Just(true).eraseToAnyPublisher()
    }

    /// Accounts per `serviceId`; the first is the service's default.
    public var accounts: [String: [String]] = [
        SonosServiceId.spotify: ["sn_5", "sn_6"],
        SonosServiceId.appleMusic: ["sn_2"],
    ]
    /// What `loadContent` plays for an `objectId`; unknown ids play a generic track.
    public var catalog: [String: (name: String, tracks: [Track])] = DemoSonosBackend.defaultCatalog
    /// How long the household takes to report a grouping change. Real
    /// players confirm `createGroup` and `modifyGroupMembers` before
    /// `getGroups` and the topology events show it.
    public var topologyDelay: Duration = .zero
    /// Picks the track a skip with shuffle on lands on, from the queue's length.
    public var randomIndex: (Int) -> Int = { Int.random(in: 0..<$0) }
    /// Favorites with more tracks load, but answer `504 ERROR_COMMAND_TIMEOUT`
    /// like the Sonos cloud does for playlists with thousands of tracks.
    public var cloudTimeoutTrackCount = 1_000

    public private(set) var rooms: [Room]
    private var groups: [String: GroupState] = [:]
    /// What topology reads return while a grouping change is still unreported.
    private var reportedTopology: ([Group], [Player])?
    private var playerVolumes: [String: (volume: Int, muted: Bool)] = [:]
    private var favoriteList: [(favorite: Favorite, content: Content)] = []
    private var playlistList: [(playlist: Playlist, content: Content)] = []
    private var sequence = 100
    private var session: DemoLiveSession?
    private let now: () -> Date

    public init(now: @escaping () -> Date = Date.init) {
        self.now = now
        rooms = [
            Room(id: "RINCON_DEMO_LIVING", name: "Living Room"),
            Room(id: "RINCON_DEMO_KITCHEN", name: "Kitchen"),
            Room(id: "RINCON_DEMO_DINING", name: "Dining Room"),
            Room(id: "RINCON_DEMO_KIDS", name: "Kids Room"),
            Room(id: "RINCON_DEMO_BATH", name: "Bathroom"),
        ]
        seed()
    }

    // MARK: - Reads

    public func getHouseholds() async throws -> [Household] {
        [try Self.decode(Household.self, ["id": Self.householdId, "name": "Demo"])]
    }

    public func getGroups(householdId: String, useCache: Bool) async throws -> ([Group], [Player]) {
        reportedTopology ?? topology()
    }

    public func getGroupPlaybackStatus(groupId: String, useCache: Bool) async throws -> PlaybackStatus {
        status(of: try group(groupId))
    }

    public func getGroupPlaybackMetadata(groupId: String, useCache: Bool) async throws -> PlaybackMetadata {
        try metadata(of: try group(groupId))
    }

    public func getGroupVolume(groupId: String, useCache: Bool) async throws -> GroupVolume {
        groupVolume(of: try group(groupId))
    }

    public func getPlayerVolume(playerId: String, useCache: Bool) async throws -> PlayerVolume {
        guard let volume = playerVolumes[playerId] else { throw DemoSonosError.unknownPlayer(playerId) }
        return PlayerVolume(volume: volume.volume, muted: volume.muted)
    }

    public func getFavorites(householdId: String) async throws -> [Favorite] {
        favoriteList.map(\.favorite)
    }

    public func getPlaylists(householdId: String) async throws -> [Playlist] {
        playlistList.map(\.playlist)
    }

    // MARK: - Playback

    public func play(groupId: String) async throws {
        try setPlayback(.playing, groupId: groupId)
    }

    public func pause(groupId: String) async throws {
        try setPlayback(.paused, groupId: groupId)
    }

    public func skipToNextTrack(groupId: String) async throws {
        try skip(groupId: groupId, by: 1)
    }

    public func skipToPreviousTrack(groupId: String) async throws {
        try skip(groupId: groupId, by: -1)
    }

    public func seek(groupId: String, positionMillis: UInt) async throws {
        var state = try group(groupId)
        state.baseMillis = Double(positionMillis)
        state.anchor = now()
        store(state)
        emitPlayback(of: state)
    }

    public func setPlayModes(groupId: String, playModes: PlayModesBody) async throws {
        var state = try group(groupId)
        if let shuffle = playModes.shuffle { state.shuffle = shuffle }
        if let repeatAll = playModes.repeat { state.repeat = repeatAll }
        store(state)
        emitPlayback(of: state)
    }

    public func loadFavorite(groupId: String, favoriteId: String, play: Bool, queueAction: SonosQueueAction) async throws {
        guard let entry = favoriteList.first(where: { $0.favorite.id == favoriteId }) else {
            throw DemoSonosError.unknownFavorite(favoriteId)
        }
        try load(entry.content, groupId: groupId, play: play, queueAction: queueAction, inOrder: true)
        if entry.content.tracks.count > cloudTimeoutTrackCount {
            throw SonosError.httpError(statusCode: 504,
                                       body: try Self.decode(SonosErrorBody.self, ["errorCode": "ERROR_COMMAND_TIMEOUT"]))
        }
    }

    public func loadPlaylist(groupId: String, playlistId: String, play: Bool, queueAction: SonosQueueAction) async throws {
        guard let entry = playlistList.first(where: { $0.playlist.id == playlistId }) else {
            throw DemoSonosError.unknownPlaylist(playlistId)
        }
        try load(entry.content, groupId: groupId, play: play, queueAction: queueAction, inOrder: true)
    }

    public func loadContent(groupId: String, content: SonosContent, play: Bool, queueAction: SonosQueueAction) async throws {
        let known = accounts[content.serviceId] ?? []
        let accountId = known.contains(content.accountId) ? content.accountId : (known.first ?? content.accountId)
        let entry = catalog[content.objectId]
        let item = Content(
            name: entry?.name ?? content.objectId,
            serviceId: content.serviceId,
            serviceName: Self.serviceName(content.serviceId),
            objectId: content.objectId,
            accountId: accountId,
            tracks: entry?.tracks ?? [Track(title: content.objectId, artist: Self.serviceName(content.serviceId),
                                            album: "", durationMillis: 180_000)]
        )
        try load(item, groupId: groupId, play: play, queueAction: queueAction)
    }

    // MARK: - Volume

    public func setGroupVolume(groupId: String, volume: Int) async throws {
        let state = try group(groupId)
        let delta = volume - groupVolume(of: state).volume
        for playerId in state.playerIds {
            let current = playerVolumes[playerId] ?? (0, false)
            playerVolumes[playerId] = (min(max(current.volume + delta, 0), 100), current.muted)
            emitPlayerVolume(playerId)
        }
        emitGroupVolume(of: state)
    }

    public func setGroupMuted(groupId: String, muted: Bool) async throws {
        let state = try group(groupId)
        for playerId in state.playerIds {
            playerVolumes[playerId]?.muted = muted
            emitPlayerVolume(playerId)
        }
        emitGroupVolume(of: state)
    }

    public func setPlayerVolume(playerId: String, volume: Int) async throws {
        guard playerVolumes[playerId] != nil else { throw DemoSonosError.unknownPlayer(playerId) }
        playerVolumes[playerId]?.volume = min(max(volume, 0), 100)
        emitPlayerVolume(playerId)
        if let state = groups.values.first(where: { $0.playerIds.contains(playerId) }) { emitGroupVolume(of: state) }
    }

    public func setPlayerMuted(playerId: String, muted: Bool) async throws {
        guard playerVolumes[playerId] != nil else { throw DemoSonosError.unknownPlayer(playerId) }
        playerVolumes[playerId]?.muted = muted
        emitPlayerVolume(playerId)
    }

    // MARK: - Grouping

    public func createGroup(householdId: String, playerIds: [String], musicContextGroupId: String?) async throws -> Group {
        guard let coordinator = playerIds.first else { throw DemoSonosError.emptyGroup }
        let before = topology()
        let context = musicContextGroupId.flatMap { groups[$0] }
        if let context, context.content == nil {
            // Like real players: an idle group has no music to hand over.
            throw SonosError.apiError(errorCode: "ERROR_PLAYBACK_FAILED",
                                      reason: "musicContextGroupId music context content cannot be copied")
        }
        detach(playerIds)
        var created = GroupState(id: nextGroupId(coordinator), coordinatorId: coordinator, playerIds: playerIds, anchor: now())
        if let context {
            // Takes over the music where it is, paused.
            created.content = context.content
            created.index = context.index
            created.baseMillis = position(of: context)
            created.playback = context.content == nil ? .idle : .paused
        }
        store(created)
        reportTopologyChange(since: before)
        emitGroup(created)
        return model(of: created)
    }

    public func modifyGroupMembers(groupId: String, playerIdsToAdd: [String], playerIdsToRemove: [String]) async throws -> Group {
        let current = try group(groupId)
        let before = topology()
        detach(playerIdsToAdd.filter { !current.playerIds.contains($0) })
        var state = groups.removeValue(forKey: current.id) ?? current
        state.playerIds = state.playerIds.filter { !playerIdsToRemove.contains($0) }
            + playerIdsToAdd.filter { !state.playerIds.contains($0) }
        for removed in playerIdsToRemove where current.playerIds.contains(removed) {
            store(GroupState(id: nextGroupId(removed), coordinatorId: removed, playerIds: [removed], anchor: now()))
        }
        if !state.playerIds.contains(state.coordinatorId), let next = state.playerIds.first {
            state.coordinatorId = next
            state.id = nextGroupId(next)
        }
        if !state.playerIds.isEmpty { store(state) }
        reportTopologyChange(since: before)
        groups.values.forEach(emitGroup)
        return model(of: state)
    }

    // MARK: - Live updates

    public func startLiveSession(
        householdId: String,
        groups: [Group],
        players: [Player],
        configuration: SonosLiveConfiguration
    ) async -> any SonosLiveSession {
        session?.finish()
        let session = DemoLiveSession { [weak self] in
            Task { @MainActor in self?.emitSnapshot() }
        }
        self.session = session
        emitSnapshot()
        return session
    }

    public func stopLiveSession(_ session: any SonosLiveSession) async {
        guard let demo = session as? DemoLiveSession, demo === self.session else { return }
        demo.finish()
        self.session = nil
    }

    // MARK: - Household

    private func seed() {
        let start = now()
        let living = rooms[0].id, kitchen = rooms[1].id, dining = rooms[2].id, kids = rooms[3].id, bath = rooms[4].id
        let volumes = [living: 32, kitchen: 24, dining: 22, kids: 18, bath: 15]
        for (id, volume) in volumes { playerVolumes[id] = (volume, false) }

        let favorites = Self.defaultFavorites
        favoriteList = favorites
        playlistList = Self.defaultPlaylists
        store(GroupState(id: "\(living):1", coordinatorId: living, playerIds: [living],
                         content: favorites[0].content, playback: .playing, baseMillis: 42_000, anchor: start))
        store(GroupState(id: "\(kitchen):1", coordinatorId: kitchen, playerIds: [kitchen, dining],
                         content: favorites[1].content, playback: .playing, anchor: start))
        store(GroupState(id: "\(kids):1", coordinatorId: kids, playerIds: [kids],
                         content: favorites[2].content, playback: .paused, baseMillis: 610_000, anchor: start))
        store(GroupState(id: "\(bath):1", coordinatorId: bath, playerIds: [bath], anchor: start))
    }

    /// Like the players: added tracks keep the queue's name and the current
    /// track, and a playing group pauses unless asked to play.
    private func load(_ content: Content, groupId: String, play: Bool, queueAction: SonosQueueAction,
                      inOrder: Bool = false) throws {
        var state = try group(groupId)
        if queueAction != .replace, let queued = state.content, !queued.tracks.isEmpty {
            var tracks = queued.tracks
            tracks.insert(contentsOf: content.tracks, at: queueAction == .append ? tracks.endIndex : state.index + 1)
            state.content = Content(name: queued.name, serviceId: queued.serviceId, serviceName: queued.serviceName,
                                    objectId: queued.objectId, accountId: queued.accountId, tracks: tracks)
            if inOrder {
                state.shuffle = false
                state.repeat = false
            }
            let playback: SonosPlaybackState = play ? .playing : (state.playback == .playing ? .paused : state.playback)
            if playback != state.playback {
                state.baseMillis = position(of: state)
                state.anchor = now()
                state.playback = playback
            }
            store(state)
            emitGroup(state)
            return
        }
        state.content = content
        state.index = 0
        if inOrder {
            state.shuffle = false
            state.repeat = false
        }
        state.baseMillis = 0
        state.anchor = now()
        state.playback = play ? .playing : .idle
        store(state)
        emitGroup(state)
    }

    private func setPlayback(_ playback: SonosPlaybackState, groupId: String) throws {
        var state = try group(groupId)
        guard state.content != nil else { return }
        state.baseMillis = position(of: state)
        state.anchor = now()
        state.playback = playback
        store(state)
        emitPlayback(of: state)
    }

    /// Like the players: with shuffle on, forward lands on a random track; without
    /// repeat, the queue's first and last tracks are the ends.
    private func skip(groupId: String, by step: Int) throws {
        var state = try group(groupId)
        guard let count = state.content?.tracks.count, count > 0 else { return }
        if state.shuffle, step > 0, count > 1 {
            let next = randomIndex(count - 1)
            state.index = next >= state.index ? next + 1 : next
        } else if state.repeat {
            state.index = (state.index + step + count) % count
        } else {
            state.index = min(max(state.index + step, 0), count - 1)
        }
        state.baseMillis = 0
        state.anchor = now()
        store(state)
        emitGroup(state)
    }

    /// Takes `playerIds` out of their groups. A group keeps its id while its
    /// coordinator stays (as on real players); one that loses its
    /// coordinator continues under its next room with a new id.
    private func detach(_ playerIds: [String]) {
        for var state in groups.values where state.playerIds.contains(where: playerIds.contains) {
            groups.removeValue(forKey: state.id)
            state.playerIds.removeAll { playerIds.contains($0) }
            guard let first = state.playerIds.first else { continue }
            if !state.playerIds.contains(state.coordinatorId) {
                state.coordinatorId = first
                state.id = nextGroupId(first)
            }
            store(state)
        }
    }

    private func group(_ groupId: String) throws -> GroupState {
        guard let state = groups[groupId] else { throw DemoSonosError.unknownGroup(groupId) }
        return state
    }

    private func store(_ state: GroupState) {
        groups[state.id] = state
    }

    private func nextGroupId(_ coordinatorId: String) -> String {
        sequence += 1
        return "\(coordinatorId):\(sequence)"
    }

    private func position(of state: GroupState) -> Double {
        let elapsed = state.playback == .playing ? max(0, now().timeIntervalSince(state.anchor)) * 1_000 : 0
        let position = state.baseMillis + elapsed
        if let duration = state.track?.durationMillis, duration > 0 { return min(position, Double(duration)) }
        return position
    }

    // MARK: - Models

    private func roomName(_ id: String) -> String {
        rooms.first { $0.id == id }?.name ?? id
    }

    private func model(of state: GroupState) -> Group {
        let others = state.playerIds.count - 1
        let name = others > 0 ? "\(roomName(state.coordinatorId)) + \(others)" : roomName(state.coordinatorId)
        return Group(id: state.id, name: name, coordinatorId: state.coordinatorId,
                     playbackState: state.playback.rawValue, playerIds: state.playerIds)
    }

    private func topology() -> ([Group], [Player]) {
        let models = groups.values.sorted { $0.id < $1.id }.map(model(of:))
        return (models, rooms.map { Player(id: $0.id, name: $0.name) })
    }

    private func status(of state: GroupState) -> PlaybackStatus {
        let tracks = state.content?.tracks.count ?? 0
        let seekable = (state.track?.durationMillis ?? 0) > 0
        return PlaybackStatus(
            availablePlaybackActions: PlaybackActions(canRepeat: tracks > 0, canResume: tracks > 0, canSeek: seekable,
                                                      canShuffle: tracks > 1, canSkip: tracks > 1, canSkipBack: tracks > 1),
            itemId: state.content.map { "\($0.objectId)#\(state.index)" },
            playbackState: state.playback.rawValue,
            playModes: PlayModes(shuffle: state.shuffle, repeat: state.repeat),
            positionMillis: UInt(position(of: state))
        )
    }

    private func metadata(of state: GroupState) throws -> PlaybackMetadata {
        guard let content = state.content, let track = state.track else {
            return try Self.decode(PlaybackMetadata.self, [:])
        }
        let service: [String: Any] = ["name": content.serviceName, "id": content.serviceId]
        func id(_ objectId: String) -> [String: Any] {
            ["serviceId": content.serviceId, "objectId": objectId, "accountId": content.accountId]
        }
        func json(_ track: Track, index: Int) -> [String: Any] {
            var json: [String: Any] = [
                "name": track.title,
                "artist": ["name": track.artist],
                "album": ["name": track.album],
                "id": id("\(content.objectId)#\(index)"),
                "service": service,
            ]
            if track.durationMillis > 0 { json["durationMillis"] = track.durationMillis }
            if let imageUrl = track.imageUrl { json["imageUrl"] = imageUrl }
            return json
        }
        var metadata: [String: Any] = [
            "container": ["name": content.name, "type": content.objectId.contains("album:") ? "album" : "playlist",
                          "id": id(content.objectId), "service": service],
            "currentItem": ["track": json(track, index: state.index)],
        ]
        if !state.shuffle, content.tracks.indices.contains(state.index + 1) {
            metadata["nextItem"] = ["track": json(content.tracks[state.index + 1], index: state.index + 1)]
        }
        return try Self.decode(PlaybackMetadata.self, metadata)
    }

    private func groupVolume(of state: GroupState) -> GroupVolume {
        let volumes = state.playerIds.compactMap { playerVolumes[$0] }
        let average = volumes.isEmpty ? 0 : volumes.map(\.volume).reduce(0, +) / volumes.count
        return GroupVolume(volume: average, muted: !volumes.isEmpty && volumes.allSatisfy(\.muted))
    }

    // MARK: - Events

    private func emit(_ event: SonosLiveEvent) {
        session?.yield(event)
    }

    private func emitSnapshot() {
        emitTopology()
        for room in rooms {
            emit(.connection(playerId: room.id, state: .connected))
            emitPlayerVolume(room.id)
        }
        groups.values.forEach(emitGroup)
    }

    private func emitTopology() {
        let (groups, players) = topology()
        emit(.topology(groups: groups, players: players))
    }

    /// Reports a grouping change at once, or after `topologyDelay`: until
    /// then reads return the topology from `before`, and the groups' state
    /// follows the new topology like it does on real players.
    private func reportTopologyChange(since before: ([Group], [Player])) {
        guard topologyDelay > .zero else { return emitTopology() }
        if reportedTopology == nil { reportedTopology = before }
        let delay = topologyDelay
        Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self else { return }
            reportedTopology = nil
            emitTopology()
            groups.values.forEach(emitGroup)
        }
    }

    private func emitGroup(_ state: GroupState) {
        emitPlayback(of: state)
        if let metadata = try? metadata(of: state) {
            emit(.metadataStatus(groupId: state.id, metadata: metadata))
        }
        emitGroupVolume(of: state)
    }

    private func emitPlayback(of state: GroupState) {
        emit(.playbackStatus(groupId: state.id, status: status(of: state)))
    }

    private func emitGroupVolume(of state: GroupState) {
        emit(.groupVolume(groupId: state.id, volume: groupVolume(of: state)))
    }

    private func emitPlayerVolume(_ playerId: String) {
        guard let volume = playerVolumes[playerId] else { return }
        emit(.playerVolume(playerId: playerId, volume: PlayerVolume(volume: volume.volume, muted: volume.muted)))
    }

    static func decode<T: Decodable>(_ type: T.Type, _ object: [String: Any]) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
    }

    static func serviceName(_ serviceId: String) -> String {
        switch serviceId {
        case SonosServiceId.spotify: return "Spotify"
        case SonosServiceId.appleMusic: return "Apple Music"
        default: return "Music"
        }
    }
}

public enum DemoSonosError: LocalizedError, Equatable {
    case unknownGroup(String)
    case unknownPlayer(String)
    case unknownFavorite(String)
    case unknownPlaylist(String)
    case emptyGroup

    public var errorDescription: String? {
        switch self {
        case .unknownGroup(let id): return "Unknown demo group \(id)."
        case .unknownPlayer(let id): return "Unknown demo speaker \(id)."
        case .unknownFavorite(let id): return "Unknown demo favorite \(id)."
        case .unknownPlaylist(let id): return "Unknown demo playlist \(id)."
        case .emptyGroup: return "A group needs at least one speaker."
        }
    }
}

/// Event stream of the demo household. `resume()` replays the full state,
/// like a reconnecting player.
final class DemoLiveSession: SonosLiveSession, @unchecked Sendable {
    let events: AsyncStream<SonosLiveEvent>
    private let continuation: AsyncStream<SonosLiveEvent>.Continuation
    private let replay: @Sendable () -> Void

    init(replay: @escaping @Sendable () -> Void) {
        var continuation: AsyncStream<SonosLiveEvent>.Continuation!
        events = AsyncStream(bufferingPolicy: .unbounded) { continuation = $0 }
        self.continuation = continuation
        self.replay = replay
    }

    func yield(_ event: SonosLiveEvent) {
        continuation.yield(event)
    }

    func finish() {
        continuation.finish()
    }

    func suspend() async {}

    func resume() async {
        replay()
    }
}
