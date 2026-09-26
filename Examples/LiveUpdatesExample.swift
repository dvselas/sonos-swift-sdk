//
//  LiveUpdatesExample.swift
//  SonosSDK
//
//  Real-time playback state over the local network.
//

import SwiftUI
import SonosSDK

@MainActor
final class LiveGroupViewModel: ObservableObject {

    @Published var playbackState = "PLAYBACK_STATE_IDLE"
    @Published var trackName: String?
    @Published var positionMillis: UInt = 0
    @Published var volume = 0

    private let sonosManager: SonosManager
    private let groupId: String
    private var eventsTask: Task<Void, Never>?

    init(sonosManager: SonosManager, groupId: String) {
        self.sonosManager = sonosManager
        self.groupId = groupId
    }

    func start(householdId: String) async throws {
        // Bootstrap the topology (and each player's websocketUrl) once from the cloud.
        let (groups, players) = try await sonosManager.getGroups(householdId: householdId, useCache: false)
        let live = await sonosManager.startLiveUpdates(householdId: householdId, groups: groups, players: players)

        eventsTask = Task { [weak self] in
            for await event in live.events {
                self?.apply(event)
            }
        }
    }

    func stop() async {
        eventsTask?.cancel()
        await sonosManager.stopLiveUpdates()
    }

    /// Commands go over the LAN while live updates run.
    func togglePlayPause() async {
        try? await sonosManager.togglePlayPause(groupId: groupId)
    }

    private func apply(_ event: SonosLiveEvent) {
        switch event {
        case .playbackStatus(groupId, let status):
            playbackState = status.playbackState
            positionMillis = status.positionMillis
        case .metadataStatus(groupId, let metadata):
            trackName = metadata.currentItem?.track?.name
        case .groupVolume(groupId, let groupVolume):
            volume = groupVolume.volume
        default:
            break
        }
    }
}
