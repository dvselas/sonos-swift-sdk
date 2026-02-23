//
//  StateCacheManager.swift
//  SonosSDK
//
//  Thread-safe cache manager with TTL-based invalidation
//

import Foundation

/// Thread-safe cache manager for Sonos API state with TTL-based invalidation
public final class StateCacheManager: @unchecked Sendable {

    // MARK: - Cache Entry

    private struct CacheEntry<T> {
        let value: T
        let timestamp: Date
        let ttl: TimeInterval

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }
    }

    // MARK: - Properties

    private let queue = DispatchQueue(label: "com.sonos.sdk.cache", attributes: .concurrent)
    private var playbackStatusCache: [String: CacheEntry<PlaybackStatus>] = [:]
    private var playbackMetadataCache: [String: CacheEntry<PlaybackMetadata>] = [:]
    private var groupVolumeCache: [String: CacheEntry<GroupVolume>] = [:]
    private var playerVolumeCache: [String: CacheEntry<PlayerVolume>] = [:]
    private var groupsCache: CacheEntry<[Group]>?
    private var playersCache: CacheEntry<[Player]>?

    // Default TTLs (in seconds)
    private let defaultPlaybackTTL: TimeInterval = 5.0
    private let defaultVolumeTTL: TimeInterval = 10.0
    private let defaultMetadataTTL: TimeInterval = 30.0
    private let defaultListTTL: TimeInterval = 60.0

    public static let shared = StateCacheManager()

    private init() {}

    // MARK: - Playback Status Cache

    public func getPlaybackStatus(for groupId: String) -> PlaybackStatus? {
        queue.sync {
            guard let entry = playbackStatusCache[groupId], !entry.isExpired else { return nil }
            return entry.value
        }
    }

    public func setPlaybackStatus(_ status: PlaybackStatus, for groupId: String, ttl: TimeInterval? = nil) {
        queue.async(flags: .barrier) {
            self.playbackStatusCache[groupId] = CacheEntry(value: status, timestamp: Date(), ttl: ttl ?? self.defaultPlaybackTTL)
        }
    }

    public func invalidatePlaybackStatus(for groupId: String) {
        queue.async(flags: .barrier) { self.playbackStatusCache.removeValue(forKey: groupId) }
    }

    // MARK: - Playback Metadata Cache

    public func getPlaybackMetadata(for groupId: String) -> PlaybackMetadata? {
        queue.sync {
            guard let entry = playbackMetadataCache[groupId], !entry.isExpired else { return nil }
            return entry.value
        }
    }

    public func setPlaybackMetadata(_ metadata: PlaybackMetadata, for groupId: String, ttl: TimeInterval? = nil) {
        queue.async(flags: .barrier) {
            self.playbackMetadataCache[groupId] = CacheEntry(value: metadata, timestamp: Date(), ttl: ttl ?? self.defaultMetadataTTL)
        }
    }

    public func invalidatePlaybackMetadata(for groupId: String) {
        queue.async(flags: .barrier) { self.playbackMetadataCache.removeValue(forKey: groupId) }
    }

    // MARK: - Group Volume Cache

    public func getGroupVolume(for groupId: String) -> GroupVolume? {
        queue.sync {
            guard let entry = groupVolumeCache[groupId], !entry.isExpired else { return nil }
            return entry.value
        }
    }

    public func setGroupVolume(_ volume: GroupVolume, for groupId: String, ttl: TimeInterval? = nil) {
        queue.async(flags: .barrier) {
            self.groupVolumeCache[groupId] = CacheEntry(value: volume, timestamp: Date(), ttl: ttl ?? self.defaultVolumeTTL)
        }
    }

    public func invalidateGroupVolume(for groupId: String) {
        queue.async(flags: .barrier) { self.groupVolumeCache.removeValue(forKey: groupId) }
    }

    // MARK: - Player Volume Cache

    public func getPlayerVolume(for playerId: String) -> PlayerVolume? {
        queue.sync {
            guard let entry = playerVolumeCache[playerId], !entry.isExpired else { return nil }
            return entry.value
        }
    }

    public func setPlayerVolume(_ volume: PlayerVolume, for playerId: String, ttl: TimeInterval? = nil) {
        queue.async(flags: .barrier) {
            self.playerVolumeCache[playerId] = CacheEntry(value: volume, timestamp: Date(), ttl: ttl ?? self.defaultVolumeTTL)
        }
    }

    public func invalidatePlayerVolume(for playerId: String) {
        queue.async(flags: .barrier) { self.playerVolumeCache.removeValue(forKey: playerId) }
    }

    // MARK: - Groups Cache

    public func getGroups() -> [Group]? {
        queue.sync {
            guard let entry = groupsCache, !entry.isExpired else { return nil }
            return entry.value
        }
    }

    public func setGroups(_ groups: [Group], ttl: TimeInterval? = nil) {
        queue.async(flags: .barrier) {
            self.groupsCache = CacheEntry(value: groups, timestamp: Date(), ttl: ttl ?? self.defaultListTTL)
        }
    }

    public func invalidateGroups() {
        queue.async(flags: .barrier) { self.groupsCache = nil }
    }

    // MARK: - Players Cache

    public func getPlayers() -> [Player]? {
        queue.sync {
            guard let entry = playersCache, !entry.isExpired else { return nil }
            return entry.value
        }
    }

    public func setPlayers(_ players: [Player], ttl: TimeInterval? = nil) {
        queue.async(flags: .barrier) {
            self.playersCache = CacheEntry(value: players, timestamp: Date(), ttl: ttl ?? self.defaultListTTL)
        }
    }

    public func invalidatePlayers() {
        queue.async(flags: .barrier) { self.playersCache = nil }
    }

    // MARK: - Bulk Operations

    public func invalidateAll() {
        queue.async(flags: .barrier) {
            self.playbackStatusCache.removeAll()
            self.playbackMetadataCache.removeAll()
            self.groupVolumeCache.removeAll()
            self.playerVolumeCache.removeAll()
            self.groupsCache = nil
            self.playersCache = nil
        }
    }

    public func invalidateAllForGroup(_ groupId: String) {
        queue.async(flags: .barrier) {
            self.playbackStatusCache.removeValue(forKey: groupId)
            self.playbackMetadataCache.removeValue(forKey: groupId)
            self.groupVolumeCache.removeValue(forKey: groupId)
        }
    }

    public func invalidateAllForPlayer(_ playerId: String) {
        queue.async(flags: .barrier) {
            self.playerVolumeCache.removeValue(forKey: playerId)
        }
    }

    // MARK: - Cache Statistics

    public func getCacheStatistics() -> CacheStatistics {
        queue.sync {
            CacheStatistics(
                playbackStatusCount: playbackStatusCache.count,
                playbackMetadataCount: playbackMetadataCache.count,
                groupVolumeCount: groupVolumeCache.count,
                playerVolumeCount: playerVolumeCache.count,
                hasGroupsCache: groupsCache != nil,
                hasPlayersCache: playersCache != nil
            )
        }
    }
}

// MARK: - Cache Statistics

public struct CacheStatistics: Sendable {
    public let playbackStatusCount: Int
    public let playbackMetadataCount: Int
    public let groupVolumeCount: Int
    public let playerVolumeCount: Int
    public let hasGroupsCache: Bool
    public let hasPlayersCache: Bool

    public var totalEntries: Int {
        playbackStatusCount + playbackMetadataCount + groupVolumeCount + playerVolumeCount +
        (hasGroupsCache ? 1 : 0) + (hasPlayersCache ? 1 : 0)
    }
}
