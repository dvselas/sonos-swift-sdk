//
//  SonosManager+PlayerVolume.swift
//  SonosSDK
//

import Foundation

extension SonosManager {

    /// Get player volume with automatic caching
    public func getPlayerVolume(playerId: String, useCache: Bool = true) async throws -> PlayerVolume {
        if useCache, let cached = stateCache.getPlayerVolume(for: playerId) {
            return cached
        }

        let volume = try await playerVolumeService.getVolume(playerId: playerId)
        stateCache.setPlayerVolume(volume, for: playerId)
        return volume
    }

    public func setPlayerVolume(playerId: String, volume: Int) async throws {
        try await playerVolumeService.setVolume(playerId: playerId, volume: volume)
        stateCache.invalidatePlayerVolume(for: playerId)
    }

    public func setPlayerMuted(playerId: String, muted: Bool) async throws {
        try await playerVolumeService.setMuted(playerId: playerId, muted: muted)
        stateCache.invalidatePlayerVolume(for: playerId)
    }

    public func setPlayerRelativeVolume(playerId: String, volumeDelta: Int) async throws {
        try await playerVolumeService.setRelativeVolume(playerId: playerId, volumeDelta: volumeDelta)
        stateCache.invalidatePlayerVolume(for: playerId)
    }

    /// Temporarily reduce player volume (for notifications/alerts)
    public func duckPlayerVolume(playerId: String) async throws {
        try await playerVolumeService.duck(playerId: playerId)
    }

    /// Restore player volume after ducking
    public func unduckPlayerVolume(playerId: String) async throws {
        try await playerVolumeService.unduck(playerId: playerId)
    }

    /// Subscribe to player volume change events
    public func subscribeToPlayerVolume(playerId: String) async throws {
        try await playerVolumeService.subscribe(playerId: playerId)
    }

    /// Unsubscribe from player volume change events
    public func unsubscribeFromPlayerVolume(playerId: String) async throws {
        try await playerVolumeService.unsubscribe(playerId: playerId)
    }
}
