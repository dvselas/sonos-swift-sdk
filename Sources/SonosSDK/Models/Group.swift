//
//  Group.swift
//  SonosSDK
//
//  Created by James Hickman on 2/17/21.
//

import Foundation

public struct Group: Codable, Identifiable, Hashable, Sendable {

    /// `<coordinator player id>:<sequence>`; changes whenever the group changes.
    public let id: String
    public let name: String
    public let coordinatorId: String
    public let playbackState: String?
    public let playerIds: [String]

    /// Convenience accessors for backward compatibility
    public var coordinatorID: String { coordinatorId }
    public var playerIDs: [String] { playerIds }

    public init(id: String, name: String, coordinatorId: String, playbackState: String? = nil, playerIds: [String]) {
        self.id = id
        self.name = name
        self.coordinatorId = coordinatorId
        self.playbackState = playbackState
        self.playerIds = playerIds
    }

    enum CodingKeys: String, CodingKey {
        case id, name, coordinatorId, playbackState, playerIds
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        coordinatorId = try c.decode(String.self, forKey: .coordinatorId)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        playbackState = try? c.decodeIfPresent(String.self, forKey: .playbackState)
        playerIds = (try? c.decodeIfPresent([String].self, forKey: .playerIds)) ?? [coordinatorId]
    }
}

/// Response wrapper for createGroup/modifyGroupMembers
struct GroupResponse: Codable {
    let group: Group
}
