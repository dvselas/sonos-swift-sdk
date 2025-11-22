//
//  RealtimePlaybackExample.swift
//  SonosSDK
//
//  Example demonstrating real-time playback updates with WebSocket
//

import SwiftUI
import Combine
import SonosSDK

@available(iOS 14.0, *)
class RealtimePlaybackViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var playbackState: String = "Unknown"
    @Published var currentTrack: String = "No track"
    @Published var currentArtist: String = ""
    @Published var positionMillis: UInt = 0
    @Published var volume: Int = 0
    @Published var isConnected: Bool = false

    // MARK: - Private Properties

    private let sonosManager: SonosManager
    private let groupId: String
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(sonosManager: SonosManager, groupId: String) {
        self.sonosManager = sonosManager
        self.groupId = groupId

        setupSubscriptions()
    }

    // MARK: - Setup

    func startRealtimeUpdates() async {
        do {
            // Get players and start WebSocket connections
            let householdId = "your-household-id"
            let players = try await sonosManager.getPlayers(householdId: householdId)

            // Start WebSocket for all players
            sonosManager.startWebSocketsForPlayers(players)

            // Subscribe to API events
            try await sonosManager.subscribeToGroupVolume(groupId: groupId)

            // Initial data fetch
            await refreshData()

            isConnected = true
        } catch {
            print("Failed to start real-time updates: \(error)")
        }
    }

    func stopRealtimeUpdates() {
        sonosManager.stopAllWebSockets()
        isConnected = false
    }

    private func setupSubscriptions() {
        // Subscribe to playback status changes
        sonosManager.subscriptionCoordinator.playbackStatusPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.groupId == self.groupId }
            .sink { [weak self] _, status in
                self?.playbackState = status.playbackState
                self?.positionMillis = status.positionMillis
            }
            .store(in: &cancellables)

        // Subscribe to metadata changes
        sonosManager.subscriptionCoordinator.metadataPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.groupId == self.groupId }
            .sink { [weak self] _, metadata in
                self?.currentTrack = metadata.currentItem?.trackName ?? "Unknown"
                self?.currentArtist = metadata.currentItem?.artistName ?? ""
            }
            .store(in: &cancellables)

        // Subscribe to volume changes
        sonosManager.subscriptionCoordinator.groupVolumePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.groupId == self.groupId }
            .sink { [weak self] _, volumeData in
                self?.volume = volumeData.volume
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func play() async {
        do {
            try await sonosManager.setGroupPlaybackPlay(groupId: groupId)
        } catch {
            print("Failed to play: \(error)")
        }
    }

    func pause() async {
        do {
            try await sonosManager.setGroupPlaybackPause(groupId: groupId)
        } catch {
            print("Failed to pause: \(error)")
        }
    }

    func skipNext() async {
        do {
            try await sonosManager.setGroupSkipToNext(groupId: groupId)
        } catch {
            print("Failed to skip: \(error)")
        }
    }

    func skipPrevious() async {
        do {
            try await sonosManager.setGroupSkipToPrevious(groupId: groupId)
        } catch {
            print("Failed to skip back: \(error)")
        }
    }

    func setVolume(_ newVolume: Int) async {
        do {
            try await sonosManager.setGroupVolume(groupId: groupId, volume: newVolume)
        } catch {
            print("Failed to set volume: \(error)")
        }
    }

    func refreshData() async {
        do {
            // Fetch current state (uses cache if available)
            let status = try await sonosManager.getGroupPlaybackStatus(groupId: groupId)
            let volumeData = try await sonosManager.getGroupVolume(groupId: groupId)

            await MainActor.run {
                playbackState = status.playbackState
                positionMillis = status.positionMillis
                volume = volumeData.volume
            }
        } catch {
            print("Failed to refresh: \(error)")
        }
    }
}

// MARK: - SwiftUI View

@available(iOS 14.0, *)
struct RealtimePlaybackView: View {

    @StateObject var viewModel: RealtimePlaybackViewModel

    var body: some View {
        VStack(spacing: 20) {

            // Connection Status
            HStack {
                Circle()
                    .fill(viewModel.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(viewModel.isConnected ? "Connected" : "Disconnected")
                    .font(.caption)
            }

            // Now Playing
            VStack {
                Text(viewModel.currentTrack)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(viewModel.currentArtist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Playback State
            Text(viewModel.playbackState)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)

            // Position
            Text(formatTime(viewModel.positionMillis))
                .font(.body)
                .monospacedDigit()

            // Playback Controls
            HStack(spacing: 30) {
                Button(action: {
                    Task { await viewModel.skipPrevious() }
                }) {
                    Image(systemName: "backward.fill")
                        .font(.title)
                }

                Button(action: {
                    Task {
                        if viewModel.playbackState == "PLAYBACK_STATE_PLAYING" {
                            await viewModel.pause()
                        } else {
                            await viewModel.play()
                        }
                    }
                }) {
                    Image(systemName: viewModel.playbackState == "PLAYBACK_STATE_PLAYING" ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                }

                Button(action: {
                    Task { await viewModel.skipNext() }
                }) {
                    Image(systemName: "forward.fill")
                        .font(.title)
                }
            }

            // Volume Control
            VStack {
                HStack {
                    Image(systemName: "speaker.fill")
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.volume) },
                            set: { newValue in
                                Task {
                                    await viewModel.setVolume(Int(newValue))
                                }
                            }
                        ),
                        in: 0...100,
                        step: 1
                    )
                    Image(systemName: "speaker.wave.3.fill")
                }
                Text("Volume: \(viewModel.volume)")
                    .font(.caption)
            }
            .padding()
        }
        .padding()
        .task {
            await viewModel.startRealtimeUpdates()
        }
        .onDisappear {
            viewModel.stopRealtimeUpdates()
        }
    }

    private func formatTime(_ millis: UInt) -> String {
        let seconds = Int(millis / 1000)
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Preview

@available(iOS 14.0, *)
struct RealtimePlaybackView_Previews: PreviewProvider {
    static var previews: some View {
        let sonosManager = SonosManager(
            keyName: "test",
            key: "test-key",
            secret: "test-secret",
            redirectURI: "test://callback",
            callbackURL: "test://callback"
        )

        let viewModel = RealtimePlaybackViewModel(
            sonosManager: sonosManager,
            groupId: "test-group-id"
        )

        RealtimePlaybackView(viewModel: viewModel)
    }
}
