//
//  SonosManager+GroupPlayback.swift
//  SonosSDK
//

import Foundation

extension SonosManager {

    /// Get playback status with automatic caching
    public func getGroupPlaybackStatus(groupId: String, useCache: Bool = true) async throws -> PlaybackStatus {
        if useCache, let cached = stateCache.getPlaybackStatus(for: groupId) {
            return cached
        }

        let status = try await groupPlaybackService.getPlaybackStatus(groupId: groupId)
        let ttl = TimeInterval(status.availablePlaybackActions.playTtlSec > 0 ? status.availablePlaybackActions.playTtlSec : 5)
        stateCache.setPlaybackStatus(status, for: groupId, ttl: ttl)
        return status
    }

    public func play(groupId: String) async throws {
        try await groupPlaybackService.play(groupId: groupId)
        stateCache.invalidatePlaybackStatus(for: groupId)
    }

    public func pause(groupId: String) async throws {
        try await groupPlaybackService.pause(groupId: groupId)
        stateCache.invalidatePlaybackStatus(for: groupId)
    }

    public func togglePlayPause(groupId: String) async throws {
        try await groupPlaybackService.togglePlayPause(groupId: groupId)
        stateCache.invalidatePlaybackStatus(for: groupId)
    }

    public func skipToNextTrack(groupId: String) async throws {
        try await groupPlaybackService.skipToNextTrack(groupId: groupId)
        stateCache.invalidatePlaybackStatus(for: groupId)
        stateCache.invalidatePlaybackMetadata(for: groupId)
    }

    public func skipToPreviousTrack(groupId: String) async throws {
        try await groupPlaybackService.skipToPreviousTrack(groupId: groupId)
        stateCache.invalidatePlaybackStatus(for: groupId)
        stateCache.invalidatePlaybackMetadata(for: groupId)
    }

    public func seek(groupId: String, positionMillis: UInt) async throws {
        try await groupPlaybackService.seek(groupId: groupId, positionMillis: positionMillis)
        stateCache.invalidatePlaybackStatus(for: groupId)
    }

    public func seekRelative(groupId: String, deltaMillis: Int, itemId: String? = nil) async throws {
        try await groupPlaybackService.seekRelative(groupId: groupId, deltaMillis: deltaMillis, itemId: itemId)
        stateCache.invalidatePlaybackStatus(for: groupId)
    }

    public func setPlayModes(groupId: String, playModes: PlayModesBody) async throws {
        try await groupPlaybackService.setPlayModes(groupId: groupId, playModes: playModes)
        stateCache.invalidatePlaybackStatus(for: groupId)
    }

    public func loadLineIn(groupId: String, deviceId: String? = nil, playOnCompletion: Bool? = nil) async throws {
        try await groupPlaybackService.loadLineIn(groupId: groupId, deviceId: deviceId, playOnCompletion: playOnCompletion)
        stateCache.invalidatePlaybackStatus(for: groupId)
        stateCache.invalidatePlaybackMetadata(for: groupId)
    }

    /// Subscribe to playback events
    public func subscribeToPlayback(groupId: String) async throws {
        try await groupPlaybackService.subscribe(groupId: groupId)
    }

    /// Unsubscribe from playback events
    public func unsubscribeFromPlayback(groupId: String) async throws {
        try await groupPlaybackService.unsubscribe(groupId: groupId)
    }
}
