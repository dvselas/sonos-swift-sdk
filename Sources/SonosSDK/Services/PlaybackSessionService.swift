//
//  PlaybackSessionService.swift
//  SonosSDK
//
//  Created on 2025-01-22.
//

import Foundation
import SwiftyJSON
import SonosNetworking

struct PlaybackSessionService {

    // MARK: - Session Management

    func createSession(authenticationToken: AuthenticationToken, groupId: String, appId: String, appContext: String, accountId: String? = nil, customData: String? = nil, success: @escaping (PlaybackSession) -> (), failure: @escaping (Error?) -> ()) {
        PlaybackSessionCreateNetwork(accessToken: authenticationToken.access_token, groupId: groupId, accountId: accountId, appContext: appContext, appId: appId, customData: customData, success: { data in
            guard let data = data,
                  let session = PlaybackSession(data) else {
                let error = NSError.errorWithMessage(message: "Could not create PlaybackSession object.")
                failure(error)
                return
            }
            success(session)
        }, failure: { error in
            failure(error)
        }).performRequest()
    }

    func joinSession(authenticationToken: AuthenticationToken, groupId: String, appId: String, appContext: String, success: @escaping (PlaybackSession) -> (), failure: @escaping (Error?) -> ()) {
        PlaybackSessionJoinNetwork(accessToken: authenticationToken.access_token, groupId: groupId, appId: appId, appContext: appContext, success: { data in
            guard let data = data,
                  let session = PlaybackSession(data) else {
                let error = NSError.errorWithMessage(message: "Could not create PlaybackSession object.")
                failure(error)
                return
            }
            success(session)
        }, failure: { error in
            failure(error)
        }).performRequest()
    }

    func suspendSession(authenticationToken: AuthenticationToken, sessionId: String, queueVersion: String? = nil, success: @escaping () -> (), failure: @escaping (Error?) -> ()) {
        PlaybackSessionSuspendNetwork(accessToken: authenticationToken.access_token, sessionId: sessionId, queueVersion: queueVersion, success: { data in
            success()
        }, failure: { error in
            failure(error)
        }).performRequest()
    }

    // MARK: - Cloud Queue Operations

    func loadCloudQueue(authenticationToken: AuthenticationToken, sessionId: String, queueBaseUrl: String, httpAuthorization: String? = nil, itemId: String? = nil, playOnCompletion: Bool? = nil, positionMillis: UInt? = nil, queueVersion: String? = nil, trackMetadata: [String: Any]? = nil, useHttpAuthorizationForMedia: Bool? = nil, success: @escaping () -> (), failure: @escaping (Error?) -> ()) {
        PlaybackSessionLoadCloudQueueNetwork(accessToken: authenticationToken.access_token, sessionId: sessionId, httpAuthorization: httpAuthorization, itemId: itemId, playOnCompletion: playOnCompletion, positionMillis: positionMillis, queueBaseUrl: queueBaseUrl, queueVersion: queueVersion, trackMetadata: trackMetadata, useHttpAuthorizationForMedia: useHttpAuthorizationForMedia, success: { data in
            success()
        }, failure: { error in
            failure(error)
        }).performRequest()
    }

    func refreshCloudQueue(authenticationToken: AuthenticationToken, sessionId: String, success: @escaping () -> (), failure: @escaping (Error?) -> ()) {
        PlaybackSessionRefreshCloudQueueNetwork(accessToken: authenticationToken.access_token, sessionId: sessionId, success: { data in
            success()
        }, failure: { error in
            failure(error)
        }).performRequest()
    }

    // MARK: - Stream URL

    func loadStreamUrl(authenticationToken: AuthenticationToken, sessionId: String, streamUrl: String, playOnCompletion: Bool? = nil, success: @escaping () -> (), failure: @escaping (Error?) -> ()) {
        PlaybackSessionLoadStreamUrlNetwork(accessToken: authenticationToken.access_token, sessionId: sessionId, streamUrl: streamUrl, playOnCompletion: playOnCompletion, success: { data in
            success()
        }, failure: { error in
            failure(error)
        }).performRequest()
    }

    // MARK: - Session Playback Control

    func sessionSeek(authenticationToken: AuthenticationToken, sessionId: String, positionMillis: UInt, itemId: String, success: @escaping () -> (), failure: @escaping (Error?) -> ()) {
        PlaybackSessionSeekNetwork(accessToken: authenticationToken.access_token, sessionId: sessionId, itemId: itemId, positionMillis: positionMillis, success: { data in
            success()
        }, failure: { error in
            failure(error)
        }).performRequest()
    }

    func sessionSeekRelative(authenticationToken: AuthenticationToken, sessionId: String, deltaMillis: Int, success: @escaping () -> (), failure: @escaping (Error?) -> ()) {
        PlaybackSessionSeekRelativeNetwork(accessToken: authenticationToken.access_token, sessionId: sessionId, deltaMillis: deltaMillis, success: { data in
            success()
        }, failure: { error in
            failure(error)
        }).performRequest()
    }

    func sessionSkipToItem(authenticationToken: AuthenticationToken, sessionId: String, itemId: String, playOnCompletion: Bool? = nil, success: @escaping () -> (), failure: @escaping (Error?) -> ()) {
        PlaybackSessionSkipToItemNetwork(accessToken: authenticationToken.access_token, sessionId: sessionId, itemId: itemId, playOnCompletion: playOnCompletion, success: { data in
            success()
        }, failure: { error in
            failure(error)
        }).performRequest()
    }

    // MARK: - Subscriptions

    func subscribe(authenticationToken: AuthenticationToken, sessionId: String, success: @escaping () -> (), failure: @escaping (Error?) -> ()) {
        PlaybackSessionSubscribeNetwork(accessToken: authenticationToken.access_token, sessionId: sessionId, success: { data in
            success()
        }, failure: { error in
            failure(error)
        }).performRequest()
    }

    func unsubscribe(authenticationToken: AuthenticationToken, sessionId: String, success: @escaping () -> (), failure: @escaping (Error?) -> ()) {
        PlaybackSessionUnsubscribeNetwork(accessToken: authenticationToken.access_token, sessionId: sessionId, success: { data in
            success()
        }, failure: { error in
            failure(error)
        }).performRequest()
    }
}
