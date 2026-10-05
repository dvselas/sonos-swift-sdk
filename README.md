Sonos Swift SDK
========

[![Swift](https://github.com/vselas/sonos-swift-sdk/actions/workflows/swift.yml/badge.svg)](https://github.com/vselas/sonos-swift-sdk/actions/workflows/swift.yml)
[![SwiftLint](https://github.com/vselas/sonos-swift-sdk/actions/workflows/SwiftLint.yml/badge.svg)](https://github.com/vselas/sonos-swift-sdk/actions/workflows/SwiftLint.yml)
[![License](https://img.shields.io/cocoapods/l/Swinject.svg?style=flat)](http://cocoapods.org/pods/Swinject)
[![Platforms](https://img.shields.io/badge/platform-iOS%20%7C%20macOS-lightgrey.svg)](http://cocoapods.org/pods/Swinject)
[![Swift Version](https://img.shields.io/badge/Swift-5.0-F16D39.svg?style=flat)](https://developer.apple.com/swift)
[![Twitter](https://img.shields.io/badge/twitter-@jimmy_jammed-blue.svg?style=flat)](http://twitter.com/jimmy_jammed)

Sonos Swift SDK is a plug-and-play library that allows you to quickly integrate your iOS and macOS apps with the Sonos API.

## How To Get Started
* [ ] Create a Sonos Developer account [here](https://developer.sonos.com)
* [ ] Setup a new integration [here](https://integration.sonos.com/integrations)
* [ ] Open the `SonosSDK.xcworkspace` in Xcode.
* [ ] Grab the **Key Name**, **Key** and **Secret** from your new Sonos app integration and update the `SwiftUIExampleApp.swift` file with your values:

```
struct SonosConfiguration {

    static let keyName = "your-sonos-key-name"
    static let key = "your-sonos-developer-key"
    static let secret = "your-sonos-developer-secret"
    static let redirectURI = "sonos-swift-sdk://authorize"
    static let callbackURL = "your-webhook-api-url"

}
```

## Real-time updates

`SonosManager.startLiveUpdates(householdId:groups:players:)` connects to the
players on the local network. It streams playback, metadata, volume and grouping
changes as they happen, and sends commands over the LAN. See
[LIVE_UPDATES.md](LIVE_UPDATES.md).

Players present a certificate from Sonos' own CA, which the system doesn't
trust. The SDK accepts it only from the household's players on the local API
port, and only if it is issued by the "Sonos Device Authentication Root CA" and
names that player (`CN=<MAC>` from `RINCON_<MAC>01400`). Sonos renews these
certificates about once a year, so their keys aren't pinned.

Apps that want the state ready to render use the `SonosLive` product:
`SonosLiveStore` keeps `@Observable` models per group and room, shows user
actions optimistically until the players confirm them, and follows sign-in, sleep
and wake (macOS) or background and foreground (iOS). It talks to Sonos through
`SonosLiveBackend`, which `SonosManager` implements.

```swift
let store = SonosLiveStore(backend: sonosManager)
store.activate()   // connects once signed in
```

The store also loads the household's favorites and Sonos playlists
(`loadFavorites()`, `loadPlaylists()`) and plays them on a group
(`playFavorite(_:on:)`, `playPlaylist(_:on:)`; a playlist replaces the queue).

The `SonosDemo` product has `DemoSonosBackend`, a simulated household with made-up
music for demo mode, UI tests and previews. Its covers are drawn on the device
(friendly for children, no network), and `topologyDelay` makes grouping changes
arrive late, like on real players.

## Playing music service items

`loadContent(groupId:content:play:)` plays a music service item by id with one of
the household's accounts, e.g. a Spotify track on a child's account:

```swift
let track = SonosContent(kind: .track, serviceId: SonosServiceId.spotify,
                         objectId: "spotify:track:4uLU6hMCjMI75M1A2tKUQC", accountId: "sn_6")
try await sonosManager.loadContent(groupId: groupId, content: track)
```

Only the players answer it (over the local socket while live updates run). Apple
Music items use `serviceId` 204 and ids like `song:<id>` or `album:<id>`. An
unknown `accountId` falls back to the service's default account. `SonosLiveStore`
adds `play(_:onPlayer:)` (the room leaves its group first, the other rooms keep
the music), `isolate(_:)`, and `discoverAccounts(probe:onPlayer:)`, which finds a
service's accounts without playing anything.

## Token storage

The OAuth token is kept in the Keychain (`KeychainTokenStore`, service
`com.sonossdk.token`). It stays on the device and is readable after the first
unlock, so background refreshes work on iOS. A token that an earlier version
stored in `UserDefaults` moves to the Keychain on first launch. To keep it
elsewhere, pass your own `TokenStoring` to `SonosManager(...tokenStore:)` or
`TokenManager(...tokenStore:)`. Tests can use `InMemoryTokenStore`.

## Installation
Sonos Swift SDK supports the following installation methods:

### Swift Package Manager

in `Package.swift` add the following:

```swift
dependencies: [
    .package(url: "https://github.com/vselas/sonos-swift-sdk", from: "0.5.0")
],
targets: [
    .target(
        name: "MyProject",
        dependencies: [
            .product(name: "SonosSDK", package: "sonos-swift-sdk"),
            .product(name: "SonosLive", package: "sonos-swift-sdk"),   // optional
        ]
    )
    ...
]
```

###### Note: Sonos Swift SDK requires the following Swift Package dependency:

[BetterSafariView](https://github.com/stleamist/BetterSafariView)

## Requirements

| Sonos Swift SDK Version | Sonos Swift Networking Version | Minimum iOS Target  | Minimum macOS Target  | Minimum watchOS Target  | Minimum tvOS Target  |                                   Notes |
|:--------------------:|:--------------------:|:---------------------------:|:----------------------------:|:----------------------------:|:----------------------------:|:-------------------------------------------------------------------------:|
| 0.4+ | – | iOS 17 | macOS 14 | x | x | `SonosLive` needs Observation. |
| 1.x | v1 | iOS 14 | x | x | x | Xcode 12+ is required. |

## Supported Sonos APIs

Here is a list of the supported Sonos API's in Sonos Swift SDK:

* [x] [Authorization](https://developer.sonos.com/reference/authorization-api/)
	* [x] [Create Authorization Code](https://developer.sonos.com/reference/authorization-api/create-authorization-code/) 
	* [x] [Create Token](https://developer.sonos.com/reference/authorization-api/create-token/) 
	* [x] [Refresh Token](https://developer.sonos.com/reference/authorization-api/refresh-token/) 
* [ ] [Control API](https://developer.sonos.com/reference/control-api/)
	* [ ] [Audio Clip](https://developer.sonos.com/reference/control-api/audioclip/)
	* [ ] [Favorites](https://developer.sonos.com/reference/control-api/favorites/)
	* [x] [Groups](https://developer.sonos.com/reference/control-api/groups/)
	* [ ] [Group Volume](https://developer.sonos.com/reference/control-api/group-volume/)
	* [ ] [Home Theater](https://developer.sonos.com/reference/control-api/hometheater/)
	* [x] [Households](https://developer.sonos.com/reference/control-api/households/)
	* [ ] [Music Service Accounts](https://developer.sonos.com/reference/control-api/musicserviceaccounts/)
	* [ ] [Playback](https://developer.sonos.com/reference/control-api/playback/)
	* [ ] [Playback Metadata](https://developer.sonos.com/reference/control-api/playback-metadata/)
	* [ ] [Playback Session](https://developer.sonos.com/reference/control-api/playbacksession/)
	* [x] [Player Volume](https://developer.sonos.com/reference/control-api/playervolume/)
	* [ ] [Playlists](https://developer.sonos.com/reference/control-api/playlists/)
	* [ ] [Settings](https://developer.sonos.com/reference/control-api/settings/)
* [ ] [Cloud Queue API](https://developer.sonos.com/reference/cloud-queue-api/)
* [ ] [Sonos Music API](https://developer.sonos.com/reference/sonos-music-api/)

## Unit Tests

Sonos Swift SDK includes a suite of unit tests within the Tests subdirectory.

## Contribution Guide

A guide to [submit issues](https://github.com/vselas/sonos-swift-sdk/issues), to ask general questions, or to [open pull requests](https://github.com/vselas/sonos-swift-sdk/pulls) are [here](CONTRIBUTING.md).

## Credits

Sonos Swift SDK is an open source project and unaffiliated with Sonos Inc. It is a fork of [JimmyJammed/sonos-swift-sdk](https://github.com/JimmyJammed/sonos-swift-sdk) by James Hickman.

And most of all, thanks to Sonos Swift SDK's [growing list of contributors](https://github.com/vselas/sonos-swift-sdk/graphs/contributors).

## License

Sonos Swift SDK is released under the MIT license. See [LICENSE](LICENSE) for details.
