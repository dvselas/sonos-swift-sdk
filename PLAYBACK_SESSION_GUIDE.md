# Playback Session API - Complete Implementation Guide

Complete guide for using the Sonos playbackSession API to create custom cloud-based playback experiences in the Sonos Swift SDK.

## Overview

The playbackSession API allows your app to:
- **Create and manage playback sessions** for cloud-based queues
- **Load streaming URLs** for live radio stations
- **Load cloud queues** with custom track listings
- **Control session playback** independently from regular playback
- **Receive real-time events** when sessions are evicted or encounter errors

**All 11 playbackSession endpoints are fully implemented** with both callback-based and async/await APIs. ✅

---

## Quick Start

### 1. Create a Session (Async/Await)

```swift
import SonosSDK

let sonosManager = SonosManager.shared

do {
    // Create a new playback session
    let session = try await sonosManager.createPlaybackSession(
        groupId: "yourGroupId",
        appId: "com.yourcompany.yourapp",
        appContext: "user123",  // User account identifier
        customData: "{\"playlistId\": \"favorites-rock\"}"  // Optional custom data
    )

    print("Session created: \(session.sessionId)")
    print("Was newly created: \(session.sessionCreated ?? false)")
    print("Session state: \(session.sessionState ?? "")")

} catch {
    print("Error creating session: \(error)")
}
```

### 2. Load a Streaming Radio URL

```swift
do {
    // Load a live radio stream
    try await sonosManager.loadStreamUrl(
        groupId: "yourGroupId",
        sessionId: session.sessionId,
        streamUrl: "https://stream.radio.com/live",
        itemId: "station-kcrw",  // Optional - for tracking in events
        playOnCompletion: true,  // Start playing immediately
        stationMetadata: [       // Optional station info
            "name": "KCRW",
            "logo": "https://example.com/kcrw-logo.png"
        ]
    )

    print("Stream loaded and playing")
} catch {
    print("Error loading stream: \(error)")
}
```

### 3. Subscribe to Session Events

```swift
import Combine

class SessionManager {
    private var cancellables = Set<AnyCancellable>()
    private let sonosManager = SonosManager.shared

    func setupSessionMonitoring(sessionId: String) {
        // Subscribe to playbackSession events
        sonosManager.subscriptionCoordinator.playbackSessionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (eventSessionId, event) in
                guard eventSessionId == sessionId else { return }
                self?.handleSessionEvent(event)
            }
            .store(in: &cancellables)

        // Subscribe via API
        Task {
            try await sonosManager.subscribeToPlaybackSession(sessionId: sessionId)
        }
    }

    private func handleSessionEvent(_ event: PlaybackSessionEvent) {
        switch event {
        case .sessionEvicted(let evictedEvent):
            print("⚠️ Session evicted: \(evictedEvent.sessionId)")
            print("Reason: \(evictedEvent.reason ?? "Another app took control")")
            // Handle eviction - rejoin or create new session

        case .sessionError(let errorEvent):
            print("❌ Session error: \(errorEvent.errorCode)")
            print("Reason: \(errorEvent.reason ?? "Unknown error")")
            // Handle error - retry or show error to user
        }
    }
}
```

---

## Complete API Reference

### Session Management

#### createSession
Create a new playback session, replacing any existing session.

**Async/Await:**
```swift
func createPlaybackSession(
    groupId: String,
    appId: String,              // "com.yourcompany.yourapp"
    appContext: String,         // User/instance identifier
    accountId: String? = nil,   // Music service account
    customData: String? = nil   // Up to 1023 bytes of custom data
) async throws -> PlaybackSession
```

**Callback:**
```swift
func createPlaybackSession(
    groupId: String,
    appId: String,
    appContext: String,
    accountId: String? = nil,
    customData: String? = nil,
    success: @escaping (PlaybackSession) -> Void,
    failure: @escaping (Error?) -> Void
)
```

