//
//  PlayerService.swift
//  SonosSDK
//

import Foundation

struct PlayerService {

    private let client: HTTPClientProtocol

    init(client: HTTPClientProtocol) {
        self.client = client
    }

    /// Get all players for a household (via groups endpoint)
    func getPlayers(householdId: String) async throws -> [Player] {
        let response: GroupsResponse = try await client.request(.getGroups(householdId: householdId))
        return response.players
    }
}
