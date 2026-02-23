//
//  SonosManager+GroupVolume.swift
//  SonosSDK
//

import Foundation

extension SonosManager {

    /// Get group volume with automatic caching
    public func getGroupVolume(groupId: String, useCache: Bool = true) async throws -> GroupVolume {
        if useCache, let cached = stateCache.getGroupVolume(for: groupId) {
            return cached
        }

        let volume = try await groupVolumeService.getVolume(groupId: groupId)
        stateCache.setGroupVolume(volume, for: groupId)
        return volume
    }

    public func setGroupVolume(groupId: String, volume: Int) async throws {
        try await groupVolumeService.setVolume(groupId: groupId, volume: volume)
        stateCache.invalidateGroupVolume(for: groupId)
    }

    public func setGroupMuted(groupId: String, muted: Bool) async throws {
        try await groupVolumeService.setMuted(groupId: groupId, muted: muted)
        stateCache.invalidateGroupVolume(for: groupId)
    }

    public func setGroupRelativeVolume(groupId: String, volumeDelta: Int) async throws {
        try await groupVolumeService.setRelativeVolume(groupId: groupId, volumeDelta: volumeDelta)
        stateCache.invalidateGroupVolume(for: groupId)
    }

    /// Subscribe to group volume change events
    public func subscribeToGroupVolume(groupId: String) async throws {
        try await groupVolumeService.subscribe(groupId: groupId)
    }

    /// Unsubscribe from group volume change events
    public func unsubscribeFromGroupVolume(groupId: String) async throws {
        try await groupVolumeService.unsubscribe(groupId: groupId)
    }
}
