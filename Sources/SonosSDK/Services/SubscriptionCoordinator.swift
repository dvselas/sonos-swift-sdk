//
//  SubscriptionCoordinator.swift
//  SonosSDK
//
//  Modernized with auto-resubscribe on reconnect
//

import Foundation
import Combine

/// Coordinates subscriptions, WebSocket connections, and state management
public class SubscriptionCoordinator {

    // MARK: - Properties

    private var webSocketManagers: [String: WebSocketManager] = [:]
    private var subscriptions = Set<AnyCancellable>()
    private let cache = StateCacheManager.shared

    /// Tracks active subscriptions per player for auto-resubscribe
    private var activeSubscriptions: [String: Set<SonosNamespace>] = [:]

    /// HTTP client for re-subscribing (set by SonosManager)
    public var httpClient: HTTPClientProtocol?

    // Combine publishers for state updates
    public let playbackStatusPublisher = PassthroughSubject<(groupId: String, status: PlaybackStateChangedEvent), Never>()
    public let metadataPublisher = PassthroughSubject<(groupId: String, metadata: MetadataChangedEvent), Never>()
    public let groupVolumePublisher = PassthroughSubject<(groupId: String, volume: GroupVolume), Never>()
    public let playerVolumePublisher = PassthroughSubject<(playerId: String, volume: PlayerVolume), Never>()
    public let groupChangePublisher = PassthroughSubject<GroupChangedEvent, Never>()
    public let playbackSessionPublisher = PassthroughSubject<(sessionId: String, event: PlaybackSessionEvent), Never>()
    public let favoritesChangePublisher = PassthroughSubject<FavoritesChangedEvent, Never>()
    public let playlistsChangePublisher = PassthroughSubject<PlaylistsChangedEvent, Never>()
    public let audioClipStatusPublisher = PassthroughSubject<AudioClipStatusEvent, Never>()

    private let processingQueue = DispatchQueue(label: "com.sonos.subscription.processing", qos: .userInitiated)

    // MARK: - Player WebSocket Management

