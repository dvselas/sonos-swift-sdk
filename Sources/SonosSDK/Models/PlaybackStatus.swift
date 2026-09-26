//
//  PlaybackStatus.swift
//  SonosSDK
//
//  Created by James Hickman on 2/23/21.
//

import Foundation

public struct PlaybackStatus: Codable, Sendable, Equatable {

    public let availablePlaybackActions: PlaybackActions
    public let itemId: String?
    public let isDucking: Bool
    /// `PLAYBACK_STATE_IDLE`, `…_BUFFERING`, `…_PAUSED` or `…_PLAYING`.
    public let playbackState: String
    public let playModes: PlayModes
    public let positionMillis: UInt
    public let previousItemId: String?
    public let previousPositionMillis: UInt
    public let queueVersion: String?

    public init(
        availablePlaybackActions: PlaybackActions = PlaybackActions(),
        itemId: String? = nil,
        isDucking: Bool = false,
        playbackState: String,
        playModes: PlayModes = PlayModes(),
        positionMillis: UInt = 0,
        previousItemId: String? = nil,
        previousPositionMillis: UInt = 0,
        queueVersion: String? = nil
    ) {
        self.availablePlaybackActions = availablePlaybackActions
        self.itemId = itemId
        self.isDucking = isDucking
        self.playbackState = playbackState
        self.playModes = playModes
        self.positionMillis = positionMillis
        self.previousItemId = previousItemId
        self.previousPositionMillis = previousPositionMillis
        self.queueVersion = queueVersion
    }

    enum CodingKeys: String, CodingKey {
        case availablePlaybackActions, itemId, isDucking, playbackState, playModes
        case positionMillis, previousItemId, previousPositionMillis, queueVersion
    }

    /// Tolerant: only `playbackState` is required, so pushed events that
    /// omit optional fields are not dropped.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        playbackState = try c.decode(String.self, forKey: .playbackState)
        availablePlaybackActions = (try? c.decodeIfPresent(PlaybackActions.self, forKey: .availablePlaybackActions)) ?? PlaybackActions()
        itemId = try? c.decodeIfPresent(String.self, forKey: .itemId)
        isDucking = (try? c.decodeIfPresent(Bool.self, forKey: .isDucking)) ?? false
        playModes = (try? c.decodeIfPresent(PlayModes.self, forKey: .playModes)) ?? PlayModes()
        positionMillis = Self.decodeMillis(c, .positionMillis)
        previousItemId = try? c.decodeIfPresent(String.self, forKey: .previousItemId)
        previousPositionMillis = Self.decodeMillis(c, .previousPositionMillis)
        queueVersion = try? c.decodeIfPresent(String.self, forKey: .queueVersion)
    }

    private static func decodeMillis(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> UInt {
        if let value = try? c.decodeIfPresent(UInt.self, forKey: key) { return value }
        if let value = try? c.decodeIfPresent(Double.self, forKey: key), value > 0 { return UInt(value) }
        return 0
    }
}

public struct PlayModes: Codable, Sendable, Equatable {

    public let shuffle: Bool
    public let repeatOne: Bool
    public let crossfade: Bool
    public let `repeat`: Bool

    public init(shuffle: Bool = false, repeat repeatValue: Bool = false, repeatOne: Bool = false, crossfade: Bool = false) {
        self.shuffle = shuffle
        self.`repeat` = repeatValue
        self.repeatOne = repeatOne
        self.crossfade = crossfade
    }

    enum CodingKeys: String, CodingKey {
        case shuffle, repeatOne, crossfade, `repeat`
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        shuffle = (try? c.decodeIfPresent(Bool.self, forKey: .shuffle)) ?? false
        repeatOne = (try? c.decodeIfPresent(Bool.self, forKey: .repeatOne)) ?? false
        crossfade = (try? c.decodeIfPresent(Bool.self, forKey: .crossfade)) ?? false
        `repeat` = (try? c.decodeIfPresent(Bool.self, forKey: .repeat)) ?? false
    }
}

public struct PlaybackActions: Codable, Sendable, Equatable {

