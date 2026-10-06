//
//  SonosManager+Favorites.swift
//  SonosSDK
//

import Foundation

extension SonosManager {

    public func getFavorites(householdId: String) async throws -> [Favorite] {
        try await favoriteService.getFavorites(householdId: householdId)
    }

    /// Loads a favorite; the group keeps its shuffle and repeat.
    public func loadFavorite(groupId: String, favoriteId: String, playOnCompletion: Bool? = true, action: String? = "REPLACE") async throws {
        try await loadFavorite(groupId: groupId, favoriteId: favoriteId, playOnCompletion: playOnCompletion, action: action,
                               playModes: nil)
    }

    /// Loads a favorite; `playModes` sets shuffle and repeat for it, nil keeps
    /// the group's current ones.
    public func loadFavorite(groupId: String, favoriteId: String, playOnCompletion: Bool?, action: String?,
                             playModes: PlayModesBody?) async throws {
        try await favoriteService.loadFavorite(groupId: groupId, favoriteId: favoriteId, playOnCompletion: playOnCompletion,
                                               action: action, playModes: playModes)
        stateCache.invalidatePlaybackStatus(for: groupId)
        stateCache.invalidatePlaybackMetadata(for: groupId)
    }

    public func subscribeToFavorites(householdId: String) async throws {
        try await favoriteService.subscribe(householdId: householdId)
    }

    public func unsubscribeFromFavorites(householdId: String) async throws {
        try await favoriteService.unsubscribe(householdId: householdId)
    }
}
