//
//  SubscriptionEvents.swift
//  SonosSDK
//
//  Created on 2025-01-22.
//

import Foundation
import SwiftyJSON

// MARK: - Base Event Protocol

public protocol SubscriptionEvent {
    var namespace: String { get }
    var type: String { get }
}

// MARK: - Playback Events

public enum PlaybackEvent: SubscriptionEvent {
    case stateChanged(PlaybackStateChangedEvent)
    case errorOccurred(PlaybackErrorEvent)

    public var namespace: String { "playback" }
    public var type: String {
        switch self {
        case .stateChanged: return "playbackStatus"
        case .errorOccurred: return "playbackError"
        }
    }

    init?(from json: JSON) {
        guard let type = json["type"].string else { return nil }

        switch type {
        case "playbackStatus":
            guard let event = PlaybackStateChangedEvent(json) else { return nil }
            self = .stateChanged(event)
        case "playbackError":
            guard let event = PlaybackErrorEvent(json) else { return nil }
            self = .errorOccurred(event)
        default:
            return nil
        }
    }
}

public struct PlaybackStateChangedEvent {
    public let groupId: String
    public let playbackState: String
    public let positionMillis: UInt?
    public let itemId: String?
    public let queueVersion: String?
    public let isDucking: Bool?
    public let timestamp: Date

    init?(_ json: JSON) {
        guard let groupId = json["groupId"].string,
              let playbackState = json["playbackState"].string else {
            return nil
        }

        self.groupId = groupId
        self.playbackState = playbackState
        self.positionMillis = json["positionMillis"].uInt
        self.itemId = json["itemId"].string
        self.queueVersion = json["queueVersion"].string
        self.isDucking = json["isDucking"].bool
        self.timestamp = Date()
    }
}

public struct PlaybackErrorEvent {
    public let groupId: String
    public let errorCode: String
    public let reason: String?
    public let timestamp: Date

    init?(_ json: JSON) {
        guard let groupId = json["groupId"].string,
              let errorCode = json["errorCode"].string else {
            return nil
        }

        self.groupId = groupId
        self.errorCode = errorCode
        self.reason = json["reason"].string
        self.timestamp = Date()
    }
}

// MARK: - Metadata Events

public enum MetadataEvent: SubscriptionEvent {
    case changed(MetadataChangedEvent)

    public var namespace: String { "playbackMetadata" }
    public var type: String { "metadataStatus" }

    init?(from json: JSON) {
        guard let event = MetadataChangedEvent(json) else { return nil }
        self = .changed(event)
    }
}

public struct MetadataChangedEvent {
    public let groupId: String
    public let currentItem: PlaybackMetadataItem?
    public let nextItem: PlaybackMetadataItem?
    public let container: PlaybackMetadataContainer?
    public let timestamp: Date

    init?(_ json: JSON) {
        guard let groupId = json["groupId"].string else { return nil }

        self.groupId = groupId
        self.currentItem = PlaybackMetadataItem(json["currentItem"])
        self.nextItem = PlaybackMetadataItem(json["nextItem"])
        self.container = PlaybackMetadataContainer(json["container"])
        self.timestamp = Date()
    }
}

public struct PlaybackMetadataItem {
    public let trackName: String?
    public let artistName: String?
    public let albumName: String?
    public let imageUrl: String?
    public let durationMillis: Int64?

    init?(_ json: JSON) {
        guard json.exists() else { return nil }

        let track = json["track"]
        self.trackName = track["name"].string
        self.artistName = track["artist"]["name"].string
        self.albumName = track["album"]["name"].string
        self.imageUrl = track["imageUrl"].string
        self.durationMillis = track["durationMillis"].int64
    }
}

public struct PlaybackMetadataContainer {
    public let name: String?
    public let type: String?
    public let imageUrl: String?

    init?(_ json: JSON) {
        guard json.exists() else { return nil }

        self.name = json["name"].string
        self.type = json["type"].string
        self.imageUrl = json["imageUrl"].string
    }
}

// MARK: - Volume Events

public enum GroupVolumeEvent: SubscriptionEvent {
    case changed(VolumeChangedEvent)

    public var namespace: String { "groupVolume" }
    public var type: String { "volumeChange" }

    init?(from json: JSON) {
        guard let event = VolumeChangedEvent(json, isGroup: true) else { return nil }
        self = .changed(event)
    }
}

public enum PlayerVolumeEvent: SubscriptionEvent {
    case changed(VolumeChangedEvent)

    public var namespace: String { "playerVolume" }
    public var type: String { "volumeChange" }

    init?(from json: JSON) {
        guard let event = VolumeChangedEvent(json, isGroup: false) else { return nil }
        self = .changed(event)
    }
}

public struct VolumeChangedEvent {
    public let id: String // groupId or playerId
    public let volume: Int
    public let muted: Bool
    public let fixed: Bool
    public let timestamp: Date
    public let isGroup: Bool

    init?(_ json: JSON, isGroup: Bool) {
        let id = isGroup ? json["groupId"].string : json["playerId"].string
        guard let validId = id,
              let volume = json["volume"].int,
              let muted = json["muted"].bool else {
            return nil
        }

        self.id = validId
        self.volume = volume
        self.muted = muted
        self.fixed = json["fixed"].bool ?? false
        self.timestamp = Date()
        self.isGroup = isGroup
    }
}

