//
//  SubscriptionCoordinator.swift
//  SonosSDK
//
//  Created on 2025-01-22.
//

import Foundation
import Combine

/// Coordinates subscriptions, WebSocket connections, and state management
public class SubscriptionCoordinator {

    // MARK: - Properties

    private var webSocketManagers: [String: WebSocketManager] = [:]
    private var subscriptions = Set<AnyCancellable>()
    private let cache = StateCacheManager.shared

    // Publishers for state updates
    public let playbackStatusPublisher = PassthroughSubject<(groupId: String, status: PlaybackStatus), Never>()
    public let metadataPublisher = PassthroughSubject<(groupId: String, metadata: MetadataChangedEvent), Never>()
    public let groupVolumePublisher = PassthroughSubject<(groupId: String, volume: GroupVolume), Never>()
    public let playerVolumePublisher = PassthroughSubject<(playerId: String, volume: PlayerVolume), Never>()
    public let groupChangePublisher = PassthroughSubject<GroupChangedEvent, Never>()
    public let playbackSessionPublisher = PassthroughSubject<(sessionId: String, event: PlaybackSessionEvent), Never>()

    private let processingQueue = DispatchQueue(label: "com.sonos.subscription.processing", qos: .userInitiated)

    // MARK: - Player WebSocket Management

    /// Start WebSocket connection for a player
    /// - Parameter player: The player to connect to
    public func startWebSocket(for player: Player) {
        guard webSocketManagers[player.id] == nil else {
            return // Already connected
        }

        guard let url = URL(string: player.websocketURL) else {
            print("Invalid WebSocket URL for player: \(player.id)")
            return
        }

        let manager = WebSocketManager()
        webSocketManagers[player.id] = manager

        // Subscribe to messages
        manager.messagePublisher
            .receive(on: processingQueue)
            .sink { [weak self] message in
                self?.handleWebSocketMessage(message, playerId: player.id)
            }
            .store(in: &subscriptions)

        // Subscribe to connection state
        manager.connectionStatePublisher
            .sink { state in
                print("WebSocket for player \(player.id): \(state)")
            }
            .store(in: &subscriptions)

        manager.connect(to: url)
    }

    /// Stop WebSocket connection for a player
    /// - Parameter playerId: The player ID
    public func stopWebSocket(for playerId: String) {
        webSocketManagers[playerId]?.disconnect()
        webSocketManagers.removeValue(forKey: playerId)
    }

    /// Stop all WebSocket connections
    public func stopAllWebSockets() {
        webSocketManagers.values.forEach { $0.disconnect() }
        webSocketManagers.removeAll()
    }

    // MARK: - Message Handling

    private func handleWebSocketMessage(_ message: WebSocketMessage, playerId: String) {
        guard let event = SubscriptionEventParser.parse(message: message) else {
            print("Failed to parse event from namespace: \(message.namespace)")
            return
        }

        switch event {
        case let playbackEvent as PlaybackEvent:
            handlePlaybackEvent(playbackEvent)

        case let metadataEvent as MetadataEvent:
            handleMetadataEvent(metadataEvent)

        case let volumeEvent as GroupVolumeEvent:
            handleGroupVolumeEvent(volumeEvent)

        case let volumeEvent as PlayerVolumeEvent:
            handlePlayerVolumeEvent(volumeEvent)

        case let groupEvent as GroupEvent:
            handleGroupEvent(groupEvent)

        case let audioClipEvent as AudioClipEvent:
            handleAudioClipEvent(audioClipEvent)

        case let favoritesEvent as FavoritesEvent:
            handleFavoritesEvent(favoritesEvent)

        case let playlistsEvent as PlaylistsEvent:
            handlePlaylistsEvent(playlistsEvent)

        case let sessionEvent as PlaybackSessionEvent:
            handlePlaybackSessionEvent(sessionEvent)

        default:
            print("Unhandled event type: \(type(of: event))")
        }
    }

    // MARK: - Event Handlers

    private func handlePlaybackEvent(_ event: PlaybackEvent) {
        switch event {
        case .stateChanged(let stateEvent):
            // Invalidate cache and fetch fresh data
            cache.invalidatePlaybackStatus(for: stateEvent.groupId)

            // Notify observers - they should fetch fresh data
            // We could also construct a PlaybackStatus from the event, but fetching ensures consistency
            print("Playback state changed for group: \(stateEvent.groupId), state: \(stateEvent.playbackState)")

        case .errorOccurred(let errorEvent):
            print("Playback error for group: \(errorEvent.groupId), code: \(errorEvent.errorCode)")
        }
    }

