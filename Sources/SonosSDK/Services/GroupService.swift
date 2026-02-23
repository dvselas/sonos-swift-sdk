//
//  GroupService.swift
//  SonosSDK
//
//  Created by James Hickman on 2/17/21.
//

import Foundation

struct GroupService {

    private let client: HTTPClientProtocol

    init(client: HTTPClientProtocol) {
        self.client = client
    }

    /// Get all groups and players for a household
    func getGroups(householdId: String) async throws -> ([Group], [Player]) {
        let response: GroupsResponse = try await client.request(.getGroups(householdId: householdId))
        return (response.groups, response.players)
    }

    /// Create a new group from the specified players
    func createGroup(householdId: String, playerIds: [String], musicContextGroupId: String? = nil) async throws -> Group {
        let response: GroupResponse = try await client.request(
            .createGroup(householdId: householdId, playerIds: playerIds, musicContextGroupId: musicContextGroupId)
        )
        return response.group
    }

    /// Modify group membership by adding/removing players
    func modifyGroupMembers(groupId: String, playerIdsToAdd: [String], playerIdsToRemove: [String]) async throws -> Group {
        let response: GroupResponse = try await client.request(
            .modifyGroupMembers(groupId: groupId, playerIdsToAdd: playerIdsToAdd, playerIdsToRemove: playerIdsToRemove)
        )
        return response.group
    }

    /// Set group members (replaces current membership)
    func setGroupMembers(householdId: String, playerIds: [String]) async throws -> Group {
        let response: GroupResponse = try await client.request(
            .setGroupMembers(householdId: householdId, playerIds: playerIds)
        )
        return response.group
    }

    /// Subscribe to group change events
    func subscribe(householdId: String) async throws {
        try await client.request(.subscribeToGroups(householdId: householdId))
    }

    /// Unsubscribe from group change events
    func unsubscribe(householdId: String) async throws {
        try await client.request(.unsubscribeFromGroups(householdId: householdId))
    }
}