**Response:**
```swift
public struct PlaybackSession {
    public var sessionId: String        // Unique session identifier
    public var sessionState: String?    // "SESSION_STATE_CONNECTED"
    public var sessionCreated: Bool?    // true if new, false if joined
    public var customData: String?      // Custom data from session
}
```

#### joinSession
Join an existing session if it matches your appId and appContext.

```swift
func joinPlaybackSession(
    groupId: String,
    appId: String,
    appContext: String
) async throws -> PlaybackSession
```

#### suspendSession
Suspend the active session.

```swift
func suspendPlaybackSession(
    sessionId: String,
    queueVersion: String? = nil
) async throws
```

---

### Cloud Queue Operations

#### loadCloudQueue
Load a cloud-based queue into the session.

```swift
func loadCloudQueue(
    groupId: String,
    sessionId: String,
    queueBaseUrl: String,                      // Base URL for queue API
    httpAuthorization: String? = nil,          // Authorization header
    itemId: String? = nil,                     // Start item ID
    playOnCompletion: Bool? = nil,             // Auto-play
    positionMillis: UInt? = nil,               // Start position
    queueVersion: String? = nil,               // Queue version
    trackMetadata: [String: Any]? = nil,       // Track metadata
    useHttpAuthorizationForMedia: Bool? = nil  // Use auth for media URLs
) async throws
```

#### refreshCloudQueue
Refresh the cloud queue to pick up changes.

```swift
func refreshCloudQueue(
    groupId: String,
    sessionId: String
) async throws
```

---

### Stream URL

#### loadStreamUrl
Load a streaming (live) radio station URL.

```swift
func loadStreamUrl(
    groupId: String,
    sessionId: String,
    streamUrl: String,                     // HTTP URL for the stream
    itemId: String? = nil,                 // Optional ID for event tracking
    playOnCompletion: Bool? = nil,         // Start playing immediately
    stationMetadata: [String: Any]? = nil  // Station metadata
) async throws
```

**Station Metadata Example:**
```swift
let stationMetadata: [String: Any] = [
    "name": "KCRW Live",
    "description": "Music, News, Culture from Los Angeles",
    "logo": "https://example.com/kcrw-logo.png",
    "genre": "Public Radio"
]
```

---

### Session Playback Control

#### sessionSeek
Seek to a specific position within the current item.

```swift
func sessionSeek(
    groupId: String,
    sessionId: String,
    positionMillis: UInt,
    itemId: String  // Item to seek in
) async throws
```

#### sessionSeekRelative
Seek relative to the current position.

```swift
func sessionSeekRelative(
    groupId: String,
    sessionId: String,
    deltaMillis: Int  // Positive = forward, negative = backward
) async throws
```

#### sessionSkipToItem
Skip to a specific item in the queue.

```swift
func sessionSkipToItem(
    groupId: String,
    sessionId: String,
    itemId: String,
    playOnCompletion: Bool? = nil
) async throws
```

---

### Session Subscriptions

#### subscribe
Subscribe to session events via WebSocket.

```swift
func subscribeToPlaybackSession(sessionId: String) async throws
```

#### unsubscribe
Unsubscribe from session events.

```swift
func unsubscribeFromPlaybackSession(sessionId: String) async throws
```

---

## WebSocket Events

### Event Types

The SDK provides real-time notifications for two session event types:

#### 1. Session Evicted Event
Fired when another app creates a session and evicts yours.

```swift
public struct SessionEvictedEvent {
    public let sessionId: String
    public let reason: String?
    public let timestamp: Date
}
```

#### 2. Session Error Event
Fired when the session encounters an error.

```swift
public struct SessionErrorEvent {
    public let sessionId: String
    public let errorCode: String
    public let reason: String?
    public let timestamp: Date
}
```

### Listening to Events

```swift
sonosManager.subscriptionCoordinator.playbackSessionPublisher
    .sink { (sessionId, event) in
        switch event {
        case .sessionEvicted(let evicted):
            handleEviction(evicted)
        case .sessionError(let error):
            handleError(error)
        }
    }
    .store(in: &cancellables)
```

---

## Usage Patterns

