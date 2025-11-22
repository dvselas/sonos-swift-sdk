//
//  SonosManager+Async.swift
//  SonosSDK
//
//  Created on 2025-01-22.
//

import Foundation

// MARK: - Async/Await Extensions for SonosManager

@available(iOS 14.0, macOS 10.15, *)
extension SonosManager {

    // MARK: - Playback Methods

    /// Get playback status with automatic caching
    /// - Parameters:
    ///   - groupId: The group ID
    ///   - useCache: Whether to use cached data if available (default: true)
    /// - Returns: The playback status
    public func getGroupPlaybackStatus(groupId: String, useCache: Bool = true) async throws -> PlaybackStatus {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        // Check cache first if enabled
        if useCache, let cached = stateCache.getPlaybackStatus(for: groupId) {
            return cached
        }

        // Fetch from API
        let status = try await groupPlaybackService.getGroupPlaybackStatus(
            authenticationToken: authenticationToken,
            groupId: groupId
        )

        // Cache the result with TTL from playback actions
        let ttlSeconds = status.availablePlaybackActions.playTtlSec > 0 ? status.availablePlaybackActions.playTtlSec : 5
        let ttl = TimeInterval(ttlSeconds)
        stateCache.setPlaybackStatus(status, for: groupId, ttl: ttl)

        return status
    }

    public func setGroupPlaybackPlay(groupId: String) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await groupPlaybackService.setGroupPlaybackPlay(
            authenticationToken: authenticationToken,
            groupId: groupId
        )

