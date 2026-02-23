//
//  HomeTheaterService.swift
//  SonosSDK
//

import Foundation

struct HomeTheaterService {

    private let client: HTTPClientProtocol

    init(client: HTTPClientProtocol) {
        self.client = client
    }

    func getOptions(playerId: String) async throws -> HomeTheaterOptions {
        try await client.request(.getHomeTheaterOptions(playerId: playerId))
    }

    func setOptions(playerId: String, nightMode: Bool? = nil, enhanceDialog: Bool? = nil) async throws {
        try await client.request(.setHomeTheaterOptions(playerId: playerId, nightMode: nightMode, enhanceDialog: enhanceDialog))
    }

    /// Load home theater playback (switch to TV input)
    func loadHomeTheaterPlayback(playerId: String) async throws {
        try await client.request(.loadHomeTheaterPlayback(playerId: playerId))
    }

    /// Set TV power state ("on" or "standby")
    func setTvPowerState(playerId: String, powerState: String) async throws {
        try await client.request(.setTvPowerState(playerId: playerId, powerState: powerState))
    }
}