### Pattern 1: Custom Radio Station Player

```swift
class RadioPlayer {
    private let sonosManager = SonosManager.shared
    private var currentSession: PlaybackSession?
    private var cancellables = Set<AnyCancellable>()

    func playStation(groupId: String, streamUrl: String, stationInfo: StationInfo) async {
        do {
            // Create session
            let session = try await sonosManager.createPlaybackSession(
                groupId: groupId,
                appId: "com.yourcompany.radio",
                appContext: "user-\(userId)",
                customData: stationInfo.toJSON()
            )

            currentSession = session
            setupEventListeners(sessionId: session.sessionId)

            // Load and play stream
            try await sonosManager.loadStreamUrl(
                groupId: groupId,
                sessionId: session.sessionId,
                streamUrl: streamUrl,
                itemId: stationInfo.id,
                playOnCompletion: true,
                stationMetadata: [
                    "name": stationInfo.name,
                    "logo": stationInfo.logoUrl
                ]
            )

            // Subscribe to session events
            try await sonosManager.subscribeToPlaybackSession(sessionId: session.sessionId)

        } catch {
            print("Failed to start radio: \(error)")
        }
    }

    private func setupEventListeners(sessionId: String) {
        sonosManager.subscriptionCoordinator.playbackSessionPublisher
            .filter { $0.sessionId == sessionId }
            .sink { [weak self] (_, event) in
                self?.handleSessionEvent(event)
            }
            .store(in: &cancellables)
    }

    private func handleSessionEvent(_ event: PlaybackSessionEvent) {
        switch event {
        case .sessionEvicted:
            // Another app took control - update UI
            NotificationCenter.default.post(name: .sessionTakenOver, object: nil)

        case .sessionError(let error):
            // Handle session error
            print("Session error: \(error.errorCode)")
        }
    }
}
```

### Pattern 2: Cloud Queue Music Player

```swift
class CloudQueuePlayer {
    private let sonosManager = SonosManager.shared
    private var currentSession: PlaybackSession?

    func playPlaylist(groupId: String, playlistId: String) async {
        do {
            // Create session with playlist identifier in customData
            let session = try await sonosManager.createPlaybackSession(
                groupId: groupId,
                appId: "com.yourcompany.music",
                appContext: "user-\(userId)",
                customData: "{\"playlistId\": \"\(playlistId)\"}"
            )

            currentSession = session

            // Load cloud queue
            try await sonosManager.loadCloudQueue(
                groupId: groupId,
                sessionId: session.sessionId,
                queueBaseUrl: "https://api.yourservice.com/queue/\(playlistId)",
                httpAuthorization: "Bearer \(accessToken)",
                playOnCompletion: true
            )

            print("Playlist loaded and playing")

        } catch {
            print("Failed to load playlist: \(error)")
        }
    }

    func refreshQueue(groupId: String) async {
        guard let session = currentSession else { return }

        do {
            try await sonosManager.refreshCloudQueue(
                groupId: groupId,
                sessionId: session.sessionId
            )
            print("Queue refreshed")
        } catch {
            print("Failed to refresh: \(error)")
        }
    }

    func skipToTrack(groupId: String, trackId: String) async {
        guard let session = currentSession else { return }

        do {
            try await sonosManager.sessionSkipToItem(
                groupId: groupId,
                sessionId: session.sessionId,
                itemId: trackId,
                playOnCompletion: true
            )
        } catch {
            print("Failed to skip: \(error)")
        }
    }
}
```

### Pattern 3: Session Handoff Between Devices

```swift
class MultiDevicePlayer {
    private let sonosManager = SonosManager.shared

    func continueOnAnotherDevice(groupId: String) async {
        do {
            // Try to join existing session
            let session = try await sonosManager.joinPlaybackSession(
                groupId: groupId,
                appId: "com.yourcompany.music",
                appContext: "user-\(userId)"
            )

            if session.sessionCreated == false {
                // Successfully joined existing session
                print("Joined existing session")

                // Get custom data from session
                if let customData = session.customData {
                    let playlist = try JSONDecoder().decode(
                        PlaylistInfo.self,
                        from: customData.data(using: .utf8)!
                    )
                    loadPlaylistUI(playlist)
                }
            } else {
                // No existing session, created new one
                print("No session to join, created new one")
            }

        } catch {
            print("Failed to join session: \(error)")
        }
    }
}
```

