# Metadata and Cover Image Guide

Complete guide for fetching metadata and cover images for all content types (music, radio, TV, podcasts, etc.) in the Sonos Swift SDK.

## Overview

The SDK provides comprehensive metadata support through the `PlaybackMetadata` API, which returns detailed information about currently playing content including:

- **Track Information**: Title, artist, album, duration
- **Cover Images**: Album art, station logos, service icons
- **Container Metadata**: Playlist/album info with artwork
- **Service Information**: Streaming service details (Spotify, Apple Music, etc.)
- **Real-time Updates**: WebSocket subscriptions for instant metadata changes

**Works for ALL content types**: Music streaming, radio stations, TV input, line-in, podcasts, and more!

---

## Quick Start

### 1. Fetch Current Metadata (Async/Await - Recommended)

```swift
import SonosSDK

let sonosManager = SonosManager.shared

do {
    // Fetch metadata with automatic caching
    let metadata = try await sonosManager.getGroupPlaybackMetadata(groupId: "yourGroupId", useCache: true)

    // Track Information
    let trackName = metadata.currentItem.track?.name ?? "Unknown"
    let artistName = metadata.currentItem.track?.artist?.name ?? "Unknown Artist"
    let albumName = metadata.currentItem.track?.album?.name ?? "Unknown Album"

    // Cover Image URL - Works for all content types!
    if let imageUrl = metadata.currentItem.track?.imageUrl {
        print("Cover Image: \(imageUrl)")
        await loadImage(from: imageUrl)
    }

    // Container Art (for playlists, albums, radio stations)
    if let containerName = metadata.container.name,
       let containerArt = metadata.container.imageUrl {
        print("Playing from: \(containerName)")
        print("Container Art: \(containerArt)")
    }

    // Service Information
    if let service = metadata.currentItem.track?.service {
        print("Service: \(service.name)") // "Spotify", "Apple Music", etc.
    }

} catch {
    print("Error: \(error.localizedDescription)")
}
```

### 2. Fetch Current Metadata (Callback-based)

```swift
import SonosSDK

let sonosManager = SonosManager.shared

sonosManager.getGroupMetadataStatus(groupId: "yourGroupId") { metadata in
    // Track Information
    let trackName = metadata.currentItem.track?.name ?? "Unknown"
    let artistName = metadata.currentItem.track?.artist?.name ?? "Unknown Artist"
    let albumName = metadata.currentItem.track?.album?.name ?? "Unknown Album"
    let durationMs = metadata.currentItem.track?.durationMillis ?? 0

    // Cover Image URL - Works for all content types!
    if let imageUrl = metadata.currentItem.track?.imageUrl {
        print("Cover Image: \(imageUrl)")
        // Load the image from this URL
        loadImage(from: imageUrl)
    }

    // Container Art (for playlists, albums, radio stations)
    if let containerName = metadata.container.name,
       let containerArt = metadata.container.imageUrl {
        print("Playing from: \(containerName)")
        print("Container Art: \(containerArt)")
    }

    // Service Information
    if let service = metadata.currentItem.track?.service {
        print("Service: \(service.name)") // e.g., "Spotify", "Apple Music", "TuneIn"
        if let serviceIcon = service.images?.url {
            print("Service Icon: \(serviceIcon)")
        }
    }

    // Track Type
    print("Content Type: \(metadata.currentItem.track?.type ?? "")")

} failure: { error in
    print("Error fetching metadata: \(error?.localizedDescription ?? "")")
}
```

---

## Advanced Usage

### Modern Async/Await with Caching

The SDK now supports async/await for cleaner, more maintainable code:

```swift
class MusicPlayer {
    let sonosManager = SonosManager.shared

    func updateNowPlaying(groupId: String) async {
        do {
            // Automatically uses cache if available (30s TTL)
            let metadata = try await sonosManager.getGroupPlaybackMetadata(
                groupId: groupId,
                useCache: true
            )

            await updateUI(with: metadata)

        } catch {
            print("Failed to fetch metadata: \(error)")
        }
    }

    @MainActor
    func updateUI(with metadata: PlaybackMetadata) {
        trackLabel.text = metadata.currentItem.track?.name
        artistLabel.text = metadata.currentItem.track?.artist?.name

        if let imageUrl = metadata.currentItem.track?.imageUrl {
            Task {
                let image = try await downloadImage(from: imageUrl)
                coverImageView.image = image
            }
        }
    }
}
```

