# Live updates over the local network

Sonos players expose the Control API on the local network at
`wss://<player-ip>:1443/websocket/api`. It uses the same namespaces, commands and
payloads as the cloud API. Because players push state changes over this socket,
your app gets updates in real time without a public callback server.

## Using it

```swift
let (groups, players) = try await manager.getGroups(householdId: householdId, useCache: false)
let live = await manager.startLiveUpdates(householdId: householdId, groups: groups, players: players)

for await event in live.events {
    switch event {
    case .topology(let groups, let players): …          // regrouping, players added/removed
    case .playbackStatus(let groupId, let status): …    // play/pause, position, play modes
    case .metadataStatus(let groupId, let metadata): …  // track, container, artwork
    case .groupVolume(let groupId, let volume): …
    case .playerVolume(let playerId, let volume): …
    case .playbackError(let groupId, let code, let reason): …
    case .connection(let playerId, let state): …        // per-player socket health
    }
}
```

- `events` has a single consumer. The stream ends after `stopLiveUpdates()` or
  `logout()`.
- While live updates run, calls through `SonosManager` (playback, metadata,
  group/player volume, `getGroups`, `createGroup`, `modifyGroupMembers`) go over
  the LAN. A call falls back to the cloud only if it could not be sent locally,
  so non-idempotent commands never run twice. Favorites, playlists, sessions and
  settings always use the cloud.
- Call `live.suspend()` before system sleep and `live.resume()` after wake.
  Network-path changes are handled automatically.

## How it works

- There is one socket per player. The handshake sends `X-Sonos-Api-Key` (your
  integration key) and `Sec-WebSocket-Protocol: v1.api.smartspeaker.audio`.
  Players use certificates from Sonos' private CA, which is trusted only for
  hosts in the household's player list, on port 1443.
- Every message is a `[header, body]` JSON array. Commands carry `cmdId`, and
  replies echo it together with `success`. Events have a `type` and no `cmdId`.
- Routing rules:
  - Group namespaces (`playback`, `playbackMetadata`, `groupVolume`) work only
    on the coordinator's socket.
  - `playerVolume` works only on the player's own socket.
  - `groups` works on any socket.
- When the topology changes, the client moves subscriptions to the right
  socket. After every reconnect it subscribes again and reads a fresh snapshot,
  because subscribing doesn't replay the current state.
- Footprint: all sockets share one `URLSession`. Each socket sends a keepalive
  ping every 45 s. Reconnects back off from 1 s up to 60 s, with jitter.
- Tuning: `SonosLiveConfiguration` (timeouts, ping interval, backoff, logger,
  frame tracing).
