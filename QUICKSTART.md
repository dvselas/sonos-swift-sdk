# Quick Start Guide - Real-Time Sonos Control

Get up and running with real-time Sonos control in minutes!

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/JimmyJammed/sonos-swift-sdk.git", from: "1.0.0")
]
```

## Basic Setup

```swift
import SonosSDK

// Initialize the SDK
let sonosManager = SonosManager(
    keyName: "My App",
    key: "your-api-key",
    secret: "your-api-secret",
    redirectURI: "yourapp://callback",
    callbackURL: "https://yourserver.com/webhook"
)
```

## Authenticate

```swift
// Trigger OAuth flow
sonosManager.authenticate()

// Or load saved token
sonosManager.loadAuthenticationToken()
```

## Get Started with Real-Time Updates (3 Steps)

### Step 1: Get Players and Start WebSocket

```swift
Task {
    // Get household ID
    let households = try await sonosManager.getHouseholds()
    guard let householdId = households.first?.id else { return }

    // Get players
    let players = try await sonosManager.getPlayers(householdId: householdId)

    // Start WebSocket connections for real-time updates
    sonosManager.startWebSocketsForPlayers(players)
}
```

### Step 2: Subscribe to Events

```swift
import Combine

var cancellables = Set<AnyCancellable>()

// Volume changes
sonosManager.subscriptionCoordinator.groupVolumePublisher
    .receive(on: DispatchQueue.main)
    .sink { groupId, volume in
        print("🔊 Volume: \(volume.volume)")
        updateVolumeUI(volume.volume)
    }
    .store(in: &cancellables)

// Playback state changes
sonosManager.subscriptionCoordinator.playbackStatusPublisher
    .receive(on: DispatchQueue.main)
    .sink { groupId, status in
        print("▶️ State: \(status.playbackState)")
        updatePlaybackUI(status)
    }
    .store(in: &cancellables)

// Track changes
sonosManager.subscriptionCoordinator.metadataPublisher
    .receive(on: DispatchQueue.main)
    .sink { groupId, metadata in
        print("🎵 Now Playing: \(metadata.currentItem?.trackName ?? "Unknown")")
        updateTrackInfoUI(metadata)
    }
    .store(in: &cancellables)
```

### Step 3: Control Playback

```swift
// Get current group
let (groups, _) = try await sonosManager.getGroups(householdId: householdId)
guard let groupId = groups.first?.id else { return }

// Play/Pause
try await sonosManager.setGroupPlaybackPlay(groupId: groupId)
try await sonosManager.setGroupPlaybackPause(groupId: groupId)

// Skip tracks
try await sonosManager.setGroupSkipToNext(groupId: groupId)
try await sonosManager.setGroupSkipToPrevious(groupId: groupId)

// Set volume
try await sonosManager.setGroupVolume(groupId: groupId, volume: 50)
```

## Complete SwiftUI Example

```swift
import SwiftUI
import Combine
import SonosSDK

