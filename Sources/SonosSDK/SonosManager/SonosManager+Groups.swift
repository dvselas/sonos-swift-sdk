//
//  SonosManager+Groups.swift
//  SonosSDK
//

import Foundation

extension SonosManager {

    /// Get all groups and players for a household (with optional caching)
    public func getGroups(householdId: String, useCache: Bool = true) async throws -> ([Group], [Player]) {
        if useCache, let cachedGroups = stateCache.getGroups(), let cachedPlayers = stateCache.getPlayers() {
            return (cachedGroups, cachedPlayers)
        }

        let (groups, players) = try await groupService.getGroups(householdId: householdId)
        stateCache.setGroups(groups)
        stateCache.setPlayers(players)
        return (groups, players)
    }

    /// Get players for a household (with optional caching)
    public func getPlayers(householdId: String, useCache: Bool = true) async throws -> [Player] {
        if useCache, let cached = stateCache.getPlayers() {
            return cached
        }

        let (_, players) = try await groupService.getGroups(householdId: householdId)
        stateCache.setPlayers(players)
        return players
    }

    /// Create a new group from specified players
    public func createGroup(householdId: String, playerIds: [String], musicContextGroupId: String? = nil) async throws -> Group {
        let group = try await groupService.createGroup(householdId: householdId, playerIds: playerIds, musicContextGroupId: musicContextGroupId)
        stateCache.invalidateGroups()
        return group
    }

    /// Modify group membership by adding/removing players
    public func modifyGroupMembers(groupId: String, playerIdsToAdd: [String], playerIdsToRemove: [String]) async throws -> Group {
        let group = try await groupService.modifyGroupMembers(groupId: groupId, playerIdsToAdd: playerIdsToAdd, playerIdsToRemove: playerIdsToRemove)
        stateCache.invalidateGroups()
        return group
    }

    /// Set group members (replaces current membership)
    public func setGroupMembers(householdId: String, playerIds: [String]) async throws -> Group {
        let group = try await groupService.setGroupMembers(householdId: householdId, playerIds: playerIds)
        stateCache.invalidateGroups()
        return group
    }

    /// Subscribe to group change events
    public func subscribeToGroups(householdId: String) async throws {
        try await groupService.subscribe(householdId: householdId)
    }

    /// Unsubscribe from group change events
    public func unsubscribeFromGroups(householdId: String) async throws {
        try await groupService.unsubscribe(householdId: householdId)
    }

    /// Get group members from a player list
    public func getGroupMembers(group: Group, players: [Player]) -> [Player] {
        players.filter { group.playerIds.contains($0.id) }
    }
}
