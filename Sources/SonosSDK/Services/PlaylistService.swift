//
//  PlaylistService.swift
//  SonosSDK
//

import Foundation

struct PlaylistService {

    private let client: HTTPClientProtocol

    init(client: HTTPClientProtocol) {
        self.client = client
    }

    func getPlaylists(householdId: String) async throws -> [Playlist] {
        let response: PlaylistsResponse = try await client.request(.getPlaylists(householdId: householdId))
        return response.playlists
    }

    func getPlaylist(householdId: String, playlistId: String) async throws -> Playlist {
        try await client.request(.getPlaylist(householdId: householdId, playlistId: playlistId))
    }

    func loadPlaylist(groupId: String, playlistId: String, playOnCompletion: Bool? = true, playModes: PlayModesBody? = nil) async throws {
        try await client.request(.loadPlaylist(groupId: groupId, playlistId: playlistId, playOnCompletion: playOnCompletion, playModes: playModes))
    }

    func subscribe(householdId: String) async throws {
        try await client.request(.subscribeToPlaylists(householdId: householdId))
    }

    func unsubscribe(householdId: String) async throws {
        try await client.request(.unsubscribeFromPlaylists(householdId: householdId))
    }
}
