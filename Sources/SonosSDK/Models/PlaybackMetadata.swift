//
//  PlaybackMetadata.swift
//  SonosSDK
//
//  Enhanced with complete API support for radio, TV, podcasts, and audiobooks
//

import Foundation
import SwiftyJSON

public struct PlaybackMetadata {
    public var container: ContainerMetadata?
    public var currentItem: Item?
    public var nextItem: Item?
    public var currentShow: CurrentShow?        // NEW: For radio stations
    public var streamInfo: String?              // NEW: For stations without detailed metadata
    public var playbackSessionInfo: PlaybackSessionInfo? // NEW: External source details

    public init?(_ data: Any) {
        let json = JSON(data)

        // Make all fields optional since they may not be present
        self.container = json["container"].dictionary != nil ? ContainerMetadata(json["container"].dictionaryValue) : nil
        self.currentItem = json["currentItem"].dictionary != nil ? Item(json["currentItem"].dictionaryValue) : nil
        self.nextItem = json["nextItem"].dictionary != nil ? Item(json["nextItem"].dictionaryValue) : nil
        self.currentShow = json["currentShow"].dictionary != nil ? CurrentShow(json["currentShow"].dictionaryValue) : nil
        self.streamInfo = json["streamInfo"].string
        self.playbackSessionInfo = json["playbackSession"].dictionary != nil ? PlaybackSessionInfo(json["playbackSession"].dictionaryValue) : nil
    }
}

// MARK: - Container Metadata

public struct ContainerMetadata {
    public var name: String?
    public var type: String?
    public var id: IdMetadata?
    public var service: ServiceMetadata?
    public var imageUrl: String?
    public var images: [ImageObject]?
    public var book: Book?          // NEW: For audiobooks
    public var podcast: Podcast?    // NEW: For podcasts

    init(_ data: [String: JSON]) {
        let json = JSON(data)
        self.name = json["name"].string
        self.type = json["type"].string
        self.id = json["id"].dictionary != nil ? IdMetadata(json["id"].dictionaryValue) : nil
        self.service = json["service"].dictionary != nil ? ServiceMetadata(json["service"].dictionaryValue) : nil
        self.imageUrl = json["imageUrl"].string
        self.images = json["images"].array?.compactMap { ImageObject($0.dictionaryObject ?? [:]) }
        self.book = json["book"].dictionary != nil ? Book(json["book"].dictionaryValue) : nil
        self.podcast = json["podcast"].dictionary != nil ? Podcast(json["podcast"].dictionaryValue) : nil
    }
}

// MARK: - Item (Current/Next Track)

public struct Item {
    public var id: String?
    public var track: Track?
    public var policies: Policies?

    init(_ data: [String: JSON]) {
        let json = JSON(data)
        self.id = json["id"].string
        self.track = json["track"].dictionary != nil ? Track(json["track"].dictionaryValue) : nil
        self.policies = json["policies"].dictionary != nil ? Policies(json["policies"].dictionaryValue) : nil
    }
}

// MARK: - Track

public struct Track {
    public var type: String?
    public var name: String?
    public var mediaUrl: String?
    public var imageUrl: String?
    public var images: [ImageObject]?
    public var contentType: String?
    public var album: Album?
    public var artist: Artist?
    public var author: Author?              // NEW: For audiobooks
    public var book: Book?                  // NEW: For audiobooks
    public var narrator: Narrator?          // NEW: For audiobooks
    public var podcast: Podcast?            // NEW: For podcast episodes
    public var producer: Producer?          // NEW: For podcasts
    public var releaseDate: String?         // NEW
    public var episodeNumber: Int?          // NEW: For podcasts
    public var id: IdMetadata?
    public var service: ServiceMetadata?
    public var durationMillis: Int?
    public var trackNumber: Int?            // NEW
    public var chapterNumber: Int?          // NEW: For audiobooks
    public var tags: [String]?              // NEW (deprecated in API but may exist)
    public var quality: Quality?
    public var deleted: Bool?               // NEW

