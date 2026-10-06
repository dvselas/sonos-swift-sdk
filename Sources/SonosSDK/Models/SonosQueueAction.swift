//
//  SonosQueueAction.swift
//  SonosSDK
//
//  Where loaded music goes in a group's queue. Favorites and Sonos playlists
//  take it as `action`, `loadContent` as `queueAction` (other field names are
//  silently ignored there, and the queue is replaced).
//
//  Tried on the players: appending while the group plays pauses it unless the
//  command also asks to play; with play the current track carries on. INSERT_NEXT
//  lands right after the current track, inside a playing album.
//

import Foundation

public enum SonosQueueAction: String, Codable, Hashable, Sendable {
    case replace = "REPLACE"
    /// After the last track.
    case append = "APPEND"
    /// Right after the current track.
    case insertNext = "INSERT_NEXT"
}
