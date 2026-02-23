//
//  SonosManager+Favorites.swift
//  SonosSDK
//

import Foundation

extension SonosManager {

    public func getFavorites(householdId: String) async throws -> [Favorite] {
        try await favoriteService.getFavorites(householdId: householdId)
    }

    public func loadFavorite(groupId: String, favoriteId: String, playOnCompletion: Bool? = true, action: String? = "REPLACE") async throws {
        try await favoriteService.loadFavorite(groupId: groupId, favoriteId: favoriteId, playOnCompletion: playOnCompletion, action: action)
    }

    public func subscribeToFavorites(householdId: String) async throws {
        try await favoriteService.subscribe(householdId: householdId)
    }

    public func unsubscribeFromFavorites(householdId: String) async throws {
        try await favoriteService.unsubscribe(householdId: householdId)
    }
}
