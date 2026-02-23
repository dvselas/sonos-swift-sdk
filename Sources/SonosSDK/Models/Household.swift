//
//  Household.swift
//  SonosSDK
//
//  Created by James Hickman on 2/7/21.
//

import Foundation

public struct Household: Codable, Identifiable, Sendable {

    public let id: String
    public let name: String?
}

/// Response wrapper for getHouseholds
struct HouseholdsResponse: Codable {
    let households: [Household]
}