    init(_ data: [String: JSON]) {
        let json = JSON(data)
        self.type = json["type"].string
        self.name = json["name"].string
        self.mediaUrl = json["mediaUrl"].string
        self.imageUrl = json["imageUrl"].string
        self.images = json["images"].array?.compactMap { ImageObject($0.dictionaryObject ?? [:]) }
        self.contentType = json["contentType"].string
        self.album = json["album"].dictionary != nil ? Album(json["album"].dictionaryValue) : nil
        self.artist = json["artist"].dictionary != nil ? Artist(json["artist"].dictionaryValue) : nil
        self.author = json["author"].dictionary != nil ? Author(json["author"].dictionaryValue) : nil
        self.book = json["book"].dictionary != nil ? Book(json["book"].dictionaryValue) : nil
        self.narrator = json["narrator"].dictionary != nil ? Narrator(json["narrator"].dictionaryValue) : nil
        self.podcast = json["podcast"].dictionary != nil ? Podcast(json["podcast"].dictionaryValue) : nil
        self.producer = json["producer"].dictionary != nil ? Producer(json["producer"].dictionaryValue) : nil
        self.releaseDate = json["releaseDate"].string
        self.episodeNumber = json["episodeNumber"].int
        self.id = json["id"].dictionary != nil ? IdMetadata(json["id"].dictionaryValue) : nil
        self.service = json["service"].dictionary != nil ? ServiceMetadata(json["service"].dictionaryValue) : nil
        self.durationMillis = json["durationMillis"].int
        self.trackNumber = json["trackNumber"].int
        self.chapterNumber = json["chapterNumber"].int
        self.tags = json["tags"].array?.compactMap { $0.string }
        self.quality = json["quality"].dictionary != nil ? Quality(json["quality"].dictionaryValue) : nil
        self.deleted = json["deleted"].bool
    }
}

// MARK: - Supporting Types

public struct IdMetadata {
    public var serviceId: String?
    public var objectId: String
    public var accountId: String?

    init(_ data: [String: JSON]) {
        let json = JSON(data)
        self.serviceId = json["serviceId"].string
        self.objectId = json["objectId"].string ?? ""
        self.accountId = json["accountId"].string
    }
}

public struct ServiceMetadata {
    public var name: String?
    public var id: String?
    public var imageUrl: String?
    public var images: [ImageObject]?

    init(_ data: [String: JSON]) {
        let json = JSON(data)
        self.name = json["name"].string
        self.id = json["id"].string
        self.imageUrl = json["imageUrl"].string
        self.images = json["images"].array?.compactMap { ImageObject($0.dictionaryObject ?? [:]) }
    }
}

public struct ImageObject {
    public var url: String?
    public var width: Int?
    public var height: Int?

    init(_ data: [String: Any]) {
        let json = JSON(data)
        self.url = json["url"].string
        self.width = json["width"].int
        self.height = json["height"].int
    }
}

public struct Album {
    public var name: String
    public var artist: Artist?
    public var id: IdMetadata?
    public var tags: [String]?

    init(_ data: [String: JSON]) {
        let json = JSON(data)
        self.name = json["name"].string ?? ""
        self.artist = json["artist"].dictionary != nil ? Artist(json["artist"].dictionaryValue) : nil
        self.id = json["id"].dictionary != nil ? IdMetadata(json["id"].dictionaryValue) : nil
        self.tags = json["tags"].array?.compactMap { $0.string }
    }
}

public struct Artist {
    public var name: String
    public var id: IdMetadata?
    public var tags: [String]?

    init(_ data: [String: JSON]) {
        let json = JSON(data)
        self.name = json["name"].string ?? ""
        self.id = json["id"].dictionary != nil ? IdMetadata(json["id"].dictionaryValue) : nil
        self.tags = json["tags"].array?.compactMap { $0.string }
    }
}

// MARK: - Audiobook Support

public struct Author {
    public var name: String
    public var id: IdMetadata?
    public var tags: [String]?

    init(_ data: [String: JSON]) {
        let json = JSON(data)
        self.name = json["name"].string ?? ""
        self.id = json["id"].dictionary != nil ? IdMetadata(json["id"].dictionaryValue) : nil
        self.tags = json["tags"].array?.compactMap { $0.string }
    }
}

public struct Book {
    public var name: String
    public var chapterCount: Int?
    public var author: Author?
    public var narrator: Narrator?
    public var id: IdMetadata?

    init(_ data: [String: JSON]) {
        let json = JSON(data)
        self.name = json["name"].string ?? ""
        self.chapterCount = json["chapterCount"].int
        self.author = json["author"].dictionary != nil ? Author(json["author"].dictionaryValue) : nil
        self.narrator = json["narrator"].dictionary != nil ? Narrator(json["narrator"].dictionaryValue) : nil
        self.id = json["id"].dictionary != nil ? IdMetadata(json["id"].dictionaryValue) : nil
    }
}

public struct Narrator {
    public var name: String
    public var id: IdMetadata?
    public var tags: [String]?

    init(_ data: [String: JSON]) {
        let json = JSON(data)
        self.name = json["name"].string ?? ""
        self.id = json["id"].dictionary != nil ? IdMetadata(json["id"].dictionaryValue) : nil
        self.tags = json["tags"].array?.compactMap { $0.string }
    }
}

// MARK: - Podcast Support

public struct Podcast {
    public var name: String
    public var producer: Producer?
    public var id: IdMetadata?

