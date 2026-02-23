//
//  PlaybackStatus.swift
//  SonosSDK
//
//  Created by James Hickman on 2/23/21.
//

import Foundation

public struct PlaybackStatus: Codable, Sendable {

    public let availablePlaybackActions: PlaybackActions
    public let itemId: String?
    public let isDucking: Bool
    public let playbackState: String
    public let playModes: PlayModes
    public let positionMillis: UInt
    public let previousItemId: String?
    public let previousPositionMillis: UInt
    public let queueVersion: String?
}

public struct PlayModes: Codable, Sendable {

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
}

public struct PlaybackActions: Codable, Sendable {

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