// MARK: - Group Events

public enum GroupEvent: SubscriptionEvent {
    case changed(GroupChangedEvent)
    case coordinatorChanged(GroupCoordinatorChangedEvent)

    public var namespace: String { "groups" }
    public var type: String {
        switch self {
        case .changed: return "groupChange"
        case .coordinatorChanged: return "groupCoordinatorChanged"
        }
    }

    init?(from json: JSON) {
        guard let type = json["type"].string else { return nil }

        switch type {
        case "groupChange":
            guard let event = GroupChangedEvent(json) else { return nil }
            self = .changed(event)
        case "groupCoordinatorChanged":
            guard let event = GroupCoordinatorChangedEvent(json) else { return nil }
            self = .coordinatorChanged(event)
        default:
            return nil
        }
    }
}

public struct GroupChangedEvent {
    public let groupId: String
    public let changeType: String // "CREATED", "UPDATED", "DELETED"
    public let playerIds: [String]?
    public let coordinatorId: String?
    public let name: String?
    public let timestamp: Date

    init?(_ json: JSON) {
        guard let groupId = json["groupId"].string,
              let changeType = json["groupStatus"].string else {
            return nil
        }

        self.groupId = groupId
        self.changeType = changeType
        self.playerIds = json["playerIds"].array?.compactMap { $0.string }
        self.coordinatorId = json["coordinatorId"].string
        self.name = json["name"].string
        self.timestamp = Date()
    }
}

public struct GroupCoordinatorChangedEvent {
    public let groupId: String
    public let coordinatorId: String
    public let previousCoordinatorId: String?
    public let timestamp: Date

    init?(_ json: JSON) {
        guard let groupId = json["groupId"].string,
              let coordinatorId = json["coordinatorId"].string else {
            return nil
        }

        self.groupId = groupId
        self.coordinatorId = coordinatorId
        self.previousCoordinatorId = json["previousCoordinatorId"].string
        self.timestamp = Date()
    }
}

// MARK: - Favorites Events

public enum FavoritesEvent: SubscriptionEvent {
    case changed(FavoritesChangedEvent)

    public var namespace: String { "favorites" }
    public var type: String { "favoritesChange" }

    init?(from json: JSON) {
        guard let event = FavoritesChangedEvent(json) else { return nil }
        self = .changed(event)
    }
}

public struct FavoritesChangedEvent {
    public let householdId: String
    public let version: String
    public let timestamp: Date

    init?(_ json: JSON) {
        guard let householdId = json["householdId"].string,
              let version = json["version"].string else {
            return nil
        }

        self.householdId = householdId
        self.version = version
        self.timestamp = Date()
    }
}

// MARK: - Playlists Events

public enum PlaylistsEvent: SubscriptionEvent {
    case changed(PlaylistsChangedEvent)

    public var namespace: String { "playlists" }
    public var type: String { "playlistsChange" }

    init?(from json: JSON) {
        guard let event = PlaylistsChangedEvent(json) else { return nil }
        self = .changed(event)
    }
}

public struct PlaylistsChangedEvent {
    public let householdId: String
    public let version: String
    public let timestamp: Date

    init?(_ json: JSON) {
        guard let householdId = json["householdId"].string,
              let version = json["version"].string else {
            return nil
        }

        self.householdId = householdId
        self.version = version
        self.timestamp = Date()
    }
}

// MARK: - AudioClip Events

public enum AudioClipEvent: SubscriptionEvent {
    case statusChanged(AudioClipStatusEvent)

    public var namespace: String { "audioClip" }
    public var type: String { "audioClipStatus" }

    init?(from json: JSON) {
        guard let event = AudioClipStatusEvent(json) else { return nil }
        self = .statusChanged(event)
    }
}

public struct AudioClipStatusEvent {
    public let playerId: String
    public let status: String // "ACTIVE", "DONE", "ERROR", "INTERRUPTED"
    public let clipId: String?
    public let errorCode: String?
    public let timestamp: Date

    init?(_ json: JSON) {
        guard let playerId = json["playerId"].string,
              let status = json["status"].string else {
            return nil
        }

        self.playerId = playerId
        self.status = status
        self.clipId = json["clipId"].string
        self.errorCode = json["errorCode"].string
        self.timestamp = Date()
    }
}

// MARK: - Event Parser

public class SubscriptionEventParser {

    public static func parse(message: WebSocketMessage) -> (any SubscriptionEvent)? {
        let json = JSON(message.data)

        switch message.namespace {
        case "playback":
            return PlaybackEvent(from: json)
        case "playbackMetadata":
            return MetadataEvent(from: json)
        case "groupVolume":
            return GroupVolumeEvent(from: json)
        case "playerVolume":
            return PlayerVolumeEvent(from: json)
        case "groups":
            return GroupEvent(from: json)
        case "favorites":
            return FavoritesEvent(from: json)
        case "playlists":
            return PlaylistsEvent(from: json)
        case "audioClip":
            return AudioClipEvent(from: json)
        default:
            return nil
        }
    }
}