---

## Best Practices

### 1. appId and appContext Strategy

**appId**: Use reverse DNS notation for your app
```swift
let appId = "com.yourcompany.yourapp"
```

**appContext**: Use for multi-instance control
```swift
// Same user across devices - can share sessions
let appContext = "user-\(userAccountId)"

// Different users or instances - separate sessions
let appContext = "user-\(userAccountId)-device-\(deviceId)"
```

### 2. Custom Data Usage

Store useful state information (max 1023 bytes):
```swift
struct SessionData: Codable {
    let playlistId: String
    let startTime: Date
    let source: String
}

let data = try JSONEncoder().encode(sessionData)
let customData = String(data: data, encoding: .utf8)
```

### 3. Session Eviction Handling

Always handle session eviction gracefully:
```swift
case .sessionEvicted(let event):
    // Update UI to show session is no longer active
    updateUI(isSessionActive: false)

    // Optionally try to create a new session
    // or let user know another app took control
    showAlert("Another device is now controlling playback")
```

### 4. Error Handling

Handle common session errors:
```swift
case .sessionError(let error):
    switch error.errorCode {
    case "ERROR_INVALID_SESSION":
        // Session expired - create new one
        recreateSession()

    case "ERROR_QUEUE_UNAVAILABLE":
        // Cloud queue service down
        showOfflineMode()

    case "ERROR_STREAM_UNAVAILABLE":
        // Stream URL not accessible
        tryAlternateStream()

    default:
        showError(error.reason ?? "Unknown error")
    }
```

### 5. Subscription Management

Subscribe to events after creating a session:
```swift
// 1. Create session
let session = try await createPlaybackSession(...)

// 2. Setup event listeners
setupEventHandlers(sessionId: session.sessionId)

// 3. Subscribe to WebSocket events
try await subscribeToPlaybackSession(sessionId: session.sessionId)

// 4. Load content
try await loadStreamUrl(...)
```

---

## Supported Content Types

### Streaming URLs

The `loadStreamUrl` endpoint supports:
- **MP3** streams
- **AAC** streams
- **HLS** (HTTP Live Streaming)
- **Icecast** streams

Example:
```swift
try await sonosManager.loadStreamUrl(
    groupId: groupId,
    sessionId: sessionId,
    streamUrl: "https://stream.example.com/radio.mp3",
    playOnCompletion: true
)
```

### Cloud Queues

Cloud queues require:
- A **base URL** pointing to your queue service
- Implementation of Sonos **Cloud Queue API** endpoints
- Proper **authentication** if required

Example:
```swift
try await sonosManager.loadCloudQueue(
    groupId: groupId,
    sessionId: sessionId,
    queueBaseUrl: "https://api.example.com/queue/abc123",
    httpAuthorization: "Bearer your-token-here",
    playOnCompletion: true
)
```

---

## Complete Example: Radio App

