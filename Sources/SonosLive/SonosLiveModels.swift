//
//  SonosLiveModels.swift
//  SonosLive
//
//  Observable Sonos state fed by `SonosLiveSession` events. Everything a
//  Sonos card renders comes from here; views never fetch state themselves.
//
//  Optimistic UI: a user action records a pending intent (play, pause,
//  seek, volume, mute). The card shows the intent until the players confirm
//  it or its deadline passes, then shows the players' truth again. Every
//  writer (pushed events, fallback polls) goes through the same reducers,
//  so nothing can bypass the intent guard.
//

import Foundation
import Observation
import SonosSDK

/// Playback states of the Sonos Control API.
public enum SonosPlaybackState: String, Equatable, Sendable {
    case idle = "PLAYBACK_STATE_IDLE"
    case buffering = "PLAYBACK_STATE_BUFFERING"
    case paused = "PLAYBACK_STATE_PAUSED"
    case playing = "PLAYBACK_STATE_PLAYING"

    public init(sonos raw: String?) {
        self = raw.flatMap(SonosPlaybackState.init(rawValue:)) ?? .idle
    }

    /// Playing or about to play: the transport button offers "pause".
    public var isActive: Bool {
        self == .playing || self == .buffering
    }
}

/// A value the user asked for, shown until confirmed or `deadline` passes.
public struct SonosPending<Value: Equatable>: Equatable {
    public let value: Value
    public let deadline: Date

    public func isValid(at now: Date) -> Bool {
        now < deadline
    }
}

/// How long intents may override the players' reported state.
public enum SonosIntentTiming {
    public static let playState: TimeInterval = 5
    public static let seek: TimeInterval = 3
    public static let volumeSettle: TimeInterval = 1.5
    public static let mute: TimeInterval = 3
    public static let skip: TimeInterval = 4
    /// A confirmed seek lands within this distance of the target.
    public static let seekToleranceMillis: Double = 2_500
}

// MARK: - Playback

/// Position known at an instant; extrapolated while playing.
public struct SonosPositionAnchor: Equatable {
    public var millis: Double
    public var at: Date
    public var advancing: Bool

    public static let zero = SonosPositionAnchor(millis: 0, at: .distantPast, advancing: false)

    public func position(at now: Date) -> Double {
        guard advancing else { return millis }
        return millis + max(0, now.timeIntervalSince(at)) * 1_000
    }
}

/// Play state and position of a group, merged with pending intents.
public struct SonosPlaybackControlState: Equatable {
    public private(set) var status: PlaybackStatus?
    public private(set) var truthAnchor: SonosPositionAnchor = .zero
    public private(set) var intentAnchor: SonosPositionAnchor?
    public private(set) var pendingPlayState: SonosPending<SonosPlaybackState>?
    public private(set) var pendingSeek: SonosPending<Double>?

    public init() {}

    public var reportedState: SonosPlaybackState {
        SonosPlaybackState(sonos: status?.playbackState)
    }

    public var playState: SonosPlaybackState {
        pendingPlayState?.value ?? reportedState
    }

    /// True while the displayed position moves.
    public var isAdvancing: Bool {
        (intentAnchor ?? truthAnchor).advancing
    }

    public func position(at now: Date) -> Double {
        (intentAnchor ?? truthAnchor).position(at: now)
    }

    public mutating func apply(_ newStatus: PlaybackStatus, at now: Date) {
        status = newStatus
        let reported = SonosPlaybackState(sonos: newStatus.playbackState)
        truthAnchor = SonosPositionAnchor(millis: Double(newStatus.positionMillis), at: now, advancing: reported == .playing)

        if let pending = pendingPlayState {
            if !pending.isValid(at: now) || Self.confirms(reported, pending.value) {
                pendingPlayState = nil
            }
        }
        if let seek = pendingSeek {
            let expected = intentAnchor?.position(at: now) ?? seek.value
            if !seek.isValid(at: now) || abs(truthAnchor.position(at: now) - expected) <= SonosIntentTiming.seekToleranceMillis {
                pendingSeek = nil
            }
        }
        if pendingPlayState == nil && pendingSeek == nil {
            intentAnchor = nil
        }
    }

    /// Whether the reported state fulfils the requested one. Buffering is
    /// on the way to playing, so it keeps a play intent alive.
    public static func confirms(_ reported: SonosPlaybackState, _ requested: SonosPlaybackState) -> Bool {
        switch requested {
        case .playing:
            return reported == .playing
        case .paused, .idle:
            return reported == .paused || reported == .idle
        case .buffering:
            return reported.isActive
        }
    }