**Benefits of Async/Await:**
- ✅ Cleaner error handling with try/catch
- ✅ Automatic cache management
- ✅ Better integration with SwiftUI and modern Swift
- ✅ Easier to compose with other async operations
- ✅ No callback hell or completion handler nesting

### Real-Time Metadata Updates via WebSocket

Subscribe to metadata changes to get instant updates when tracks change:

```swift
import Combine

class PlaybackViewController: UIViewController {
    private var cancellables = Set<AnyCancellable>()
    private let sonosManager = SonosManager.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMetadataSubscription()
    }

    private func setupMetadataSubscription() {
        // Subscribe to real-time metadata changes
        sonosManager.subscriptionCoordinator.metadataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (groupId, metadataEvent) in
                self?.updateUI(with: metadataEvent)
            }
            .store(in: &cancellables)
    }

    private func updateUI(with metadata: MetadataChangedEvent) {
        // Current track info
        if let currentItem = metadata.currentItem {
            trackLabel.text = currentItem.trackName
            artistLabel.text = currentItem.artistName
            albumLabel.text = currentItem.albumName

            // Load cover image
            if let imageUrlString = currentItem.imageUrl,
               let imageUrl = URL(string: imageUrlString) {
                loadCoverImage(from: imageUrl)
            }
        }

        // Next track info (for "up next" display)
        if let nextItem = metadata.nextItem {
            nextTrackLabel.text = nextItem.trackName
        }

        // Container info
        if let container = metadata.container {
            containerLabel.text = "Playing from: \(container.name ?? "")"
            if let containerImageUrl = container.imageUrl {
                loadContainerImage(from: URL(string: containerImageUrl)!)
            }
        }
    }

    private func loadCoverImage(from url: URL) {
        // Use your preferred image loading library
        // Examples: Kingfisher, SDWebImage, or URLSession
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.coverImageView.image = image
            }
        }.resume()
    }
}
```

---

## Metadata by Content Type

### Music Streaming (Spotify, Apple Music, Tidal, etc.)

```swift
// Full metadata available:
metadata.currentItem.track?.name           // "Bohemian Rhapsody"
metadata.currentItem.track?.artist?.name   // "Queen"
metadata.currentItem.track?.album?.name    // "A Night at the Opera"
metadata.currentItem.track?.imageUrl       // Album art URL
metadata.currentItem.track?.service?.name  // "Spotify"
metadata.currentItem.track?.durationMillis // Track length
```

### Radio Stations (TuneIn, iHeartRadio, etc.)

```swift
// Station and show info:
metadata.currentItem.track?.name           // "KCRW Live"
metadata.currentItem.track?.imageUrl       // Station logo
metadata.container.name                    // "Radio Station"
metadata.container.imageUrl                // Alternative station art
metadata.currentItem.track?.service?.name  // "TuneIn"
```

### TV Input / HDMI

```swift
// TV source info:
metadata.currentItem.track?.name           // "TV"
metadata.currentItem.track?.type           // "lineIn" or "tv"
metadata.currentItem.track?.imageUrl       // Generic TV icon or source logo
metadata.container.name                    // "Living Room TV"
```

### Podcasts

```swift
// Episode and show info:
metadata.currentItem.track?.name           // "Episode 142: AI Revolution"
metadata.currentItem.track?.artist?.name   // Podcast host/author
metadata.currentItem.track?.album?.name    // Podcast series name
metadata.currentItem.track?.imageUrl       // Podcast artwork
metadata.currentItem.track?.durationMillis // Episode length
```

### Playlists

```swift
// Track within playlist:
metadata.currentItem.track?.name           // Current track name
metadata.currentItem.track?.imageUrl       // Track/album art
metadata.container.name                    // "My Favorite Playlist"
metadata.container.imageUrl                // Playlist cover art
metadata.container.type                    // "playlist"
```

---

## Complete Data Structure

### PlaybackMetadata Model

