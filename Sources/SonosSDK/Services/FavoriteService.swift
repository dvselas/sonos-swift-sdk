//
//  FavoriteService.swift
//  SonosSDK
//

import Foundation

struct FavoriteService {

    private let client: HTTPClientProtocol

    init(client: HTTPClientProtocol) {
        self.client = client
    }

    func getFavorites(householdId: String) async throws -> [Favorite] {
        let response: FavoritesResponse = try await client.request(.getFavorites(householdId: householdId))
        return response.items
    }

    func loadFavorite(groupId: String, favoriteId: String, playOnCompletion: Bool? = true, action: String? = "REPLACE",
                      playModes: PlayModesBody? = nil) async throws {
        try await client.request(.loadFavorite(groupId: groupId, favoriteId: favoriteId, playOnCompletion: playOnCompletion,
                                               action: action, playModes: playModes))
    }

    func subscribe(householdId: String) async throws {
        try await client.request(.subscribeToFavorites(householdId: householdId))
    }

    func unsubscribe(householdId: String) async throws {
        try await client.request(.unsubscribeFromFavorites(householdId: householdId))
    }
}
