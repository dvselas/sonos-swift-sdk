//
//  File.swift
//
//
//  Created by James Hickman on 2/17/21.
//

import Foundation
import SwiftyJSON
import SonosNetworking

struct GroupPlaybackService {
            
    func getGroupPlaybackStatus(authenticationToken: AuthenticationToken, groupId: String, success: @escaping (PlaybackStatus) -> (), failure: @escaping (Error?) -> ()) {
        PlaybackGetStatusNetwork(accessToken: authenticationToken.access_token, groupId: groupId) { data in
            guard let data = data,
                  let playbackStatus = PlaybackStatus(data) else {
                let error = NSError.errorWithMessage(message: "Could not create PlaybackGetStatusNetwork object.")
                failure(error)
                return
            }
            success(playbackStatus)
        } failure: { error in
            failure(error)
        }.performRequest()
    }
    
    func setGroupPlaybackPlay(authenticationToken: AuthenticationToken, groupId: String, success: @escaping (Data) -> (), failure: @escaping (Error?) -> ()) {
        
        PlaybackPlayNetwork(accessToken: authenticationToken.access_token, groupId: groupId) { data in
            guard let data = data else {
                let error = NSError.errorWithMessage(message: "Could not create PlaybackPlayNetwork object.")
                failure(error)
                return
            }
            success(data)
        } failure: { error in
            failure(error)
        }.performRequest()
    }
    
    func setGroupPlaybackPause(authenticationToken: AuthenticationToken, groupId: String, success: @escaping (Data) -> (), failure: @escaping (Error?) -> ()) {
        
        PlaybackPauseNetwork(accessToken: authenticationToken.access_token, groupId: groupId) { data in
            guard let data = data else {
                let error = NSError.errorWithMessage(message: "Could not create PlaybackPauseNetwork object.")
                failure(error)
                return
            }
            success(data)
        } failure: { error in
            failure(error)
        }.performRequest()
    }

    func setGroupPlaybackModes(authenticationToken: AuthenticationToken, groupId: String, playModes: [String], success: @escaping (Data) -> (), failure: @escaping (Error?) -> ()) {
        
        PlaybackSetPlayModesNetwork(accessToken: authenticationToken.access_token, groupId: groupId, playModes: playModes) { data in
            guard let data = data else {
                let error = NSError.errorWithMessage(message: "Could not create PlaybackSetPlayModesNetwork object.")
                failure(error)
                return
            }
            success(data)
        } failure: { error in
            failure(error)
        }.performRequest()
    }
    
    func setGroupSkipToNext(authenticationToken: AuthenticationToken, groupId: String, success: @escaping (Data) -> (), failure: @escaping (Error?) -> ()) {
        
        PlaybackSkipToNextTrackNetwork(accessToken: authenticationToken.access_token, groupId: groupId) { data in
            guard let data = data else {
                let error = NSError.errorWithMessage(message: "Could not create PlaybackSkipToNextTrackNetwork object.")
                failure(error)
                return
            }
            success(data)
        } failure: { error in
            failure(error)
        }.performRequest()
    }
    
    func setGroupSkipToPrevious(authenticationToken: AuthenticationToken, groupId: String, success: @escaping (Data) -> (), failure: @escaping (Error?) -> ()) {
        
        PlaybackSkipToPreviousTrackNetwork(accessToken: authenticationToken.access_token, groupId: groupId) { data in
            guard let data = data else {
                let error = NSError.errorWithMessage(message: "Could not create PlaybackSkipToPreviousTrackNetwork object.")
                failure(error)
                return
            }
            success(data)
        } failure: { error in
            failure(error)
        }.performRequest()
    }
    
    func setGroupSkipToSeek(authenticationToken: AuthenticationToken, groupId: String, positionMillis: UInt, success: @escaping (Data) -> (), failure: @escaping (Error?) -> ()) {

        PlaybackSeekNetwork(accessToken: authenticationToken.access_token, groupId: groupId, positionMillis: positionMillis) { data in
            guard let data = data else {
                let error = NSError.errorWithMessage(message: "Could not create PlaybackSeekNetwork object.")
                failure(error)
                return
            }
            success(data)
        } failure: { error in
            failure(error)
        }.performRequest()
    }

    // MARK: - Advanced Playback

    func togglePlayPause(authenticationToken: AuthenticationToken, groupId: String, success: @escaping (Data) -> (), failure: @escaping (Error?) -> ()) {
        PlaybackTogglePlayPauseNetwork(accessToken: authenticationToken.access_token, groupId: groupId) { data in
            guard let data = data else {
                let error = NSError.errorWithMessage(message: "Could not create PlaybackTogglePlayPauseNetwork object.")
                failure(error)
                return
            }
            success(data)
        } failure: { error in
            failure(error)
        }.performRequest()
    }

    func seekRelative(authenticationToken: AuthenticationToken, groupId: String, itemId: String? = nil, deltaMillis: Int, success: @escaping (Data) -> (), failure: @escaping (Error?) -> ()) {
        PlaybackSeekRelativeNetwork(accessToken: authenticationToken.access_token, groupId: groupId, itemId: itemId, deltaMillis: deltaMillis) { data in
            guard let data = data else {
                let error = NSError.errorWithMessage(message: "Could not create PlaybackSeekRelativeNetwork object.")
                failure(error)
                return
            }
            success(data)
        } failure: { error in
            failure(error)
        }.performRequest()
    }

    func loadLineIn(authenticationToken: AuthenticationToken, groupId: String, deviceId: String? = nil, playOnCompletion: Bool? = nil, success: @escaping (Data) -> (), failure: @escaping (Error?) -> ()) {
        PlaybackLoadLineInNetwork(accessToken: authenticationToken.access_token, groupId: groupId, deviceId: deviceId, playOnCompletion: playOnCompletion) { data in
            guard let data = data else {
                let error = NSError.errorWithMessage(message: "Could not create PlaybackLoadLineInNetwork object.")
                failure(error)
                return
            }
            success(data)
        } failure: { error in
            failure(error)
        }.performRequest()
    }
}