        // Invalidate cache after state change
        stateCache.invalidatePlaybackStatus(for: groupId)
    }

    public func setGroupPlaybackPause(groupId: String) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await groupPlaybackService.setGroupPlaybackPause(
            authenticationToken: authenticationToken,
            groupId: groupId
        )

        stateCache.invalidatePlaybackStatus(for: groupId)
    }

    public func setGroupSkipToNext(groupId: String) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await groupPlaybackService.setGroupSkipToNext(
            authenticationToken: authenticationToken,
            groupId: groupId
        )

        stateCache.invalidatePlaybackStatus(for: groupId)
        stateCache.invalidatePlaybackMetadata(for: groupId)
    }

    public func setGroupSkipToPrevious(groupId: String) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await groupPlaybackService.setGroupSkipToPrevious(
            authenticationToken: authenticationToken,
            groupId: groupId
        )

        stateCache.invalidatePlaybackStatus(for: groupId)
        stateCache.invalidatePlaybackMetadata(for: groupId)
    }

    public func setGroupSkipToSeek(groupId: String, positionMillis: UInt) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await groupPlaybackService.setGroupSkipToSeek(
            authenticationToken: authenticationToken,
            groupId: groupId,
            positionMillis: positionMillis
        )

        stateCache.invalidatePlaybackStatus(for: groupId)
    }

    public func setGroupPlaybackModes(groupId: String, playModes: [String]) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await groupPlaybackService.setGroupPlaybackModes(
            authenticationToken: authenticationToken,
            groupId: groupId,
            playModes: playModes
        )

        stateCache.invalidatePlaybackStatus(for: groupId)
    }

    // MARK: - Volume Methods

    /// Get group volume with automatic caching
    public func getGroupVolume(groupId: String, useCache: Bool = true) async throws -> GroupVolume {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        if useCache, let cached = stateCache.getGroupVolume(for: groupId) {
            return cached
        }

        let volume = try await groupVolumeService.getVolume(
            authenticationToken: authenticationToken,
            groupId: groupId
        )

        stateCache.setGroupVolume(volume, for: groupId)
        return volume
    }

    public func setGroupVolume(groupId: String, volume: Int) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await groupVolumeService.setVolume(
            authenticationToken: authenticationToken,
            groupId: groupId,
            volume: volume
        )

        stateCache.invalidateGroupVolume(for: groupId)
    }

    public func setGroupMuted(groupId: String, muted: Bool) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await groupVolumeService.setMuted(
            authenticationToken: authenticationToken,
            groupId: groupId,
            muted: muted
        )

        stateCache.invalidateGroupVolume(for: groupId)
    }

    /// Get player volume with automatic caching
    public func getPlayerVolume(playerId: String, useCache: Bool = true) async throws -> PlayerVolume {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        if useCache, let cached = stateCache.getPlayerVolume(for: playerId) {
            return cached
        }

        let volume = try await playerVolumeService.getVolume(
            authenticationToken: authenticationToken,
            playerId: playerId
        )

        stateCache.setPlayerVolume(volume, for: playerId)
        return volume
    }

    public func setPlayerVolume(playerId: String, volume: Int) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await playerVolumeService.setVolume(
            authenticationToken: authenticationToken,
            playerId: playerId,
            volume: volume
        )

        stateCache.invalidatePlayerVolume(for: playerId)
    }

    public func setPlayerMuted(playerId: String, muted: Bool) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await playerVolumeService.setMuted(
            authenticationToken: authenticationToken,
            playerId: playerId,
            muted: muted
        )

        stateCache.invalidatePlayerVolume(for: playerId)
    }

    // MARK: - Groups and Players

    /// Get groups with automatic caching
    /// Returns both groups and players from the API
    public func getGroups(householdId: String, useCache: Bool = true) async throws -> ([Group], [Player]) {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        if useCache, let cachedGroups = stateCache.getGroups(), let cachedPlayers = stateCache.getPlayers() {
            return (cachedGroups, cachedPlayers)
        }

        let (groups, players) = try await groupService.getGroups(
            authenticationToken: authenticationToken,
            householdId: householdId
        )

        stateCache.setGroups(groups)
        stateCache.setPlayers(players)
        return (groups, players)
    }

    /// Get players with automatic caching
    public func getPlayers(householdId: String, useCache: Bool = true) async throws -> [Player] {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        if useCache, let cached = stateCache.getPlayers() {
            return cached
        }

        // Get players from groups endpoint
        let (_, players) = try await groupService.getGroups(
            authenticationToken: authenticationToken,
            householdId: householdId
        )

        stateCache.setPlayers(players)
        return players
    }

    // MARK: - Subscription Management

    /// Subscribe to group volume changes with WebSocket support
    public func subscribeToGroupVolume(groupId: String) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await groupVolumeService.subscribe(
            authenticationToken: authenticationToken,
            groupId: groupId
        )
    }

    /// Subscribe to player volume changes with WebSocket support
    public func subscribeToPlayerVolume(playerId: String) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await playerVolumeService.subscribe(
            authenticationToken: authenticationToken,
            playerId: playerId
        )
    }

    /// Subscribe to group changes with WebSocket support
    public func subscribeToGroups(householdId: String) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await groupService.subscribe(
            authenticationToken: authenticationToken,
            householdId: householdId
        )
    }

    // MARK: - WebSocket Management

    /// Start WebSocket connections for all players to enable real-time updates
    public func startWebSocketsForPlayers(_ players: [Player]) {
        for player in players {
            subscriptionCoordinator.startWebSocket(for: player)
        }
    }

    /// Start WebSocket for a specific player
    public func startWebSocket(for player: Player) {
        subscriptionCoordinator.startWebSocket(for: player)
    }

    /// Stop all WebSocket connections
    public func stopAllWebSockets() {
        subscriptionCoordinator.stopAllWebSockets()
    }

    /// Stop WebSocket for a specific player
    public func stopWebSocket(for playerId: String) {
        subscriptionCoordinator.stopWebSocket(for: playerId)
    }

    // MARK: - Advanced Playback

    public func togglePlayPause(groupId: String) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await groupPlaybackService.togglePlayPause(authenticationToken: authenticationToken, groupId: groupId)
        stateCache.invalidatePlaybackStatus(for: groupId)
    }

    public func seekRelative(groupId: String, itemId: String? = nil, deltaMillis: Int) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await groupPlaybackService.seekRelative(authenticationToken: authenticationToken, groupId: groupId, itemId: itemId, deltaMillis: deltaMillis)
        stateCache.invalidatePlaybackStatus(for: groupId)
    }

    public func loadLineIn(groupId: String, deviceId: String? = nil, playOnCompletion: Bool? = nil) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await groupPlaybackService.loadLineIn(authenticationToken: authenticationToken, groupId: groupId, deviceId: deviceId, playOnCompletion: playOnCompletion)
        stateCache.invalidatePlaybackStatus(for: groupId)
        stateCache.invalidatePlaybackMetadata(for: groupId)
    }

    // MARK: - Advanced Group Operations

    public func createGroup(householdId: String, playerIds: [String], musicContextGroupId: String? = nil) async throws -> Group {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        let group = try await groupService.createGroup(authenticationToken: authenticationToken, householdId: householdId, playerIds: playerIds, musicContextGroupId: musicContextGroupId)
        stateCache.invalidateGroups()
        return group
    }

    public func setGroupMembers(householdId: String, playerIds: [String]) async throws -> Group {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        let group = try await groupService.setGroupMembers(authenticationToken: authenticationToken, householdId: householdId, playerIds: playerIds)
        stateCache.invalidateGroups()
        return group
    }

    // MARK: - Music Service Accounts

    public func matchMusicServiceAccount(householdId: String, serviceId: String, userIdHashCode: String, nickname: String, linkCode: String? = nil, linkDeviceId: String? = nil) async throws -> MusicServiceAccount {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        return try await musicServiceAccountsService.matchAccount(authenticationToken: authenticationToken, householdId: householdId, serviceId: serviceId, userIdHashCode: userIdHashCode, nickname: nickname, linkCode: linkCode, linkDeviceId: linkDeviceId)
    }

    // MARK: - Playback Metadata

    /// Get playback metadata with automatic caching
    /// - Parameters:
    ///   - groupId: The group ID
    ///   - useCache: Whether to use cached data if available (default: true)
    /// - Returns: The playback metadata including track info, artwork URLs, and service details
    public func getGroupPlaybackMetadata(groupId: String, useCache: Bool = true) async throws -> PlaybackMetadata {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        // Check cache first if enabled
        if useCache, let cached = stateCache.getPlaybackMetadata(for: groupId) {
            return cached
        }

        // Fetch from API
        let metadata = try await groupMetadataService.getGroupPlaybackMetadata(
            authenticationToken: authenticationToken,
            groupId: groupId
        )

        // Cache the result with default TTL
        stateCache.setPlaybackMetadata(metadata, for: groupId)

        return metadata
    }
}
