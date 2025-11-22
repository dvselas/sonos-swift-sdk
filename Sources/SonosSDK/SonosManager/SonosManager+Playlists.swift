//
//  SonosManager+Playlists.swift
//  SonosSDK
//
//  Created on 2025-01-22.
//

import Foundation

extension SonosManager {

    // MARK: - Playlists (Callback-based)

    public func getPlaylists(householdId: String, success: @escaping ([Playlist]) -> Void, failure: @escaping (Error?) -> Void) {
        guard let authenticationToken = authenticationToken else {
            let error = NSError.errorWithMessage(message: "Could not load authentication token.")
            failure(error)
            return
        }

        playlistService.getPlaylists(authenticationToken: authenticationToken, householdId: householdId, success: success, failure: failure)
    }

    public func getPlaylist(householdId: String, playlistId: String, success: @escaping (Playlist) -> Void, failure: @escaping (Error?) -> Void) {
        guard let authenticationToken = authenticationToken else {
            let error = NSError.errorWithMessage(message: "Could not load authentication token.")
            failure(error)
            return
        }

        playlistService.getPlaylist(authenticationToken: authenticationToken, householdId: householdId, playlistId: playlistId, success: success, failure: failure)
    }

    public func loadPlaylist(groupId: String, playlistId: String, playOnCompletion: Bool = true, success: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        guard let authenticationToken = authenticationToken else {
            let error = NSError.errorWithMessage(message: "Could not load authentication token.")
            failure(error)
            return
        }

        playlistService.loadPlaylist(authenticationToken: authenticationToken, groupId: groupId, playlistId: playlistId, playOnCompletion: playOnCompletion, success: success, failure: failure)
    }

    public func subscribeToPlaylists(householdId: String, success: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        guard let authenticationToken = authenticationToken else {
            let error = NSError.errorWithMessage(message: "Could not load authentication token.")
            failure(error)
            return
        }

        playlistService.subscribe(authenticationToken: authenticationToken, householdId: householdId, success: success, failure: failure)
    }

    public func unsubscribeFromPlaylists(householdId: String, success: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        guard let authenticationToken = authenticationToken else {
            let error = NSError.errorWithMessage(message: "Could not load authentication token.")
            failure(error)
            return
        }

        playlistService.unsubscribe(authenticationToken: authenticationToken, householdId: householdId, success: success, failure: failure)
    }
}

// MARK: - Async/Await Extensions

@available(iOS 14.0, macOS 10.15, *)
extension SonosManager {

    public func getPlaylists(householdId: String) async throws -> [Playlist] {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        return try await playlistService.getPlaylists(authenticationToken: authenticationToken, householdId: householdId)
    }

    public func getPlaylist(householdId: String, playlistId: String) async throws -> Playlist {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        return try await playlistService.getPlaylist(authenticationToken: authenticationToken, householdId: householdId, playlistId: playlistId)
    }

    public func loadPlaylist(groupId: String, playlistId: String, playOnCompletion: Bool = true) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await playlistService.loadPlaylist(authenticationToken: authenticationToken, groupId: groupId, playlistId: playlistId, playOnCompletion: playOnCompletion)

        // Invalidate cache after loading new content
        stateCache.invalidatePlaybackStatus(for: groupId)
        stateCache.invalidatePlaybackMetadata(for: groupId)
    }

    public func subscribeToPlaylists(householdId: String) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await playlistService.subscribe(authenticationToken: authenticationToken, householdId: householdId)
    }

    public func unsubscribeFromPlaylists(householdId: String) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await playlistService.unsubscribe(authenticationToken: authenticationToken, householdId: householdId)
    }
}