    private func handleMetadataEvent(_ event: MetadataEvent) {
        switch event {
        case .changed(let metadataEvent):
            cache.invalidatePlaybackMetadata(for: metadataEvent.groupId)
            metadataPublisher.send((groupId: metadataEvent.groupId, metadata: metadataEvent))
            print("Metadata changed for group: \(metadataEvent.groupId)")
        }
    }

    private func handleGroupVolumeEvent(_ event: GroupVolumeEvent) {
        switch event {
        case .changed(let volumeEvent):
            // Update cache immediately with event data
            let volume = GroupVolume(
                volume: volumeEvent.volume,
                muted: volumeEvent.muted,
                fixed: volumeEvent.fixed
            )
            cache.setGroupVolume(volume, for: volumeEvent.id)
            groupVolumePublisher.send((groupId: volumeEvent.id, volume: volume))
            print("Group volume changed: \(volumeEvent.id), volume: \(volumeEvent.volume)")
        }
    }

    private func handlePlayerVolumeEvent(_ event: PlayerVolumeEvent) {
        switch event {
        case .changed(let volumeEvent):
            // Update cache immediately with event data
            let volume = PlayerVolume(
                volume: volumeEvent.volume,
                muted: volumeEvent.muted,
                fixed: volumeEvent.fixed
            )
            cache.setPlayerVolume(volume, for: volumeEvent.id)
            playerVolumePublisher.send((playerId: volumeEvent.id, volume: volume))
            print("Player volume changed: \(volumeEvent.id), volume: \(volumeEvent.volume)")
        }
    }

    private func handleGroupEvent(_ event: GroupEvent) {
        switch event {
        case .changed(let changeEvent):
            // Invalidate groups cache - requires full refresh
            cache.invalidateGroups()
            groupChangePublisher.send(changeEvent)
            print("Group changed: \(changeEvent.groupId), type: \(changeEvent.changeType)")

        case .coordinatorChanged(let coordinatorEvent):
            cache.invalidateGroups()
            print("Group coordinator changed: \(coordinatorEvent.groupId)")
        }
    }

    private func handleAudioClipEvent(_ event: AudioClipEvent) {
        switch event {
        case .statusChanged(let statusEvent):
            print("Audio clip status: \(statusEvent.playerId), status: \(statusEvent.status)")
        }
    }

    private func handleFavoritesEvent(_ event: FavoritesEvent) {
        switch event {
        case .changed(let changeEvent):
            print("Favorites changed for household: \(changeEvent.householdId)")
        }
    }

    private func handlePlaylistsEvent(_ event: PlaylistsEvent) {
        switch event {
        case .changed(let changeEvent):
            print("Playlists changed for household: \(changeEvent.householdId)")
        }
    }

    private func handlePlaybackSessionEvent(_ event: PlaybackSessionEvent) {
        switch event {
        case .sessionEvicted(let evictedEvent):
            print("Session evicted: \(evictedEvent.sessionId), reason: \(evictedEvent.reason ?? "unknown")")
            playbackSessionPublisher.send((evictedEvent.sessionId, event))

        case .sessionError(let errorEvent):
            print("Session error: \(errorEvent.sessionId), code: \(errorEvent.errorCode)")
            playbackSessionPublisher.send((errorEvent.sessionId, event))
        }
    }

    // MARK: - Connection Status

    /// Get connection states for all active WebSockets
    public func getConnectionStates() -> [String: WebSocketManager.ConnectionState] {
        var states: [String: WebSocketManager.ConnectionState] = [:]
        for (playerId, manager) in webSocketManagers {
            states[playerId] = manager.connectionState
        }
        return states
    }

    /// Check if any WebSocket is connected
    public var hasActiveConnections: Bool {
        webSocketManagers.values.contains { manager in
            if case .connected = manager.connectionState {
                return true
            }
            return false
        }
    }

    deinit {
        stopAllWebSockets()
        subscriptions.removeAll()
    }
}

// MARK: - Helper Extensions

extension GroupVolume {
    init(volume: Int, muted: Bool, fixed: Bool) {
        self.init()
        self.volume = volume
        self.muted = muted
        self.fixed = fixed
    }
}

extension PlayerVolume {
    init(volume: Int, muted: Bool, fixed: Bool) {
        self.init()
        self.volume = volume
        self.muted = muted
        self.fixed = fixed
    }
}