    public let canCrossfade: Bool
    public let canRepeat: Bool
    public let canRepeatOne: Bool
    public let canResume: Bool
    public let canSeek: Bool
    public let canShuffle: Bool
    public let canSkip: Bool
    public let canSkipBack: Bool
    public let canSkipToItem: Bool
    public let limitedSkips: Bool
    public let notifyUserIntent: Bool
    public let pauseAtEndOfQueue: Bool
    public let pauseOnDuck: Bool
    public let pauseTtlSec: Int
    public let playTtlSec: Int
    public let refreshAuthWhilePaused: Bool
    public let showNNextTracks: Int
    public let showNPreviousTracks: Int
    public let skipsRemaining: Int

    public init(
        canCrossfade: Bool = false,
        canRepeat: Bool = false,
        canRepeatOne: Bool = false,
        canResume: Bool = false,
        canSeek: Bool = false,
        canShuffle: Bool = false,
        canSkip: Bool = false,
        canSkipBack: Bool = false,
        canSkipToItem: Bool = false,
        limitedSkips: Bool = false,
        notifyUserIntent: Bool = false,
        pauseAtEndOfQueue: Bool = false,
        pauseOnDuck: Bool = false,
        pauseTtlSec: Int = 0,
        playTtlSec: Int = 0,
        refreshAuthWhilePaused: Bool = false,
        showNNextTracks: Int = 0,
        showNPreviousTracks: Int = 0,
        skipsRemaining: Int = 0
    ) {
        self.canCrossfade = canCrossfade
        self.canRepeat = canRepeat
        self.canRepeatOne = canRepeatOne
        self.canResume = canResume
        self.canSeek = canSeek
        self.canShuffle = canShuffle
        self.canSkip = canSkip
        self.canSkipBack = canSkipBack
        self.canSkipToItem = canSkipToItem
        self.limitedSkips = limitedSkips
        self.notifyUserIntent = notifyUserIntent
        self.pauseAtEndOfQueue = pauseAtEndOfQueue
        self.pauseOnDuck = pauseOnDuck
        self.pauseTtlSec = pauseTtlSec
        self.playTtlSec = playTtlSec
        self.refreshAuthWhilePaused = refreshAuthWhilePaused
        self.showNNextTracks = showNNextTracks
        self.showNPreviousTracks = showNPreviousTracks
        self.skipsRemaining = skipsRemaining
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.canCrossfade = (try? container.decode(Bool.self, forKey: .canCrossfade)) ?? false
        self.canRepeat = (try? container.decode(Bool.self, forKey: .canRepeat)) ?? false
        self.canRepeatOne = (try? container.decode(Bool.self, forKey: .canRepeatOne)) ?? false
        self.canResume = (try? container.decode(Bool.self, forKey: .canResume)) ?? false
        self.canSeek = (try? container.decode(Bool.self, forKey: .canSeek)) ?? false
        self.canShuffle = (try? container.decode(Bool.self, forKey: .canShuffle)) ?? false
        self.canSkip = (try? container.decode(Bool.self, forKey: .canSkip)) ?? false
        self.canSkipBack = (try? container.decode(Bool.self, forKey: .canSkipBack)) ?? false
        self.canSkipToItem = (try? container.decode(Bool.self, forKey: .canSkipToItem)) ?? false
        self.limitedSkips = (try? container.decode(Bool.self, forKey: .limitedSkips)) ?? false
        self.notifyUserIntent = (try? container.decode(Bool.self, forKey: .notifyUserIntent)) ?? false
        self.pauseAtEndOfQueue = (try? container.decode(Bool.self, forKey: .pauseAtEndOfQueue)) ?? false
        self.pauseOnDuck = (try? container.decode(Bool.self, forKey: .pauseOnDuck)) ?? false
        self.pauseTtlSec = (try? container.decode(Int.self, forKey: .pauseTtlSec)) ?? 0
        self.playTtlSec = (try? container.decode(Int.self, forKey: .playTtlSec)) ?? 0
        self.refreshAuthWhilePaused = (try? container.decode(Bool.self, forKey: .refreshAuthWhilePaused)) ?? false
        self.showNNextTracks = (try? container.decode(Int.self, forKey: .showNNextTracks)) ?? 0
        self.showNPreviousTracks = (try? container.decode(Int.self, forKey: .showNPreviousTracks)) ?? 0
        self.skipsRemaining = (try? container.decode(Int.self, forKey: .skipsRemaining)) ?? 0
    }
}