```swift
import SwiftUI
import Combine
import SonosSDK

class RadioPlayerViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var currentStation: Station?
    @Published var sessionActive = true
    @Published var errorMessage: String?

    private let sonosManager = SonosManager.shared
    private var currentSession: PlaybackSession?
    private var cancellables = Set<AnyCancellable>()
    private let groupId: String

    init(groupId: String) {
        self.groupId = groupId
        setupEventListeners()
    }

    func playStation(_ station: Station) async {
        do {
            // Create session
            let session = try await sonosManager.createPlaybackSession(
                groupId: groupId,
                appId: "com.example.radioapp",
                appContext: "user-\(userId)",
                customData: station.toJSON()
            )

            currentSession = session

            // Load stream
            try await sonosManager.loadStreamUrl(
                groupId: groupId,
                sessionId: session.sessionId,
                streamUrl: station.streamUrl,
                itemId: station.id,
                playOnCompletion: true,
                stationMetadata: [
                    "name": station.name,
                    "logo": station.logoUrl,
                    "genre": station.genre
                ]
            )

            // Subscribe to events
            try await sonosManager.subscribeToPlaybackSession(sessionId: session.sessionId)

            await MainActor.run {
                self.currentStation = station
                self.isPlaying = true
                self.sessionActive = true
            }

        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to play station: \(error.localizedDescription)"
            }
        }
    }

    func stopPlayback() async {
        guard let session = currentSession else { return }

        do {
            try await sonosManager.suspendPlaybackSession(sessionId: session.sessionId)

            await MainActor.run {
                self.isPlaying = false
            }
        } catch {
            print("Failed to stop: \(error)")
        }
    }

    private func setupEventListeners() {
        sonosManager.subscriptionCoordinator.playbackSessionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (sessionId, event) in
                guard sessionId == self?.currentSession?.sessionId else { return }
                self?.handleSessionEvent(event)
            }
            .store(in: &cancellables)
    }

    private func handleSessionEvent(_ event: PlaybackSessionEvent) {
        switch event {
        case .sessionEvicted(let evicted):
            sessionActive = false
            errorMessage = "Another app took control: \(evicted.reason ?? "Unknown")"

        case .sessionError(let error):
            errorMessage = "Session error: \(error.errorCode)"
        }
    }
}

struct RadioPlayerView: View {
    @StateObject private var viewModel: RadioPlayerViewModel
    let stations: [Station]

    var body: some View {
        VStack {
            if let station = viewModel.currentStation {
                StationInfoView(station: station)

                HStack {
                    Button(viewModel.isPlaying ? "Stop" : "Play") {
                        Task {
                            if viewModel.isPlaying {
                                await viewModel.stopPlayback()
                            } else {
                                await viewModel.playStation(station)
                            }
                        }
                    }
                }

                if !viewModel.sessionActive {
                    Text("Session inactive - another app is controlling playback")
                        .foregroundColor(.orange)
                }
            }

            List(stations) { station in
                Button(station.name) {
                    Task {
                        await viewModel.playStation(station)
                    }
                }
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
```

---

## Troubleshooting

### Session Creation Fails

**Problem**: `createSession` returns an error

**Solutions**:
1. Verify `appId` and `appContext` are valid strings
2. Check `accountId` matches a configured music service account
3. Ensure `customData` is less than 1023 bytes

### Stream Won't Load

**Problem**: `loadStreamUrl` fails or stream doesn't play

**Solutions**:
1. Verify stream URL is accessible and returns valid audio
2. Check stream format is supported (MP3, AAC, HLS)
3. Ensure session was created successfully first
4. Try without `stationMetadata` to isolate issue

### Session Gets Evicted

**Problem**: Frequent `sessionEvicted` events

**Solutions**:
1. Check if multiple app instances are using the same `appContext`
2. Verify another app isn't creating sessions on the same group
3. Use unique `appContext` per device if needed

### Events Not Received

**Problem**: No WebSocket events arriving

**Solutions**:
1. Ensure WebSocket is started: `sonosManager.startWebSocket(for: player)`
2. Verify subscription: `try await subscribeToPlaybackSession(sessionId:)`
3. Check publisher subscription is active

---

## Summary

✅ **Complete API Coverage** - All 11 playbackSession endpoints implemented
✅ **Full Parameter Support** - Including itemId and stationMetadata for streams
✅ **Enhanced Response Parsing** - sessionState and sessionCreated fields
✅ **Real-time Events** - Session eviction and error notifications
✅ **Modern APIs** - Both async/await and callback-based methods
✅ **Type-Safe Models** - Complete Swift structs for all operations
✅ **WebSocket Integration** - Automatic event routing and publishing

The playbackSession API is production-ready for building custom cloud-based playback experiences on Sonos! 🎉
