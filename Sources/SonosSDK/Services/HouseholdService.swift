//
//  HouseholdService.swift
//  SonosSDK
//
//  Created by James Hickman on 2/10/21.
//

import Foundation

struct HouseholdService {

    private let client: HTTPClientProtocol

    init(client: HTTPClientProtocol) {
        self.client = client
    }

    /// Get all households for the authenticated user
    func getHouseholds() async throws -> [Household] {
        let response: HouseholdsResponse = try await client.request(.getHouseholds)
        return response.households
    }

    /// Get a single household by ID
    func getHousehold(householdId: String) async throws -> Household {
        try await client.request(.getHousehold(householdId: householdId))
    }
}
