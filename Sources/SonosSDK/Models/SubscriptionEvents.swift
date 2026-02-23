//
//  SubscriptionEvents.swift
//  SonosSDK
//
//  Created on 2025-01-22.
//

import Foundation

// MARK: - Base Event Protocol

public protocol SubscriptionEvent: Sendable {
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
}

public struct PlaybackStateChangedEvent: Codable, Sendable {
    public let groupId: String
    public let playbackState: String
    public let positionMillis: UInt?
    public let itemId: String?
    public let queueVersion: String?
    public let isDucking: Bool?
}

public struct PlaybackErrorEvent: Codable, Sendable {
    public let groupId: String
    public let errorCode: String
    public let reason: String?
}

// MARK: - Metadata Events

public enum MetadataEvent: SubscriptionEvent {
    case changed(MetadataChangedEvent)

    public var namespace: String { "playbackMetadata" }
    public var type: String { "metadataStatus" }
}

public struct MetadataChangedEvent: Codable, Sendable {
    public let groupId: String
    public let currentItem: MetadataItem?
    public let nextItem: MetadataItem?
    public let container: MetadataContainer?
}

public struct MetadataItem: Codable, Sendable {
    public let track: MetadataTrack?
}

public struct MetadataTrack: Codable, Sendable {
    public let name: String?
    public let artist: MetadataArtist?
    public let album: MetadataAlbum?
    public let imageUrl: String?
    public let durationMillis: Int64?
}

public struct MetadataArtist: Codable, Sendable {
    public let name: String?
}

public struct MetadataAlbum: Codable, Sendable {
    public let name: String?
}

public struct MetadataContainer: Codable, Sendable {
    public let name: String?
    public let type: String?
    public let imageUrl: String?
}

// MARK: - Volume Events

public enum GroupVolumeEvent: SubscriptionEvent {
    case changed(VolumeChangedEvent)

    public var namespace: String { "groupVolume" }
    public var type: String { "volumeChange" }
}

public enum PlayerVolumeEvent: SubscriptionEvent {
    case changed(VolumeChangedEvent)

    public var namespace: String { "playerVolume" }
    public var type: String { "volumeChange" }
}

public struct VolumeChangedEvent: Codable, Sendable {
    public let id: String
    public let volume: Int
    public let muted: Bool
    public let fixed: Bool
    public let isGroup: Bool

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.volume = try container.decode(Int.self, forKey: .volume)
        self.muted = try container.decode(Bool.self, forKey: .muted)
        self.fixed = (try? container.decode(Bool.self, forKey: .fixed)) ?? false

        // Try groupId first, then playerId
        if let groupId = try? container.decode(String.self, forKey: .groupId) {
            self.id = groupId
            self.isGroup = true
        } else if let playerId = try? container.decode(String.self, forKey: .playerId) {
            self.id = playerId
            self.isGroup = false
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Missing groupId or playerId"))
        }
    }

    enum CodingKeys: String, CodingKey {
        case groupId, playerId, volume, muted, fixed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(volume, forKey: .volume)
        try container.encode(muted, forKey: .muted)
        try container.encode(fixed, forKey: .fixed)
        if isGroup {
            try container.encode(id, forKey: .groupId)
        } else {
            try container.encode(id, forKey: .playerId)
        }
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
}

public struct GroupChangedEvent: Codable, Sendable {
    public let groupId: String
    public let groupStatus: String
    public let playerIds: [String]?
    public let coordinatorId: String?
    public let name: String?

    /// Alias for backward compatibility
    public var changeType: String { groupStatus }
}

public struct GroupCoordinatorChangedEvent: Codable, Sendable {
    public let groupId: String
    public let coordinatorId: String
    public let previousCoordinatorId: String?
}

// MARK: - Favorites Events

public enum FavoritesEvent: SubscriptionEvent {
    case changed(FavoritesChangedEvent)

    public var namespace: String { "favorites" }
    public var type: String { "favoritesChange" }
}

public struct FavoritesChangedEvent: Codable, Sendable {
    public let householdId: String
    public let version: String
}

// MARK: - Playlists Events

public enum PlaylistsEvent: SubscriptionEvent {
    case changed(PlaylistsChangedEvent)

