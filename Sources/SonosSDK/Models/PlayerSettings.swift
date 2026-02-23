//
//  PlayerSettings.swift
//  SonosSDK
//
//  Created by James Hickman on 2/22/21.
//

import Foundation

public struct PlayerSettings: Codable, Sendable {

    public let volumeMode: VolumeMode
    public let volumeScalingFactor: Float
    public let monoMode: Bool
    public let wifiDisable: Bool

    public enum VolumeMode: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
        public var id: VolumeMode { self }

        case variable = "VARIABLE"
        case fixed = "FIXED"
        case passthrough = "PASS_THROUGH"
    }

    public init(
        volumeMode: VolumeMode = .variable,
        volumeScalingFactor: Float = 1.0,
        monoMode: Bool = false,
        wifiDisable: Bool = false
    ) {
        self.volumeMode = volumeMode
        self.volumeScalingFactor = volumeScalingFactor
        self.monoMode = monoMode
        self.wifiDisable = wifiDisable
    }
}
