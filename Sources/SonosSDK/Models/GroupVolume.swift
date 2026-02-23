//
//  GroupVolume.swift
//  SonosSDK
//
//  Created by James Hickman on 3/21/21.
//

import Foundation

public struct GroupVolume: Codable, Sendable {

    public let volume: Int
    public let muted: Bool
    public let fixed: Bool

    public init(volume: Int = 0, muted: Bool = false, fixed: Bool = false) {
        self.volume = volume
        self.muted = muted
        self.fixed = fixed
    }
}
