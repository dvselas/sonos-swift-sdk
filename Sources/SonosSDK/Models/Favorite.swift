//
//  Favorite.swift
//  SonosSDK
//
//  Created by James Hickman on 2/24/21.
//

import Foundation

public struct Favorite: Codable, Identifiable, Sendable {

    public let id: String
    public let name: String
    public let description: String?
    public let imageUrl: String?
    public let imageCompilation: [String]?
    public let service: FavoriteServiceInfo?
    /// What the favorite plays; missing in older answers.
    public let resource: FavoriteResource?

    /// A radio station or other stream: it plays instead of the queue and
    /// can't be added to it (loading it with APPEND switches to the stream).
    public var isStream: Bool {
        resource?.type == FavoriteResource.stream
    }
}

/// The content behind a favorite, e.g. `STREAM`, `PLAYLIST`, `ALBUM` or `TRACK`.
public struct FavoriteResource: Codable, Sendable {
    public static let stream = "STREAM"

    public let type: String?
}

/// Favorites response wrapper
struct FavoritesResponse: Codable {
    let items: [Favorite]
    let version: String?
}

/// Service info attached to a favorite (named to avoid conflict with FavoriteService class)
public struct FavoriteServiceInfo: Codable, Sendable {
    public let id: String?
    public let name: String?
    public let imageUrl: String?
}
