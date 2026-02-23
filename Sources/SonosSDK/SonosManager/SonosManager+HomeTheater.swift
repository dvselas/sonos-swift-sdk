//
//  SonosManager+HomeTheater.swift
//  SonosSDK
//

import Foundation

extension SonosManager {

    public func getHomeTheaterOptions(playerId: String) async throws -> HomeTheaterOptions {
        try await homeTheaterService.getOptions(playerId: playerId)
    }

    public func setHomeTheaterOptions(playerId: String, nightMode: Bool? = nil, enhanceDialog: Bool? = nil) async throws {
        try await homeTheaterService.setOptions(playerId: playerId, nightMode: nightMode, enhanceDialog: enhanceDialog)
    }

    /// Load home theater playback (switch to TV input)
    public func loadHomeTheaterPlayback(playerId: String) async throws {
        try await homeTheaterService.loadHomeTheaterPlayback(playerId: playerId)
    }

    /// Set TV power state ("on" or "standby")
    public func setTvPowerState(playerId: String, powerState: String) async throws {
        try await homeTheaterService.setTvPowerState(playerId: playerId, powerState: powerState)
    }
}
