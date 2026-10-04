//
//  DemoSonosCatalog.swift
//  SonosDemo
//
//  Made-up music for the demo household, so screenshots and App Review
//  never show real artists or brands.
//

import Foundation
import SonosSDK

extension DemoSonosBackend {

    static func artwork(_ seed: String) -> String {
        "https://picsum.photos/seed/sonos-demo-\(seed)/600/600"
    }

    static let morningMix = Content(
        name: "Morning Mix", serviceId: SonosServiceId.spotify, serviceName: "Spotify",
        objectId: "spotify:playlist:demo-morning", accountId: "sn_5",
        tracks: [
            Track(title: "Golden Hour", artist: "The Lanterns", album: "Open Windows", durationMillis: 214_000, imageUrl: artwork("golden")),
            Track(title: "Paper Boats", artist: "Mira Vale", album: "Harbour Lights", durationMillis: 187_000, imageUrl: artwork("boats")),
            Track(title: "Slow Sunday", artist: "Quiet Rooms", album: "Slow Sunday", durationMillis: 243_000, imageUrl: artwork("sunday")),
        ]
    )

    static let coffeehouseRadio = Content(
        name: "Coffeehouse Radio", serviceId: "303", serviceName: "Sonos Radio",
        objectId: "radio:demo-coffeehouse", accountId: "sn_1",
        tracks: [Track(title: "Coffeehouse Radio", artist: "Live", album: "", durationMillis: 0, imageUrl: artwork("coffee"))]
    )

    static let moonbeamAdventures = Content(
        name: "Moonbeam Adventures, Episode 1", serviceId: SonosServiceId.appleMusic, serviceName: "Apple Music",
        objectId: "album:demo-moonbeam-1", accountId: "sn_2",
        tracks: (1...4).map {
            Track(title: "Chapter \($0)", artist: "Moonbeam Adventures", album: "Episode 1: The Hidden Lighthouse",
                  durationMillis: 900_000, imageUrl: artwork("moonbeam1"))
        }
    )

    static let sleepyTimeSongs = Content(
        name: "Sleepy Time Songs", serviceId: SonosServiceId.appleMusic, serviceName: "Apple Music",
        objectId: "playlist:demo-sleepy", accountId: "sn_2",
        tracks: [
            Track(title: "Counting Stars Softly", artist: "Nora Field", album: "Night Lights", durationMillis: 198_000, imageUrl: artwork("stars")),
            Track(title: "The Sleepy Owl", artist: "Little Lullabies", album: "Little Lullabies", durationMillis: 156_000, imageUrl: artwork("owl")),
        ]
    )

    static var defaultFavorites: [(favorite: Favorite, content: Content)] {
        [morningMix, coffeehouseRadio, moonbeamAdventures, sleepyTimeSongs].enumerated().compactMap { index, content in
            let json: [String: Any] = [
                "id": "\(index + 1)",
                "name": content.name,
                "description": content.serviceName,
                "imageUrl": content.tracks.first?.imageUrl ?? "",
                "service": ["id": content.serviceId, "name": content.serviceName],
            ]
            guard let favorite = try? decode(Favorite.self, json) else { return nil }
            return (favorite, content)
        }
    }

    /// Items `loadContent` knows by `objectId`, e.g. from a demo search.
    static var defaultCatalog: [String: (name: String, tracks: [Track])] {
        var catalog: [String: (name: String, tracks: [Track])] = [:]
        for content in [morningMix, moonbeamAdventures, sleepyTimeSongs] {
            catalog[content.objectId] = (content.name, content.tracks)
        }
        catalog["album:demo-moonbeam-2"] = (
            "Moonbeam Adventures, Episode 2",
            (1...3).map {
                Track(title: "Chapter \($0)", artist: "Moonbeam Adventures", album: "Episode 2: The Secret Garden",
                      durationMillis: 840_000, imageUrl: artwork("moonbeam2"))
            }
        )
        catalog["spotify:album:demo-dino-songs"] = (
            "Dino Songs",
            [
                Track(title: "Stomp Stomp Roar", artist: "The Tiny Rexes", album: "Dino Songs", durationMillis: 142_000, imageUrl: artwork("dino")),
                Track(title: "Long Neck Lullaby", artist: "The Tiny Rexes", album: "Dino Songs", durationMillis: 171_000, imageUrl: artwork("dino")),
            ]
        )
        return catalog
    }
}