    public mutating func beginPlayIntent(_ target: SonosPlaybackState, at now: Date) {
        let current = position(at: now)
        pendingPlayState = SonosPending(value: target, deadline: now.addingTimeInterval(SonosIntentTiming.playState))
        intentAnchor = SonosPositionAnchor(millis: current, at: now, advancing: target == .playing)
    }

    public mutating func beginSeekIntent(to millis: Double, at now: Date) {
        pendingSeek = SonosPending(value: millis, deadline: now.addingTimeInterval(SonosIntentTiming.seek))
        intentAnchor = SonosPositionAnchor(millis: millis, at: now, advancing: playState == .playing)
    }

    public mutating func cancelPlayIntent() {
        pendingPlayState = nil
        if pendingSeek == nil { intentAnchor = nil }
    }

    public mutating func cancelSeekIntent() {
        pendingSeek = nil
        if pendingPlayState == nil { intentAnchor = nil }
    }

    public mutating func expireIntents(at now: Date) {
        if let pending = pendingPlayState, !pending.isValid(at: now) { pendingPlayState = nil }
        if let seek = pendingSeek, !seek.isValid(at: now) { pendingSeek = nil }
        if pendingPlayState == nil && pendingSeek == nil { intentAnchor = nil }
    }
}

// MARK: - Volume

/// Volume and mute of a group or player, merged with pending intents.
public struct SonosVolumeControlState: Equatable {
    public private(set) var volume: Int?
    public private(set) var muted: Bool?
    public private(set) var fixed = false
    public private(set) var pendingVolume: SonosPending<Int>?
    public private(set) var pendingMuted: SonosPending<Bool>?
    public private(set) var isDragging = false

    public init() {}

    public var displayedVolume: Int {
        pendingVolume?.value ?? volume ?? 0
    }

    public var displayedMuted: Bool {
        pendingMuted?.value ?? muted ?? false
    }

    public var isKnown: Bool {
        volume != nil
    }

    public mutating func apply(volume newVolume: Int, muted newMuted: Bool, fixed newFixed: Bool) {
        volume = newVolume
        muted = newMuted
        fixed = newFixed
        if let pending = pendingVolume, !isDragging, pending.value == newVolume {
            pendingVolume = nil
        }
        if let pending = pendingMuted, pending.value == newMuted {
            pendingMuted = nil
        }
    }

    /// While `dragging`, the slider owns the value; afterwards the players
    /// get `volumeSettle` seconds to confirm it.
    public mutating func beginVolumeIntent(_ value: Int, dragging: Bool, at now: Date) {
        isDragging = dragging
        let deadline = dragging ? Date.distantFuture : now.addingTimeInterval(SonosIntentTiming.volumeSettle)
        pendingVolume = SonosPending(value: min(max(value, 0), 100), deadline: deadline)
    }

    public mutating func beginMuteIntent(_ value: Bool, at now: Date) {
        pendingMuted = SonosPending(value: value, deadline: now.addingTimeInterval(SonosIntentTiming.mute))
    }

    public mutating func cancelVolumeIntent() {
        pendingVolume = nil
        isDragging = false
    }

    public mutating func cancelMuteIntent() {
        pendingMuted = nil
    }

    public mutating func expireIntents(at now: Date) {
        if let pending = pendingVolume, !pending.isValid(at: now) { pendingVolume = nil }
        if let pending = pendingMuted, !pending.isValid(at: now) { pendingMuted = nil }
    }
}

// MARK: - Observable models

/// One Sonos group as a card shows it. Identity is the coordinator, which
/// survives regrouping (the group id changes on every membership change).
@MainActor
@Observable
public final class SonosGroupModel: Identifiable {
    public nonisolated let coordinatorId: String
    public nonisolated var id: String { coordinatorId }

    public private(set) var groupId: String
    public private(set) var name: String
    public private(set) var playerIds: [String]
    public private(set) var isLive = false

    public private(set) var playback = SonosPlaybackControlState()
    public private(set) var volume = SonosVolumeControlState()
    public private(set) var metadata: PlaybackMetadata?
    /// Bumped on every metadata change (PlaybackMetadata isn't Equatable).
    public private(set) var metadataRevision = 0
    public private(set) var pendingSkip: SonosPending<Bool>?
    public private(set) var lastPlaybackError: String?

    public init(coordinatorId: String, groupId: String, name: String, playerIds: [String]) {
        self.coordinatorId = coordinatorId
        self.groupId = groupId
        self.name = name
        self.playerIds = playerIds
    }

