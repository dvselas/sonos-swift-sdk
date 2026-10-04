//
//  SonosContent.swift
//  SonosSDK
//
//  A music service item for `loadContent`: a Spotify track (`serviceId` 9,
//  `spotify:track:<id>`), an Apple Music album (`serviceId` 204,
//  `album:<id>`) and so on, played with one of the household's accounts.
//

import Foundation

public struct SonosContent: Codable, Hashable, Sendable {

    /// Sonos Content API resource type.
    public struct Kind: RawRepresentable, Codable, Hashable, Sendable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let track = Kind(rawValue: "TRACK")
        public static let album = Kind(rawValue: "ALBUM")
        public static let playlist = Kind(rawValue: "PLAYLIST")
    }

    public let kind: Kind
    public let serviceId: String
    public let objectId: String
    /// Account of the service in the household, e.g. `sn_5`. The players fall
    /// back to the service's default account for an id they don't know.
    public let accountId: String

    public init(kind: Kind, serviceId: String, objectId: String, accountId: String) {
        self.kind = kind
        self.serviceId = serviceId
        self.objectId = objectId
        self.accountId = accountId
    }
}

/// Well-known `serviceId`s.
public enum SonosServiceId {
    public static let spotify = "9"
    public static let appleMusic = "204"
}
