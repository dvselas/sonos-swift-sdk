//
//  PlaybackMetadata.swift
//  SonosSDK
//
//  Enhanced with complete API support for radio, TV, podcasts, and audiobooks
//

import Foundation

public struct PlaybackMetadata: Codable, Sendable {
    public let container: ContainerMetadata?
    public let currentItem: Item?
    public let nextItem: Item?
    public let currentShow: CurrentShow?
    public let streamInfo: String?
    public let playbackSession: PlaybackSessionInfo?

    enum CodingKeys: String, CodingKey {
        case container, currentItem, nextItem, currentShow, streamInfo, playbackSession
    }
}

// MARK: - Container Metadata

public struct ContainerMetadata: Codable, Sendable {
    public let name: String?
    public let type: String?
    public let id: IdMetadata?
    public let service: ServiceMetadata?
    public let imageUrl: String?
    public let images: [ImageObject]?
    public let book: Book?
    public let podcast: Podcast?
}

// MARK: - Item (Current/Next Track)

public struct Item: Codable, Sendable {
    public let id: String?
    public let track: Track?
    public let policies: Policies?
}

// MARK: - Track

public struct Track: Codable, Sendable {
    public let type: String?
    public let name: String?
    public let mediaUrl: String?
    public let imageUrl: String?
    public let images: [ImageObject]?
    public let contentType: String?
    public let album: Album?
    public let artist: Artist?
    public let author: Author?
    public let book: Book?
    public let narrator: Narrator?
    public let podcast: Podcast?
    public let producer: Producer?
    public let releaseDate: String?
    public let episodeNumber: Int?
    public let id: IdMetadata?
    public let service: ServiceMetadata?
    public let durationMillis: Int?
    public let trackNumber: Int?
    public let chapterNumber: Int?
    public let tags: [String]?
    public let quality: Quality?
    public let deleted: Bool?
}

// MARK: - Supporting Types

public struct IdMetadata: Codable, Sendable {
    public let serviceId: String?
    public let objectId: String?
    public let accountId: String?
}

public struct ServiceMetadata: Codable, Sendable {
    public let name: String?
    public let id: String?
    public let imageUrl: String?
    public let images: [ImageObject]?
}

public struct ImageObject: Codable, Sendable {
    public let url: String?
    public let width: Int?
    public let height: Int?
}

public struct Album: Codable, Sendable {
    public let name: String?
    public let artist: Artist?
    public let id: IdMetadata?
    public let tags: [String]?
}

public struct Artist: Codable, Sendable {
    public let name: String?
    public let id: IdMetadata?
    public let tags: [String]?
}

// MARK: - Audiobook Support

public struct Author: Codable, Sendable {
    public let name: String?
    public let id: IdMetadata?
    public let tags: [String]?
}

public struct Book: Codable, Sendable {
    public let name: String?
    public let chapterCount: Int?
    public let author: Author?
    public let narrator: Narrator?
    public let id: IdMetadata?
}

public struct Narrator: Codable, Sendable {
    public let name: String?
    public let id: IdMetadata?
    public let tags: [String]?
}

// MARK: - Podcast Support

public struct Podcast: Codable, Sendable {
    public let name: String?
    public let producer: Producer?
    public let id: IdMetadata?
}

public struct Producer: Codable, Sendable {
    public let name: String?
    public let id: IdMetadata?
    public let tags: [String]?
}

// MARK: - Radio Support

public struct CurrentShow: Codable, Sendable {
    public let name: String?
    public let id: IdMetadata?
    public let imageUrl: String?
    public let images: [ImageObject]?
    public let tags: [String]?
}

// MARK: - Quality

public struct Quality: Codable, Sendable {
    public let bitDepth: Int?
    public let sampleRate: Int?
    public let codec: String?
    public let lossless: Bool?
    public let immersive: Bool?
    public let replayGain: Float?
}

// MARK: - Policies

public struct Policies: Codable, Sendable {
    public let canSkip: Bool?
    public let canSkipBack: Bool?
    public let canSkipToPrevious: Bool?
    public let limitedSkips: Bool?
    public let canSeek: Bool?
    public let canSkipToItem: Bool?
    public let canRepeat: Bool?
    public let canRepeatOne: Bool?
    public let canCrossfade: Bool?
    public let canShuffle: Bool?
    public let canResume: Bool?
    public let pauseAtEndOfQueue: Bool?
    public let refreshAuthWhilePaused: Bool?
    public let showNNextTracks: Int?
    public let showNPreviousTracks: Int?
    public let isVisible: Bool?
    public let notifyUserIntent: Bool?
    public let pauseTtlSec: Int?
    public let playTtlSec: Int?
    public let pauseOnDuck: Bool?
    public let skipsRemaining: Int?
}

// MARK: - Playback Session Info (External Source)

public struct PlaybackSessionInfo: Codable, Sendable {
    public let clientId: String?
    public let isSuspended: Bool?
    public let accountId: String?
}
