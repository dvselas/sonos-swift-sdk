//
//  PlaylistService.swift
//  SonosSDK
//
//  Created on 2025-01-22.
//

import Foundation
import SwiftyJSON
import SonosNetworking

struct PlaylistService {

    func getPlaylists(authenticationToken: AuthenticationToken, householdId: String, success: @escaping ([Playlist]) -> (), failure: @escaping (Error?) -> ()) {
        PlaylistsGetPlaylistsNetwork(accessToken: authenticationToken.access_token, householdId: householdId) { data in
            guard let data = data else {
                let error = NSError.errorWithMessage(message: "No data received from PlaylistsGetPlaylistsNetwork.")
                failure(error)
                return
            }

            let playlists = self.decodePlaylists(data)
            success(playlists)
        } failure: { error in
            failure(error)
        }.performRequest()
    }

    func getPlaylist(authenticationToken: AuthenticationToken, householdId: String, playlistId: String, success: @escaping (Playlist) -> (), failure: @escaping (Error?) -> ()) {
        PlaylistsGetPlaylistNetwork(accessToken: authenticationToken.access_token, householdId: householdId, playlistId: playlistId) { data in
            guard let data = data,
                  let playlist = Playlist(data) else {
                let error = NSError.errorWithMessage(message: "Could not create Playlist object.")
                failure(error)
                return
            }
            success(playlist)
        } failure: { error in
            failure(error)
        }.performRequest()
    }

    func loadPlaylist(authenticationToken: AuthenticationToken, groupId: String, action: String? = nil, playlistId: String, playOnCompletion: Bool? = nil, playModes: [String]? = nil, success: @escaping () -> (), failure: @escaping (Error?) -> ()) {
        PlaylistsLoadPlaylistNetwork(accessToken: authenticationToken.access_token, groupId: groupId, action: action, playlistId: playlistId, playOnCompletion: playOnCompletion, playModes: playModes) { data in
            success()
        } failure: { error in
            failure(error)
        }.performRequest()
    }

    func subscribe(authenticationToken: AuthenticationToken, householdId: String, success: @escaping () -> (), failure: @escaping (Error?) -> ()) {
        PlaylistsSubscribeNetwork(accessToken: authenticationToken.access_token, householdId: householdId) { data in
            success()
        } failure: { error in
            failure(error)
        }.performRequest()
    }

    func unsubscribe(authenticationToken: AuthenticationToken, householdId: String, success: @escaping () -> (), failure: @escaping (Error?) -> ()) {
        PlaylistsUnsubscribeNetwork(accessToken: authenticationToken.access_token, householdId: householdId) { data in
            success()
        } failure: { error in
            failure(error)
        }.performRequest()
    }

    // MARK: - Private Helpers

    private func decodePlaylists(_ data: Any) -> [Playlist] {
        let json = JSON(data)
        var playlists = [Playlist]()

        for playlistJson in json["playlists"].arrayValue {
            if let playlist = Playlist(playlistJson) {
                playlists.append(playlist)
            }
        }

        return playlists
    }
}
