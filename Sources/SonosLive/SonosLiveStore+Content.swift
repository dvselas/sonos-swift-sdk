//
//  SonosLiveStore+Content.swift
//  SonosLive
//
//  Playing music service items in one room, and finding the household's
//  music service accounts.
//
//  Rooms are taken out of their group before anything plays, like TV
//  autoplay: the other rooms keep the music. A coordinator can't simply
//  leave its group, so the other rooms move to a new group that takes over
//  the music (`createGroup` with `musicContextGroupId`); the new group
//  starts paused and is resumed right away.
//

import Foundation
import SonosSDK

public enum SonosLiveError: LocalizedError, Equatable {
    case notConnected
    case unknownPlayer(String)

    public var errorDescription: String? {
        switch self {
        case .notConnected: return "Sonos isn't connected yet."
        case .unknownPlayer(let id): return "No Sonos speaker with the id \(id)."
        }
    }
}

extension SonosLiveStore {

    /// Plays `content` in the room `playerId`, which leaves its group first.
    public func play(_ content: SonosContent, onPlayer playerId: String) async throws {
        let groupId = try await isolate(playerId)
        try await backend.loadContent(groupId: groupId, content: content, play: true)
    }

    /// Makes `playerId` a group of its own and returns that group's id. The
    /// other rooms keep playing what the group played.
    @discardableResult
    public func isolate(_ playerId: String) async throws -> String {
        guard let householdId else { throw SonosLiveError.notConnected }
        guard let group = state.group(containing: playerId) else { throw SonosLiveError.unknownPlayer(playerId) }
        guard group.isGrouped else { return group.groupId }

        let others = group.playerIds.filter { $0 != playerId }
        if group.coordinatorId == playerId {
            let wasPlaying = group.isPlaying
            let moved = try await backend.createGroup(householdId: householdId, playerIds: others,
                                                      musicContextGroupId: group.groupId)
            if wasPlaying {
                do {
                    try await backend.play(groupId: moved.id)
                } catch {
                    log("[Sonos] Could not resume \(moved.name) after taking \(playerId) out: \(error.localizedDescription)")
                }
            }
        } else {
            _ = try await backend.modifyGroupMembers(groupId: group.groupId, playerIdsToAdd: [], playerIdsToRemove: [playerId])
        }
        return try await refreshedGroupId(of: playerId, householdId: householdId)
    }

    /// Finds the accounts of one music service without playing anything.
    /// Loads `probe` (any item of that service) once per candidate and reads
    /// which account the players used: an unknown candidate falls back to
    /// the service's default account, so every distinct answer is a real
    /// account. Replaces the queue of the room's group.
    public func discoverAccounts(
        probe: SonosContent,
        onPlayer playerId: String,
        candidates: [String] = (1...12).map { "sn_\($0)" }
    ) async throws -> [String] {
        guard let group = state.group(containing: playerId) else { throw SonosLiveError.unknownPlayer(playerId) }
        var accounts = Set<String>()
        for candidate in candidates {
            let content = SonosContent(kind: probe.kind, serviceId: probe.serviceId,
                                       objectId: probe.objectId, accountId: candidate)
            try await backend.loadContent(groupId: group.groupId, content: content, play: false)
            if let used = await loadedAccount(of: probe, groupId: group.groupId) {
                accounts.insert(used)
            }
        }
        return accounts.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// The account of the loaded item once the players report it.
    private func loadedAccount(of probe: SonosContent, groupId: String) async -> String? {
        for attempt in 0..<10 {
            if attempt > 0 { try? await Task.sleep(for: .milliseconds(200)) }
            guard let metadata = try? await backend.getGroupPlaybackMetadata(groupId: groupId, useCache: false) else { continue }
            let ids = [metadata.currentItem?.track?.id, metadata.container?.id].compactMap { $0 }
            if let id = ids.first(where: { $0.serviceId == probe.serviceId }), let account = id.accountId {
                return account
            }
        }
        return nil
    }

    /// Reads the topology (over the LAN while live) and returns the room's group id.
    private func refreshedGroupId(of playerId: String, householdId: String) async throws -> String {
        let (groups, players) = try await backend.getGroups(householdId: householdId, useCache: false)
        state.apply(.topology(groups: groups, players: players), at: now())
        guard let group = groups.first(where: { $0.playerIds == [playerId] }) else {
            throw SonosLiveError.unknownPlayer(playerId)
        }
        return group.id
    }
}
