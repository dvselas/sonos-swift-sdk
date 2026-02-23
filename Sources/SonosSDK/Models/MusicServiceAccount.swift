//
//  MusicServiceAccount.swift
//  SonosSDK
//
//  Created on 2025-01-22.
//

import Foundation

public struct MusicServiceAccount: Codable, Sendable {

    public let accountId: String
    public let serviceId: String
    public let nickname: String?
    public let isGuest: Bool?
}