```swift
public struct PlaybackMetadata {
    public var container: ContainerMetadata       // Playlist, album, or station info
    public var currentItem: Item                  // Currently playing track
    public var nextItem: Item                     // Next track in queue
}

public struct ContainerMetadata {
    public var name: String?                      // "Classic Rock Playlist"
    public var type: String?                      // "playlist", "album", "station"
    public var imageUrl: String?                  // Container artwork URL
    public var images: Images?                    // Multiple resolution images
    public var service: ServiceMetadata?          // Streaming service info
}

public struct Item {
    public var track: Track?                      // Detailed track information
    public var policies: Policies?                // Playback permissions
}

public struct Track {
    public var name: String                       // Track title
    public var type: String                       // "track", "radio", "lineIn", etc.
    public var imageUrl: String?                  // ⭐ Primary cover image URL
    public var images: Images?                    // Multiple resolution images
    public var album: Album?                      // Album information
    public var artist: Artist?                    // Artist information
    public var service: ServiceMetadata?          // Service details
    public var durationMillis: Int64              // Track duration in milliseconds
}

public struct Artist {
    public var name: String                       // Artist name
}

public struct Album {
    public var name: String                       // Album title
}

public struct ServiceMetadata {
    public var name: String                       // "Spotify", "Apple Music", "TuneIn"
    public var id: String                         // Service identifier
    public var images: Images?                    // Service logo/icon
}

public struct Images {
    public var url: String                        // Image URL
}
```

---

## Caching and Performance

The SDK includes intelligent caching with 30-second TTL:

```swift
// Check cache before fetching
if let cachedMetadata = sonosManager.stateCache.getPlaybackMetadata(for: groupId) {
    // Use cached data
    updateUI(with: cachedMetadata)
} else {
    // Fetch fresh data
    sonosManager.getGroupMetadataStatus(groupId: groupId) { metadata in
        // Will be automatically cached
        updateUI(with: metadata)
    } failure: { error in
        print("Error: \(error)")
    }
}
```

**Cache is automatically:**
- ✅ Updated when metadata changes
- ✅ Invalidated after playback control commands
- ✅ Managed with TTL expiration
- ✅ Thread-safe for concurrent access

---

## Image Loading Best Practices

### 1. Use Caching Image Libraries

```swift
// Using Kingfisher (recommended)
import Kingfisher

if let imageUrlString = metadata.currentItem.track?.imageUrl,
   let imageUrl = URL(string: imageUrlString) {
    imageView.kf.setImage(with: imageUrl, placeholder: defaultCoverImage)
}
```

```swift
// Using SDWebImage
import SDWebImage

if let imageUrlString = metadata.currentItem.track?.imageUrl,
   let imageUrl = URL(string: imageUrlString) {
    imageView.sd_setImage(with: imageUrl, placeholderImage: defaultCoverImage)
}
```

### 2. Handle Missing Images

```swift
let imageUrl = metadata.currentItem.track?.imageUrl
    ?? metadata.container.imageUrl
    ?? metadata.currentItem.track?.service?.images?.url

if let imageUrl = imageUrl, let url = URL(string: imageUrl) {
    loadImage(from: url)
} else {
    // Show default placeholder
    imageView.image = UIImage(named: "default_cover")
}
```

### 3. Preload Next Track Image

```swift
// Preload next track's artwork for smooth transitions
if let nextImageUrl = metadata.nextItem.track?.imageUrl,
   let url = URL(string: nextImageUrl) {
    ImagePrefetcher(urls: [url]).start()
}
```

---

## SwiftUI Example

Complete SwiftUI view with live metadata updates:

```swift
import SwiftUI
import Combine

struct NowPlayingView: View {
    @StateObject private var viewModel = NowPlayingViewModel()

    var body: some View {
        VStack(spacing: 20) {
            // Cover Image
            AsyncImage(url: viewModel.coverImageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "music.note")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.gray)
            }
            .frame(width: 300, height: 300)
            .cornerRadius(12)
            .shadow(radius: 10)

            // Track Info
            VStack(spacing: 8) {
                Text(viewModel.trackName)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(viewModel.artistName)
                    .font(.title3)
                    .foregroundColor(.secondary)

                Text(viewModel.albumName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Service Badge
            if let serviceName = viewModel.serviceName {
                Label(serviceName, systemImage: "music.note.list")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding()
        .onAppear {
            viewModel.startListening(groupId: "your-group-id")
        }
    }
}

class NowPlayingViewModel: ObservableObject {
    @Published var coverImageURL: URL?
    @Published var trackName: String = "Not Playing"
    @Published var artistName: String = ""
    @Published var albumName: String = ""
    @Published var serviceName: String?

    private var cancellables = Set<AnyCancellable>()
    private let sonosManager = SonosManager.shared

    func startListening(groupId: String) {
        // Subscribe to metadata changes
        sonosManager.subscriptionCoordinator.metadataPublisher
            .filter { $0.groupId == groupId }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (_, metadata) in
                self?.updateMetadata(metadata)
            }
            .store(in: &cancellables)

        // Initial fetch
        fetchMetadata(groupId: groupId)
    }

    private func fetchMetadata(groupId: String) {
        sonosManager.getGroupMetadataStatus(groupId: groupId) { [weak self] metadata in
            DispatchQueue.main.async {
                self?.updateFromPlaybackMetadata(metadata)
            }
        } failure: { error in
            print("Error: \(error?.localizedDescription ?? "")")
        }
    }

    private func updateMetadata(_ event: MetadataChangedEvent) {
        if let currentItem = event.currentItem {
            trackName = currentItem.trackName ?? "Unknown Track"
            artistName = currentItem.artistName ?? "Unknown Artist"
            albumName = currentItem.albumName ?? ""

            if let imageUrlString = currentItem.imageUrl {
                coverImageURL = URL(string: imageUrlString)
            }
        }

        if let container = event.container {
            // Use container image as fallback
            if coverImageURL == nil, let containerImageUrl = container.imageUrl {
                coverImageURL = URL(string: containerImageUrl)
            }
        }
    }

    private func updateFromPlaybackMetadata(_ metadata: PlaybackMetadata) {
        trackName = metadata.currentItem.track?.name ?? "Unknown Track"
        artistName = metadata.currentItem.track?.artist?.name ?? "Unknown Artist"
        albumName = metadata.currentItem.track?.album?.name ?? ""
        serviceName = metadata.currentItem.track?.service?.name

        if let imageUrlString = metadata.currentItem.track?.imageUrl {
            coverImageURL = URL(string: imageUrlString)
        } else if let containerImageUrl = metadata.container.imageUrl {
            coverImageURL = URL(string: containerImageUrl)
        }
    }
}
```

