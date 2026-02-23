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
