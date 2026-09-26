//
//  GroupVolume.swift
//  SonosSDK
//
//  Created by James Hickman on 3/21/21.
//

import Foundation

public struct GroupVolume: Codable, Sendable, Equatable {

    public let volume: Int
    public let muted: Bool
    /// True when every player in the group has a fixed volume.
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
