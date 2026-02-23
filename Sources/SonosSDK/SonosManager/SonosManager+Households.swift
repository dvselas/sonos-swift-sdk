//
//  SonosManager+Households.swift
//  SonosSDK
//

import Foundation

extension SonosManager {

    /// Get all households for the authenticated user
    public func getHouseholds() async throws -> [Household] {
        try await householdService.getHouseholds()
    }

    /// Get a single household by ID
    public func getHousehold(householdId: String) async throws -> Household {
        try await householdService.getHousehold(householdId: householdId)
    }
}