---

## Subscription Management

### Subscribe to Metadata Changes

```swift
// Enable WebSocket subscription for real-time updates
sonosManager.subscribeToPlaybackSession(groupId: groupId) {
    print("Subscribed to metadata updates")
} failure: { error in
    print("Subscription error: \(error)")
}

// Start WebSocket for the player
if let player = players.first {
    sonosManager.startWebSocket(for: player)
}
```

### Unsubscribe

```swift
sonosManager.unsubscribeFromPlaybackSession(groupId: groupId) {
    print("Unsubscribed")
} failure: { error in
    print("Error: \(error)")
}

// Stop WebSocket
sonosManager.stopWebSocket(for: playerId)
```

---

## API Endpoints Used

The SDK uses these Sonos Control API endpoints:

| Endpoint | Purpose |
|----------|---------|
| `GET /groups/{groupId}/playbackMetadata` | Fetch current metadata |
| `POST /groups/{groupId}/playbackMetadata/subscription` | Subscribe to updates |
| `DELETE /groups/{groupId}/playbackMetadata/subscription` | Unsubscribe |
| WebSocket Events | Real-time metadata change notifications |

---

## Troubleshooting

### No Cover Image

**Problem:** `imageUrl` is `nil` or empty

**Solutions:**
1. Check `container.imageUrl` as fallback
2. Check `service.images.url` for service logo
3. Use placeholder image
4. Some content (line-in, TV) may not have artwork

```swift
let imageUrl = metadata.currentItem.track?.imageUrl
    ?? metadata.container.imageUrl
    ?? metadata.currentItem.track?.service?.images?.url
    ?? "https://example.com/default-cover.png"
```

### Metadata Not Updating

**Problem:** Metadata changes not reflected in UI

**Solutions:**
1. Ensure WebSocket is started: `sonosManager.startWebSocket(for: player)`
2. Check subscription: Call `subscribeToPlaybackSession()`
3. Verify publisher subscription is active
4. Check cache TTL hasn't expired

### Missing Artist/Album Info

**Problem:** Artist or album is `nil` for radio/TV

**Solution:** This is expected behavior:
- Radio stations: Use `track.name` for station name
- TV input: Limited metadata available
- Use `container.name` as fallback

---

## Performance Tips

1. **Use Caching**: Check cache before fetching
2. **Preload Images**: Fetch next track's image in advance
3. **Efficient Updates**: Only update UI when metadata actually changes
4. **Memory Management**: Dispose of WebSocket subscriptions when done
5. **Background Loading**: Load images off main thread

---

## Summary

✅ **Complete metadata support** for all content types
✅ **Cover images** via `imageUrl` fields
✅ **Real-time updates** through WebSocket subscriptions
✅ **Intelligent caching** with 30-second TTL
✅ **Type-safe models** for all metadata structures
✅ **SwiftUI and UIKit** compatible

The SDK provides everything you need to display rich, up-to-date metadata and cover images for any content playing on Sonos!