    /// Start WebSocket connection for a player
    public func startWebSocket(for player: Player) {
        guard webSocketManagers[player.id] == nil else { return }
        guard let url = URL(string: player.websocketUrl) else {
            print("[SubscriptionCoordinator] Invalid WebSocket URL for player: \(player.id)")
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

        // Subscribe to connection state for auto-resubscribe
        manager.connectionStatePublisher
            .sink { [weak self] state in
                if case .connected = state {
                    self?.resubscribeOnReconnect(playerId: player.id)
                }
            }
            .store(in: &subscriptions)

        manager.connect(to: url)
    }

    /// Stop WebSocket connection for a player
    public func stopWebSocket(for playerId: String) {
        webSocketManagers[playerId]?.disconnect()
        webSocketManagers.removeValue(forKey: playerId)
        activeSubscriptions.removeValue(forKey: playerId)
    }

    /// Stop all WebSocket connections
    public func stopAllWebSockets() {
        webSocketManagers.values.forEach { $0.disconnect() }
        webSocketManagers.removeAll()
        activeSubscriptions.removeAll()
    }

    // MARK: - Subscription Tracking

    /// Track that a namespace subscription is active for a player
    public func trackSubscription(namespace: SonosNamespace, for playerId: String) {
        if activeSubscriptions[playerId] == nil {
            activeSubscriptions[playerId] = []
        }
        activeSubscriptions[playerId]?.insert(namespace)
    }

    /// Remove tracking for a namespace subscription
    public func untrackSubscription(namespace: SonosNamespace, for playerId: String) {
        activeSubscriptions[playerId]?.remove(namespace)
    }

    /// Get active subscriptions for a player
    public func getActiveSubscriptions(for playerId: String) -> Set<SonosNamespace> {
        activeSubscriptions[playerId] ?? []
    }

    // MARK: - Auto-Resubscribe

    private func resubscribeOnReconnect(playerId: String) {
        guard let namespaces = activeSubscriptions[playerId], !namespaces.isEmpty else { return }
        guard let client = httpClient else { return }

        Task {
            for namespace in namespaces {
                do {
                    let endpoint = subscribeEndpoint(for: namespace, playerId: playerId)
                    if let endpoint {
                        try await client.request(endpoint)
                        print("[SubscriptionCoordinator] Re-subscribed to \(namespace.rawValue) for player \(playerId)")
                    }
                } catch {
                    print("[SubscriptionCoordinator] Failed to re-subscribe to \(namespace.rawValue): \(error)")
                }
            }
        }
    }

    private func subscribeEndpoint(for namespace: SonosNamespace, playerId: String) -> SonosAPIEndpoint? {
        switch namespace {
        case .playback: return .subscribeToPlayback(groupId: playerId)
        case .playbackMetadata: return .subscribeToPlaybackMetadata(groupId: playerId)
        case .groupVolume: return .subscribeToGroupVolume(groupId: playerId)
        case .playerVolume: return .subscribeToPlayerVolume(playerId: playerId)
        case .audioClip: return .subscribeToAudioClip(playerId: playerId)
        case .groups, .favorites, .playlists, .playbackSession:
            return nil // These are household-level, not player-level
        }
    }

    // MARK: - Message Handling

    private func handleWebSocketMessage(_ message: WebSocketMessage, playerId: String) {
        guard let event = SubscriptionEventParser.parse(message: message) else {
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
            break
        }
    }

    // MARK: - Event Handlers

    private func handlePlaybackEvent(_ event: PlaybackEvent) {
        switch event {
        case .stateChanged(let stateEvent):
            cache.invalidatePlaybackStatus(for: stateEvent.groupId)
            playbackStatusPublisher.send((groupId: stateEvent.groupId, status: stateEvent))
        case .errorOccurred(let errorEvent):
            print("[Playback] Error for group \(errorEvent.groupId): \(errorEvent.errorCode)")
        }
    }

    private func handleMetadataEvent(_ event: MetadataEvent) {
        switch event {
        case .changed(let metadataEvent):
            cache.invalidatePlaybackMetadata(for: metadataEvent.groupId)
            metadataPublisher.send((groupId: metadataEvent.groupId, metadata: metadataEvent))
        }
    }

    private func handleGroupVolumeEvent(_ event: GroupVolumeEvent) {
        switch event {
        case .changed(let volumeEvent):
            let volume = GroupVolume(volume: volumeEvent.volume, muted: volumeEvent.muted, fixed: volumeEvent.fixed)
            cache.setGroupVolume(volume, for: volumeEvent.id)
            groupVolumePublisher.send((groupId: volumeEvent.id, volume: volume))
        }
    }

    private func handlePlayerVolumeEvent(_ event: PlayerVolumeEvent) {
        switch event {
        case .changed(let volumeEvent):
            let volume = PlayerVolume(volume: volumeEvent.volume, muted: volumeEvent.muted, fixed: volumeEvent.fixed)
            cache.setPlayerVolume(volume, for: volumeEvent.id)
            playerVolumePublisher.send((playerId: volumeEvent.id, volume: volume))
        }
    }

    private func handleGroupEvent(_ event: GroupEvent) {
        switch event {
        case .changed(let changeEvent):
            cache.invalidateGroups()
            groupChangePublisher.send(changeEvent)
        case .coordinatorChanged:
            cache.invalidateGroups()
        }
    }

    private func handleAudioClipEvent(_ event: AudioClipEvent) {
        switch event {
        case .statusChanged(let statusEvent):
            audioClipStatusPublisher.send(statusEvent)
        }
    }

    private func handleFavoritesEvent(_ event: FavoritesEvent) {
        switch event {
        case .changed(let changeEvent):
            favoritesChangePublisher.send(changeEvent)
        }
    }

    private func handlePlaylistsEvent(_ event: PlaylistsEvent) {
        switch event {
        case .changed(let changeEvent):
            playlistsChangePublisher.send(changeEvent)
        }
    }

    private func handlePlaybackSessionEvent(_ event: PlaybackSessionEvent) {
        switch event {
        case .sessionEvicted(let evictedEvent):
            playbackSessionPublisher.send((evictedEvent.sessionId, event))
        case .sessionError(let errorEvent):
            playbackSessionPublisher.send((errorEvent.sessionId, event))
        }
    }

    // MARK: - Connection Status

    public func getConnectionStates() -> [String: WebSocketManager.ConnectionState] {
        var states: [String: WebSocketManager.ConnectionState] = [:]
        for (playerId, manager) in webSocketManagers {
            states[playerId] = manager.connectionState
        }
        return states
    }

    public var hasActiveConnections: Bool {
        webSocketManagers.values.contains { manager in
            if case .connected = manager.connectionState { return true }
            return false
        }
    }

    deinit {
        stopAllWebSockets()
        subscriptions.removeAll()
    }
}