    // MARK: Derived

    public var playState: SonosPlaybackState { playback.playState }
    public var isPlaying: Bool { playback.playState.isActive }
    public var isGrouped: Bool { playerIds.count > 1 }
    public var isSkipping: Bool { pendingSkip != nil }

    public var durationMillis: Int? {
        metadata?.currentItem?.track?.durationMillis
    }

    public var actions: PlaybackActions {
        playback.status?.availablePlaybackActions ?? PlaybackActions()
    }

    public var playModes: PlayModes {
        playback.status?.playModes ?? PlayModes()
    }

    /// Position to display, clamped to the track length when known.
    public func positionMillis(at now: Date) -> Double {
        let raw = playback.position(at: now)
        if let duration = durationMillis, duration > 0 {
            return min(raw, Double(duration))
        }
        return raw
    }

    /// Name of what is playing, for grouping suggestions.
    public var contentName: String? {
        metadata?.container?.name ?? metadata?.currentItem?.track?.name
    }

    public var hasContent: Bool {
        metadata?.currentItem?.track != nil || metadata?.container != nil
    }

    // MARK: Reducers

    public func update(from group: Group) {
        if groupId != group.id { groupId = group.id }
        if name != group.name { name = group.name }
        if playerIds != group.playerIds { playerIds = group.playerIds }
    }

    public func setLive(_ live: Bool) {
        if isLive != live { isLive = live }
    }

    public func applyPlayback(_ status: PlaybackStatus, at now: Date) {
        playback.apply(status, at: now)
        if lastPlaybackError != nil, SonosPlaybackState(sonos: status.playbackState) == .playing {
            lastPlaybackError = nil
        }
    }

    public func applyMetadata(_ newMetadata: PlaybackMetadata) {
        metadata = newMetadata
        metadataRevision &+= 1
        pendingSkip = nil
    }

    public func applyVolume(_ groupVolume: GroupVolume) {
        var next = volume
        next.apply(volume: groupVolume.volume, muted: groupVolume.muted, fixed: groupVolume.fixed)
        if next != volume { volume = next }
    }

    public func applyPlaybackError(_ message: String) {
        lastPlaybackError = message
    }

    // MARK: Intents

    public func beginPlayIntent(_ target: SonosPlaybackState, at now: Date) { playback.beginPlayIntent(target, at: now) }
    public func beginSeekIntent(to millis: Double, at now: Date) { playback.beginSeekIntent(to: millis, at: now) }
    public func cancelPlayIntent() { playback.cancelPlayIntent() }
    public func cancelSeekIntent() { playback.cancelSeekIntent() }
    public func beginVolumeIntent(_ value: Int, dragging: Bool, at now: Date) { volume.beginVolumeIntent(value, dragging: dragging, at: now) }
    public func beginMuteIntent(_ value: Bool, at now: Date) { volume.beginMuteIntent(value, at: now) }
    public func cancelVolumeIntent() { volume.cancelVolumeIntent() }
    public func cancelMuteIntent() { volume.cancelMuteIntent() }

    public func beginSkip(at now: Date) {
        pendingSkip = SonosPending(value: true, deadline: now.addingTimeInterval(SonosIntentTiming.skip))
    }

    public func cancelSkip() {
        pendingSkip = nil
    }

    public func expireIntents(at now: Date) {
        var nextPlayback = playback
        nextPlayback.expireIntents(at: now)
        if nextPlayback != playback { playback = nextPlayback }
        var nextVolume = volume
        nextVolume.expireIntents(at: now)
        if nextVolume != volume { volume = nextVolume }
        if let skip = pendingSkip, !skip.isValid(at: now) { pendingSkip = nil }
    }
}

/// One speaker (room): name and its own volume.
@MainActor
@Observable
public final class SonosPlayerModel: Identifiable {
    public nonisolated let id: String
    public private(set) var name: String
    public private(set) var isLive = false
    public private(set) var volume = SonosVolumeControlState()

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    public func rename(_ newName: String) {
        if name != newName { name = newName }
    }

    public func setLive(_ live: Bool) {
        if isLive != live { isLive = live }
    }

    public func applyVolume(_ playerVolume: PlayerVolume) {
        var next = volume
        next.apply(volume: playerVolume.volume, muted: playerVolume.muted, fixed: playerVolume.fixed)
        if next != volume { volume = next }
    }

    public func beginVolumeIntent(_ value: Int, dragging: Bool, at now: Date) { volume.beginVolumeIntent(value, dragging: dragging, at: now) }
    public func beginMuteIntent(_ value: Bool, at now: Date) { volume.beginMuteIntent(value, at: now) }
    public func cancelVolumeIntent() { volume.cancelVolumeIntent() }
    public func cancelMuteIntent() { volume.cancelMuteIntent() }

