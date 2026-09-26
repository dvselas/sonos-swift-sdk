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
    /// Local Control API endpoint, e.g. `wss://192.168.1.20:1443/websocket/api`.
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

    public init(
        id: String,
        name: String,
        websocketUrl: String = "",
        softwareVersion: String = "",
        apiVersion: String = "",
        minApiVersion: String = "",
        isUnregistered: Bool = false,
        capabilities: [String] = [],
        deviceIds: [String] = []
    ) {
        self.id = id
        self.name = name
        self.websocketUrl = websocketUrl
        self.softwareVersion = softwareVersion
        self.apiVersion = apiVersion
        self.minApiVersion = minApiVersion
        self.isUnregistered = isUnregistered
        self.capabilities = capabilities
        self.deviceIds = deviceIds
    }

    enum CodingKeys: String, CodingKey {
        case id, name, websocketUrl, softwareVersion, apiVersion, minApiVersion, isUnregistered, capabilities, deviceIds
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func string(_ key: CodingKeys) -> String { (try? c.decodeIfPresent(String.self, forKey: key)) ?? "" }
        id = try c.decode(String.self, forKey: .id)
        name = string(.name)
        websocketUrl = string(.websocketUrl)
        softwareVersion = string(.softwareVersion)
        apiVersion = string(.apiVersion)
        minApiVersion = string(.minApiVersion)
        isUnregistered = (try? c.decodeIfPresent(Bool.self, forKey: .isUnregistered)) ?? false
        capabilities = (try? c.decodeIfPresent([String].self, forKey: .capabilities)) ?? []
        deviceIds = (try? c.decodeIfPresent([String].self, forKey: .deviceIds)) ?? []
    }
}

/// Response wrapper for getGroups (which returns both groups and players)
struct GroupsResponse: Codable {
    let groups: [Group]
    let players: [Player]

    enum CodingKeys: String, CodingKey {
        case groups, players
    }

    init(groups: [Group], players: [Player]) {
        self.groups = groups
        self.players = players
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        groups = try c.decode([Group].self, forKey: .groups)
        players = (try? c.decodeIfPresent([Player].self, forKey: .players)) ?? []
    }
}
