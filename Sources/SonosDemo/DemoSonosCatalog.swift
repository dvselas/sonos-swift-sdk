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

    /// Kid-friendly covers by name, drawn once (see `DemoArtwork`).
    private static let covers: [String: String] = {
        let designs: [String: (emoji: String, top: UInt32, bottom: UInt32)] = [
            "golden": ("🌻", 0xFFE29A, 0xFFA94D),
            "boats": ("⛵️", 0x9ADCFF, 0x4A90E2),
            "sunday": ("🥞", 0xFFD3B6, 0xFF8C94),
            "radio": ("📻", 0xD7B899, 0x8D6E63),
            "moonbeam1": ("🌙", 0x7F6FF0, 0x2D1E6B),
            "moonbeam2": ("🌷", 0xA8E6CF, 0x3BA57A),
            "moonbeam3": ("🏔️", 0xC9E4FF, 0x5B7DB1),
            "stars": ("⭐️", 0x4A5BC0, 0x141B4D),
            "owl": ("🦉", 0x9C8CD3, 0x3E2F6B),
            "dino": ("🦕", 0xB8E994, 0x38A169),
            "car": ("🚗", 0xFFB3C7, 0xE84A7F),
            "rocket": ("🚀", 0x89F7FE, 0x66A6FF),
            "teddy": ("🧸", 0xF6D365, 0xFDA085),
        ]
        return designs.compactMapValues { DemoArtwork.url($0.emoji, top: $0.top, bottom: $0.bottom) }
    }()

    static func artwork(_ name: String) -> String? {
        covers[name]
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
        tracks: [Track(title: "Coffeehouse Radio", artist: "Live", album: "", durationMillis: 0, imageUrl: artwork("radio"))]
    )

    static let moonbeamAdventures = Content(
        name: "Moonbeam Adventures, Episode 1", serviceId: SonosServiceId.appleMusic, serviceName: "Apple Music",
        objectId: "album:demo-moonbeam-1", accountId: "sn_2",
        tracks: (1...4).map {
            Track(title: "Chapter \($0)", artist: "Moonbeam Adventures", album: "Episode 1: The Hidden Lighthouse",
                  durationMillis: 900_000, imageUrl: artwork("moonbeam1"))
        }
    )

    /// Every episode in one playlist, newest first, like the labels' own
    /// playlists of an audio drama series: each episode is an album that
    /// starts with the theme song.
    static let moonbeamAllEpisodes: Content = {
        let episodes = [(3, "The Snowy Mountain", "moonbeam3", 3), (2, "The Secret Garden", "moonbeam2", 3),
                        (1, "The Hidden Lighthouse", "moonbeam1", 4)]
        let tracks = episodes.flatMap { number, title, cover, chapters in
            let album = "Episode \(number): \(title)"
            return [Track(title: "Moonbeam Theme", artist: "Moonbeam Adventures", album: album,
                          durationMillis: 62_000, imageUrl: artwork(cover))]
                + (1...chapters).map {
                    Track(title: "Chapter \($0): \(title)", artist: "Moonbeam Adventures", album: album,
                          durationMillis: 300_000, imageUrl: artwork(cover))
                }
        }
        return Content(name: "Moonbeam Adventures – All Episodes", serviceId: SonosServiceId.spotify, serviceName: "Spotify",
                       objectId: "spotify:playlist:demo-moonbeam-all", accountId: "sn_5", tracks: tracks)
    }()

    static let sleepyTimeSongs = Content(
        name: "Sleepy Time Songs", serviceId: SonosServiceId.appleMusic, serviceName: "Apple Music",
        objectId: "playlist:demo-sleepy", accountId: "sn_2",
        tracks: [
            Track(title: "Counting Stars Softly", artist: "Nora Field", album: "Night Lights", durationMillis: 198_000, imageUrl: artwork("stars")),
            Track(title: "The Sleepy Owl", artist: "Little Lullabies", album: "Little Lullabies", durationMillis: 156_000, imageUrl: artwork("owl")),
        ]
    )

    static let dinoSongs = [
        Track(title: "Stomp Stomp Roar", artist: "The Tiny Rexes", album: "Dino Songs", durationMillis: 142_000, imageUrl: artwork("dino")),
        Track(title: "Long Neck Lullaby", artist: "The Tiny Rexes", album: "Dino Songs", durationMillis: 171_000, imageUrl: artwork("dino")),
    ]

    // Sonos playlists mix services; like real ones they have no image of their own.

    static let roadTripPlaylist = Content(
        name: "Road Trip Sing-Along", serviceId: "", serviceName: "Sonos",
        objectId: "SQ:1", accountId: "",
        tracks: [
            Track(title: "Are We There Yet?", artist: "The Backseat Band", album: "Road Trip", durationMillis: 158_000, imageUrl: artwork("car")),
            Track(title: "Rocket to the Moon", artist: "Little Astronauts", album: "Countdown", durationMillis: 176_000, imageUrl: artwork("rocket")),
            dinoSongs[0],
        ]
    )

    static let bedtimeStoriesPlaylist = Content(
        name: "Bedtime Stories", serviceId: "", serviceName: "Sonos",
        objectId: "SQ:2", accountId: "",
        tracks: [
            Track(title: "Teddy's Big Dream", artist: "Story Time Friends", album: "Teddy Tales", durationMillis: 612_000, imageUrl: artwork("teddy")),
            sleepyTimeSongs.tracks[1],
            moonbeamAdventures.tracks[0],
        ]
    )

    static var defaultFavorites: [(favorite: Favorite, content: Content)] {
        [morningMix, coffeehouseRadio, moonbeamAdventures, sleepyTimeSongs, moonbeamAllEpisodes].enumerated().compactMap { index, content in
            let json: [String: Any] = [
                "id": "\(index + 1)",
                "name": content.name,
                "description": content.serviceName,
                "imageUrl": content.tracks.first?.imageUrl ?? "",
                "service": ["id": content.serviceId, "name": content.serviceName],
                "resource": ["type": content.tracks.first?.durationMillis == 0 ? FavoriteResource.stream : "PLAYLIST"],
            ]
            guard let favorite = try? decode(Favorite.self, json) else { return nil }
            return (favorite, content)
        }
    }

    static var defaultPlaylists: [(playlist: Playlist, content: Content)] {
        [roadTripPlaylist, bedtimeStoriesPlaylist].compactMap { content in
            let json: [String: Any] = [
                "id": content.objectId.replacingOccurrences(of: "SQ:", with: ""),
                "name": content.name,
                "type": "playlist",
                "trackCount": content.tracks.count,
            ]
            guard let playlist = try? decode(Playlist.self, json) else { return nil }
            return (playlist, content)
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
        catalog["spotify:album:demo-dino-songs"] = ("Dino Songs", dinoSongs)
        return catalog
    }
}