    public var namespace: String { "playlists" }
    public var type: String { "playlistsChange" }
}

public struct PlaylistsChangedEvent: Codable, Sendable {
    public let householdId: String
    public let version: String
}

// MARK: - AudioClip Events

public enum AudioClipEvent: SubscriptionEvent {
    case statusChanged(AudioClipStatusEvent)

    public var namespace: String { "audioClip" }
    public var type: String { "audioClipStatus" }
}

public struct AudioClipStatusEvent: Codable, Sendable {
    public let playerId: String
    public let status: String
    public let clipId: String?
    public let errorCode: String?
}

// MARK: - Playback Session Events

public enum PlaybackSessionEvent: SubscriptionEvent {
    case sessionEvicted(SessionEvictedEvent)
    case sessionError(SessionErrorEvent)

    public var namespace: String { "playbackSession" }
    public var type: String {
        switch self {
        case .sessionEvicted: return "sessionEvicted"
        case .sessionError: return "sessionError"
        }
    }
}

public struct SessionEvictedEvent: Codable, Sendable {
    public let sessionId: String
    public let reason: String?
}

public struct SessionErrorEvent: Codable, Sendable {
    public let sessionId: String
    public let errorCode: String
    public let reason: String?
}

// MARK: - Event Parser

public final class SubscriptionEventParser {

    private static let decoder = JSONDecoder()

    public static func parse(message: WebSocketMessage) -> (any SubscriptionEvent)? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message.data) else {
            return nil
        }

        switch message.namespace {
        case "playback":
            return parsePlaybackEvent(from: jsonData, type: message.type)
        case "playbackMetadata":
            if let event = try? decoder.decode(MetadataChangedEvent.self, from: jsonData) {
                return MetadataEvent.changed(event)
            }
        case "groupVolume":
            if let event = try? decoder.decode(VolumeChangedEvent.self, from: jsonData) {
                return GroupVolumeEvent.changed(event)
            }
        case "playerVolume":
            if let event = try? decoder.decode(VolumeChangedEvent.self, from: jsonData) {
                return PlayerVolumeEvent.changed(event)
            }
        case "groups":
            return parseGroupEvent(from: jsonData, type: message.type)
        case "favorites":
            if let event = try? decoder.decode(FavoritesChangedEvent.self, from: jsonData) {
                return FavoritesEvent.changed(event)
            }
        case "playlists":
            if let event = try? decoder.decode(PlaylistsChangedEvent.self, from: jsonData) {
                return PlaylistsEvent.changed(event)
            }
        case "audioClip":
            if let event = try? decoder.decode(AudioClipStatusEvent.self, from: jsonData) {
                return AudioClipEvent.statusChanged(event)
            }
        case "playbackSession":
            return parsePlaybackSessionEvent(from: jsonData, type: message.type)
        default:
            break
        }

        return nil
    }

    private static func parsePlaybackEvent(from data: Data, type: String) -> PlaybackEvent? {
        switch type {
        case "playbackStatus":
            if let event = try? decoder.decode(PlaybackStateChangedEvent.self, from: data) {
                return .stateChanged(event)
            }
        case "playbackError":
            if let event = try? decoder.decode(PlaybackErrorEvent.self, from: data) {
                return .errorOccurred(event)
            }
        default:
            break
        }
        return nil
    }

    private static func parseGroupEvent(from data: Data, type: String) -> GroupEvent? {
        switch type {
        case "groupChange":
            if let event = try? decoder.decode(GroupChangedEvent.self, from: data) {
                return .changed(event)
            }
        case "groupCoordinatorChanged":
            if let event = try? decoder.decode(GroupCoordinatorChangedEvent.self, from: data) {
                return .coordinatorChanged(event)
            }
        default:
            break
        }
        return nil
    }

    private static func parsePlaybackSessionEvent(from data: Data, type: String) -> PlaybackSessionEvent? {
        switch type {
        case "sessionEvicted":
            if let event = try? decoder.decode(SessionEvictedEvent.self, from: data) {
                return .sessionEvicted(event)
            }
        case "sessionError":
            if let event = try? decoder.decode(SessionErrorEvent.self, from: data) {
                return .sessionError(event)
            }
        default:
            break
        }
        return nil
    }
}