    public func expireIntents(at now: Date) {
        var next = volume
        next.expireIntents(at: now)
        if next != volume { volume = next }
    }
}

// MARK: - Household state

/// Groups, players and connection health of the household, updated by
/// `apply(_:at:)` from live events and fallback polls alike.
@MainActor
@Observable
public final class SonosLiveState {
    /// Groups sorted by name; the household view applies the saved order.
    public private(set) var groups: [SonosGroupModel] = []
    public private(set) var players: [String: SonosPlayerModel] = [:]
    public private(set) var connectionStates: [String: SonosLiveConnectionState] = [:]

    @ObservationIgnored private var modelsByCoordinator: [String: SonosGroupModel] = [:]
    @ObservationIgnored private var coordinatorByGroupId: [String: String] = [:]

    public init() {}

    public func group(coordinatorId: String) -> SonosGroupModel? {
        modelsByCoordinator[coordinatorId]
    }

    public func group(groupId: String) -> SonosGroupModel? {
        guard let coordinatorId = coordinatorByGroupId[groupId] ?? Self.coordinatorId(fromGroupId: groupId) else { return nil }
        return modelsByCoordinator[coordinatorId]
    }

    /// The group the room currently belongs to.
    public func group(containing playerId: String) -> SonosGroupModel? {
        groups.first { $0.playerIds.contains(playerId) }
    }

    public func player(_ playerId: String) -> SonosPlayerModel? {
        players[playerId]
    }

    /// Players whose socket is up, out of all players.
    public var liveCount: (live: Int, total: Int) {
        (players.values.filter(\.isLive).count, players.count)
    }

    public func apply(_ event: SonosLiveEvent, at now: Date = Date()) {
        switch event {
        case .topology(let groups, let players):
            applyTopology(groups: groups, players: players)
        case .playbackStatus(let groupId, let status):
            group(groupId: groupId)?.applyPlayback(status, at: now)
        case .metadataStatus(let groupId, let metadata):
            group(groupId: groupId)?.applyMetadata(metadata)
        case .groupVolume(let groupId, let volume):
            group(groupId: groupId)?.applyVolume(volume)
        case .playerVolume(let playerId, let volume):
            players[playerId]?.applyVolume(volume)
        case .playbackError(let groupId, let errorCode, let reason):
            group(groupId: groupId)?.applyPlaybackError(reason ?? errorCode)
        case .connection(let playerId, let state):
            if connectionStates[playerId] != state {
                connectionStates[playerId] = state
            }
            modelsByCoordinator[playerId]?.setLive(state.isConnected)
            players[playerId]?.setLive(state.isConnected)
        }
    }

    public func reset() {
        groups = []
        players = [:]
        connectionStates = [:]
        modelsByCoordinator = [:]
        coordinatorByGroupId = [:]
    }

    private func applyTopology(groups newGroups: [Group], players newPlayers: [Player]) {
        var models: [String: SonosGroupModel] = [:]
        var mapping: [String: String] = [:]
        for group in newGroups {
            let model = modelsByCoordinator[group.coordinatorId]
                ?? SonosGroupModel(coordinatorId: group.coordinatorId, groupId: group.id, name: group.name, playerIds: group.playerIds)
            model.update(from: group)
            model.setLive(connectionStates[group.coordinatorId]?.isConnected ?? false)
            models[group.coordinatorId] = model
            mapping[group.id] = group.coordinatorId
        }
        modelsByCoordinator = models
        coordinatorByGroupId = mapping

        let sorted = models.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        if sorted.map(\.coordinatorId) != groups.map(\.coordinatorId) {
            groups = sorted
        }

        var nextPlayers: [String: SonosPlayerModel] = [:]
        for player in newPlayers {
            let model = players[player.id] ?? SonosPlayerModel(id: player.id, name: player.name)
            model.rename(player.name)
            model.setLive(connectionStates[player.id]?.isConnected ?? false)
            nextPlayers[player.id] = model
        }
        if Set(nextPlayers.keys) != Set(players.keys) {
            players = nextPlayers
        }
    }

    /// Group ids have the form `<coordinator player id>:<sequence>`.
    public nonisolated static func coordinatorId(fromGroupId groupId: String) -> String? {
        guard let colon = groupId.firstIndex(of: ":"), colon != groupId.startIndex else { return nil }
        return String(groupId[..<colon])
    }
}
