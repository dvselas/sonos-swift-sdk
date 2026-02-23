//
//  SonosManager+Playlists.swift
//  SonosSDK
//

import Foundation

extension SonosManager {

    public func getPlaylists(householdId: String) async throws -> [Playlist] {
        try await playlistService.getPlaylists(householdId: householdId)
    }

    public func getPlaylist(householdId: String, playlistId: String) async throws -> Playlist {
        try await playlistService.getPlaylist(householdId: householdId, playlistId: playlistId)
    }

    public func loadPlaylist(groupId: String, playlistId: String, playOnCompletion: Bool? = true, playModes: PlayModesBody? = nil) async throws {
        try await playlistService.loadPlaylist(groupId: groupId, playlistId: playlistId, playOnCompletion: playOnCompletion, playModes: playModes)
        stateCache.invalidatePlaybackStatus(for: groupId)
        stateCache.invalidatePlaybackMetadata(for: groupId)
    }

    public func subscribeToPlaylists(householdId: String) async throws {
        try await playlistService.subscribe(householdId: householdId)
    }

    public func unsubscribeFromPlaylists(householdId: String) async throws {
        try await playlistService.unsubscribe(householdId: householdId)
    }
}