    init(_ data: [String: JSON]) {
        let json = JSON(data)
        self.name = json["name"].string ?? ""
        self.producer = json["producer"].dictionary != nil ? Producer(json["producer"].dictionaryValue) : nil
        self.id = json["id"].dictionary != nil ? IdMetadata(json["id"].dictionaryValue) : nil
    }
}

public struct Producer {
    public var name: String
    public var id: IdMetadata?
    public var tags: [String]?

    init(_ data: [String: JSON]) {
        let json = JSON(data)
        self.name = json["name"].string ?? ""
        self.id = json["id"].dictionary != nil ? IdMetadata(json["id"].dictionaryValue) : nil
        self.tags = json["tags"].array?.compactMap { $0.string }
    }
}

// MARK: - Radio Support

public struct CurrentShow {
    public var name: String
    public var id: IdMetadata?
    public var imageUrl: String?
    public var images: [ImageObject]?
    public var tags: [String]?

    init(_ data: [String: JSON]) {
        let json = JSON(data)
        self.name = json["name"].string ?? ""
        self.id = json["id"].dictionary != nil ? IdMetadata(json["id"].dictionaryValue) : nil
        self.imageUrl = json["imageUrl"].string
        self.images = json["images"].array?.compactMap { ImageObject($0.dictionaryObject ?? [:]) }
        self.tags = json["tags"].array?.compactMap { $0.string }
    }
}

// MARK: - Quality

public struct Quality {
    public var bitDepth: Int?
    public var sampleRate: Int?
    public var codec: String?
    public var lossless: Bool?
    public var immersive: Bool?
    public var replayGain: Float?

    init(_ data: [String: JSON]) {
        let json = JSON(data)
        self.bitDepth = json["bitDepth"].int
        self.sampleRate = json["sampleRate"].int
        self.codec = json["codec"].string
        self.lossless = json["lossless"].bool
        self.immersive = json["immersive"].bool
        self.replayGain = json["replayGain"].float
    }
}

// MARK: - Policies

public struct Policies {
    public var canSkip: Bool?
    public var canSkipBack: Bool?               // Deprecated but may exist
    public var canSkipToPrevious: Bool?
    public var limitedSkips: Bool?
    public var canSeek: Bool?
    public var canSkipToItem: Bool?
    public var canRepeat: Bool?
    public var canRepeatOne: Bool?
    public var canCrossfade: Bool?
    public var canShuffle: Bool?
    public var canResume: Bool?
    public var pauseAtEndOfQueue: Bool?
    public var refreshAuthWhilePaused: Bool?
    public var showNNextTracks: Int?
    public var showNPreviousTracks: Int?
    public var isVisible: Bool?
    public var notifyUserIntent: Bool?
    public var pauseTtlSec: Int?
    public var playTtlSec: Int?
    public var pauseOnDuck: Bool?
    public var skipsRemaining: Int?

    init(_ data: [String: JSON]) {
        let json = JSON(data)
        self.canSkip = json["canSkip"].bool
        self.canSkipBack = json["canSkipBack"].bool
        self.canSkipToPrevious = json["canSkipToPrevious"].bool
        self.limitedSkips = json["limitedSkips"].bool
        self.canSeek = json["canSeek"].bool
        self.canSkipToItem = json["canSkipToItem"].bool
        self.canRepeat = json["canRepeat"].bool
        self.canRepeatOne = json["canRepeatOne"].bool
        self.canCrossfade = json["canCrossfade"].bool
        self.canShuffle = json["canShuffle"].bool
        self.canResume = json["canResume"].bool
        self.pauseAtEndOfQueue = json["pauseAtEndOfQueue"].bool
        self.refreshAuthWhilePaused = json["refreshAuthWhilePaused"].bool
        self.showNNextTracks = json["showNNextTracks"].int
        self.showNPreviousTracks = json["showNPreviousTracks"].int
        self.isVisible = json["isVisible"].bool
        self.notifyUserIntent = json["notifyUserIntent"].bool
        self.pauseTtlSec = json["pauseTtlSec"].int
        self.playTtlSec = json["playTtlSec"].int
        self.pauseOnDuck = json["pauseOnDuck"].bool
        self.skipsRemaining = json["skipsRemaining"].int
    }
}

// MARK: - Playback Session Info (External Source)

public struct PlaybackSessionInfo {
    public var clientId: String
    public var isSuspended: Bool
    public var accountId: String

    init(_ data: [String: JSON]) {
        let json = JSON(data)
        self.clientId = json["clientId"].string ?? ""
        self.isSuspended = json["isSuspended"].bool ?? false
        self.accountId = json["accountId"].string ?? ""
    }
}
