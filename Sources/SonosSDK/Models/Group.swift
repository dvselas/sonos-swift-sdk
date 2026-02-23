//
//  Group.swift
//  SonosSDK
//
//  Created by James Hickman on 2/17/21.
//

import Foundation

public struct Group: Codable, Identifiable, Hashable, Sendable {

    public let id: String
    public let name: String
    public let coordinatorId: String
    public let playbackState: String?
    public let playerIds: [String]

    /// Convenience accessors for backward compatibility
    public var coordinatorID: String { coordinatorId }
    public var playerIDs: [String] { playerIds }
}

/// Response wrapper for createGroup/modifyGroupMembers
struct GroupResponse: Codable {
    let group: Group
}
