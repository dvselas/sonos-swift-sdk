//
//  PlaybackSession.swift
//  SonosSDK
//
//  Created on 2025-01-22.
//

import Foundation

public struct PlaybackSession: Codable, Sendable {

    public let sessionId: String
    public let appId: String?
    public let appContext: String?
    public let sessionState: String?
    public let sessionCreated: Bool?
    public let customData: String?
}