struct NowPlayingView: View {
    @StateObject var viewModel: NowPlayingViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Connection indicator
            HStack {
                Circle()
                    .fill(viewModel.isConnected ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(viewModel.isConnected ? "Live" : "Offline")
                    .font(.caption)
            }

            // Track info
            VStack {
                Text(viewModel.trackName)
                    .font(.title2)
                    .bold()
                Text(viewModel.artistName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Playback controls
            HStack(spacing: 40) {
                Button { Task { await viewModel.skipPrevious() } } {
                    Image(systemName: "backward.fill")
                }

                Button { Task { await viewModel.togglePlayPause() } } {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                }

                Button { Task { await viewModel.skipNext() } } {
                    Image(systemName: "forward.fill")
                }
            }

            // Volume
            HStack {
                Image(systemName: "speaker.fill")
                Slider(value: $viewModel.volume, in: 0...100)
                    .onChange(of: viewModel.volume) { newValue in
                        Task { await viewModel.setVolume(Int(newValue)) }
                    }
                Image(systemName: "speaker.wave.3.fill")
            }
            .padding()
        }
        .padding()
        .task {
            await viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}

@MainActor
class NowPlayingViewModel: ObservableObject {
    @Published var trackName = "Not Playing"
    @Published var artistName = ""
    @Published var isPlaying = false
    @Published var volume: Double = 50
    @Published var isConnected = false

    private let sonosManager: SonosManager
    private let householdId: String
    private var groupId: String?
    private var cancellables = Set<AnyCancellable>()

    init(sonosManager: SonosManager, householdId: String) {
        self.sonosManager = sonosManager
        self.householdId = householdId
    }

    func start() async {
        do {
            // Get players and start WebSocket
            let players = try await sonosManager.getPlayers(householdId: householdId)
            sonosManager.startWebSocketsForPlayers(players)

            // Get groups
            let (groups, _) = try await sonosManager.getGroups(householdId: householdId)
            self.groupId = groups.first?.id

            guard let groupId = groupId else { return }

            // Load initial state
            let status = try await sonosManager.getGroupPlaybackStatus(groupId: groupId)
            self.isPlaying = status.playbackState == "PLAYBACK_STATE_PLAYING"

            let volumeData = try await sonosManager.getGroupVolume(groupId: groupId)
            self.volume = Double(volumeData.volume)

            // Subscribe to events
            setupSubscriptions()

            isConnected = true
        } catch {
            print("Error starting: \(error)")
        }
    }

    func stop() {
        sonosManager.stopAllWebSockets()
        isConnected = false
    }

    private func setupSubscriptions() {
        // Playback changes
        sonosManager.subscriptionCoordinator.playbackStatusPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.groupId == self.groupId }
            .sink { [weak self] _, status in
                self?.isPlaying = status.playbackState == "PLAYBACK_STATE_PLAYING"
            }
            .store(in: &cancellables)

        // Metadata changes
        sonosManager.subscriptionCoordinator.metadataPublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.groupId == self.groupId }
            .sink { [weak self] _, metadata in
                self?.trackName = metadata.currentItem?.trackName ?? "Unknown"
                self?.artistName = metadata.currentItem?.artistName ?? ""
            }
            .store(in: &cancellables)

        // Volume changes
        sonosManager.subscriptionCoordinator.groupVolumePublisher
            .receive(on: DispatchQueue.main)
            .filter { $0.groupId == self.groupId }
            .sink { [weak self] _, volumeData in
                self?.volume = Double(volumeData.volume)
            }
            .store(in: &cancellables)
    }

    func togglePlayPause() async {
        guard let groupId = groupId else { return }
        do {
            if isPlaying {
                try await sonosManager.setGroupPlaybackPause(groupId: groupId)
            } else {
                try await sonosManager.setGroupPlaybackPlay(groupId: groupId)
            }
        } catch {
            print("Error toggling playback: \(error)")
        }
    }

    func skipNext() async {
        guard let groupId = groupId else { return }
        try? await sonosManager.setGroupSkipToNext(groupId: groupId)
    }

    func skipPrevious() async {
        guard let groupId = groupId else { return }
        try? await sonosManager.setGroupSkipToPrevious(groupId: groupId)
    }

    func setVolume(_ volume: Int) async {
        guard let groupId = groupId else { return }
        try? await sonosManager.setGroupVolume(groupId: groupId, volume: volume)
    }
}
```

## Common Patterns

### Check WebSocket Status

```swift
let states = sonosManager.subscriptionCoordinator.getConnectionStates()
for (playerId, state) in states {
    switch state {
    case .connected:
        print("✅ \(playerId) connected")
    case .reconnecting(let attempt):
        print("🔄 Reconnecting... attempt \(attempt)")
    case .failed(let error):
        print("❌ Failed: \(error)")
    default:
        break
    }
}
```

### Force Fresh Data (Bypass Cache)

```swift
let freshStatus = try await sonosManager.getGroupPlaybackStatus(
    groupId: groupId,
    useCache: false
)
```

### Monitor Cache Performance

```swift
let stats = sonosManager.stateCache.getCacheStatistics()
print("""
    Cache Stats:
    - Total entries: \(stats.totalEntries)
    - Playback status: \(stats.playbackStatusCount)
    - Volume: \(stats.groupVolumeCount + stats.playerVolumeCount)
    """)
```

## Best Practices

### ✅ DO

- Start WebSocket when UI becomes active
- Stop WebSocket when UI goes to background
- Use cached data for frequently accessed info
- Subscribe to events for automatic UI updates
- Handle connection failures gracefully

### ❌ DON'T

- Keep WebSocket running when app is in background
- Poll API when WebSocket is available
- Bypass cache without good reason
- Forget to store Combine subscriptions in `cancellables`

## Troubleshooting

### WebSocket Not Connecting?
```swift
// Check player has valid websocketURL
if let url = URL(string: player.websocketURL) {
    print("WebSocket URL: \(url)")
} else {
    print("Invalid WebSocket URL!")
}
```

### Not Receiving Events?
```swift
// 1. Verify WebSocket is connected
let hasConnections = sonosManager.subscriptionCoordinator.hasActiveConnections
print("Has active connections: \(hasConnections)")

// 2. Check you stored the subscription
sonosManager.subscriptionCoordinator.playbackStatusPublisher
    .sink { groupId, status in
        print("Received: \(status)")
    }
    .store(in: &cancellables) // Don't forget this!
```

### Cache Issues?
```swift
// Clear cache manually if needed
sonosManager.stateCache.invalidateAll()

// Or invalidate specific items
sonosManager.stateCache.invalidatePlaybackStatus(for: groupId)
```

## Next Steps

1. Read [OPTIMIZATION_GUIDE.md](OPTIMIZATION_GUIDE.md) for comprehensive documentation
2. Check [Examples/RealtimePlaybackExample.swift](Examples/RealtimePlaybackExample.swift) for complete example
3. Review [OPTIMIZATION_SUMMARY.md](OPTIMIZATION_SUMMARY.md) for technical details

## Support

- API Documentation: https://docs.sonos.com
- SDK Issues: GitHub Issues
- Questions: Stack Overflow with tag `sonos-sdk`

---

**Happy Coding! 🎵**
