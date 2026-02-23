//
//  Player.swift
//  SonosSDK
//
//  Created by James Hickman on 2/17/21.
//

import Foundation

public struct Player: Codable, Identifiable, Hashable, Sendable {

    public let id: String
    public let name: String
    public let websocketUrl: String
    public let softwareVersion: String
    public let apiVersion: String
    public let minApiVersion: String
    public let isUnregistered: Bool
    public let capabilities: [String]
    public let deviceIds: [String]

    /// Convenience accessor for backward compatibility
    public var websocketURL: String { websocketUrl }
    public var deviceIDs: [String] { deviceIds }
}

/// Response wrapper for getGroups (which returns both groups and players)
struct GroupsResponse: Codable {
    let groups: [Group]
    let players: [Player]
}
