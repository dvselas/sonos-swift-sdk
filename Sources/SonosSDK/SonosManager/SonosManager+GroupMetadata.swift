//
//  SonosManager+GroupMetadata.swift
//  SonosSDK
//

import Foundation

extension SonosManager {

    /// Get playback metadata with automatic caching
    public func getGroupPlaybackMetadata(groupId: String, useCache: Bool = true) async throws -> PlaybackMetadata {
        if useCache, let cached = stateCache.getPlaybackMetadata(for: groupId) {
            return cached
        }

        let metadata = try await groupMetadataService.getMetadataStatus(groupId: groupId)
        stateCache.setPlaybackMetadata(metadata, for: groupId)
        return metadata
    }

    /// Subscribe to metadata change events
    public func subscribeToPlaybackMetadata(groupId: String) async throws {
        try await groupMetadataService.subscribe(groupId: groupId)
    }

    /// Unsubscribe from metadata change events
    public func unsubscribeFromPlaybackMetadata(groupId: String) async throws {
        try await groupMetadataService.unsubscribe(groupId: groupId)
    }
}
