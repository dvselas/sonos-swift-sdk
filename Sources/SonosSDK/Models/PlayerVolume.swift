//
//  PlayerVolume.swift
//  SonosSDK
//
//  Created by James Hickman on 2/20/21.
//

import Foundation

public struct PlayerVolume: Codable, Sendable, Equatable {

    public let volume: Int
    public let muted: Bool
    /// True for players with a fixed line-out level.
    public let fixed: Bool

    public init(volume: Int = 0, muted: Bool = false, fixed: Bool = false) {
        self.volume = volume
        self.muted = muted
        self.fixed = fixed
    }

    enum CodingKeys: String, CodingKey {
        case volume, muted, fixed
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        volume = try c.decode(Int.self, forKey: .volume)
        muted = (try? c.decodeIfPresent(Bool.self, forKey: .muted)) ?? false
        fixed = (try? c.decodeIfPresent(Bool.self, forKey: .fixed)) ?? false
    }
}
