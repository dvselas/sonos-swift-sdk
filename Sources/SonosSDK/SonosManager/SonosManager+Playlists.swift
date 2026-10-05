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

    /// Adds the playlist to the end of the queue (the API's default).
    public func loadPlaylist(groupId: String, playlistId: String, playOnCompletion: Bool? = true, playModes: PlayModesBody? = nil) async throws {
        try await loadPlaylist(groupId: groupId, playlistId: playlistId, playOnCompletion: playOnCompletion, playModes: playModes, action: nil)
    }

    /// - Parameter action: APPEND, INSERT, INSERT_NEXT or REPLACE; nil for the API's default (APPEND).
    public func loadPlaylist(groupId: String, playlistId: String, playOnCompletion: Bool?, playModes: PlayModesBody?, action: String?) async throws {
        try await playlistService.loadPlaylist(groupId: groupId, playlistId: playlistId, playOnCompletion: playOnCompletion,
                                               playModes: playModes, action: action)
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
