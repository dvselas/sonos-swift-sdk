//
//  SonosManager+Live.swift
//  SonosSDK
//
//  Real-time updates over the local network.
//
//  Usage:
//      let (groups, players) = try await manager.getGroups(householdId: id, useCache: false)
//      let live = await manager.startLiveUpdates(householdId: id, groups: groups, players: players)
//      for await event in live.events { … }
//
//  While live updates run, playback, metadata, volume and grouping calls
//  made through the manager go over the LAN and fall back to the cloud for
//  players that aren't reachable.
//

import Foundation

extension SonosManager {

    /// The running live client, if any.
    public var liveClient: SonosLiveClient? {
        liveRouter.client
    }

    /// Connects to the household's players and starts streaming events.
    /// Replaces (and stops) a previous live client.
    @discardableResult
    public func startLiveUpdates(
        householdId: String,
        groups: [Group],
        players: [Player],
        configuration: SonosLiveConfiguration = SonosLiveConfiguration()
    ) async -> SonosLiveClient {
        let client = SonosLiveClient(householdId: householdId, apiKey: self.client.key, configuration: configuration)
        if let previous = liveRouter.replace(with: client) {
            await previous.stop()
        }
        await client.start(groups: groups, players: players)
        startNetworkObservation(for: client)
        return client
    }

    /// Closes every local socket. Calls go to the cloud afterwards.
    public func stopLiveUpdates() async {
        stopNetworkObservation()
        if let previous = liveRouter.replace(with: nil) {
            await previous.stop()
        }
    }

    /// Stops `client`. Routing only falls back to the cloud if `client` is
    /// still the running one, so a late cleanup can't stop a newer client.
    public func stopLiveUpdates(_ client: SonosLiveClient) async {
        if liveRouter.clear(ifCurrent: client) {
            stopNetworkObservation()
        }
        await client.stop()
    }
}
