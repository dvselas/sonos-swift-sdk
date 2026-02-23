//
//  AudioClip.swift
//  SonosSDK
//
//  Created by James Hickman on 2/23/21.
//

import Foundation

public struct AudioClip: Codable, Sendable {

    public let id: String
    public let appId: String?
    public let clipType: ClipType?
    public let httpAuthorization: String?
    public let name: String?
    public let priority: Priority?
    public let streamUrl: String?
    public let volume: Int?

    public enum ClipType: String, Codable, CaseIterable, Identifiable, Sendable {
        public var id: ClipType { self }

        case chime = "CHIME"
        case custom = "CUSTOM"
    }

    public enum Priority: String, Codable, CaseIterable, Identifiable, Sendable {
        public var id: Priority { self }

        case low = "LOW"
        case high = "HIGH"
    }
}
