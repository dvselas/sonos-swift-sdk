//
//  SonosManager.swift
//  SonosSDK
//
//  Created by James Hickman on 2/5/21.
//

import Foundation
import SwiftUI
import Combine

public class SonosManager: ObservableObject {

    // MARK: - Public Properties

    @Published public var isAuthenticated: Bool = false

    /// The token manager for OAuth operations
    public let tokenManager: TokenManager

    /// The HTTP client used for API requests
    public let httpClient: HTTPClientProtocol

    /// Subscription coordinator for WebSocket events
    public lazy var subscriptionCoordinator: SubscriptionCoordinator = {
        SubscriptionCoordinator()
    }()

    /// State cache for API responses
    public let stateCache = StateCacheManager.shared

    /// The client credentials
    let client: Client

    /// Authorization URL for OAuth flow
    public var authorizationUrl: URL? {
        get async {
            await tokenManager.authorizationURL()
        }
    }

    /// Synchronous authorization URL (for backward compatibility with SwiftUI views)
    public var authorizationUrlSync: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.sonos.com"
        components.path = "/login/v3/oauth"
        components.queryItems = [
            URLQueryItem(name: "client_id", value: client.key),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: "sonos_auth"),
            URLQueryItem(name: "scope", value: "playback-control-all"),
            URLQueryItem(name: "redirect_uri", value: client.redirectURI)
        ]
        return components.url
    }

    // MARK: - Services (internal)

    lazy var householdService = HouseholdService(client: httpClient)
    lazy var groupService = GroupService(client: httpClient)
    lazy var groupPlaybackService = GroupPlaybackService(client: httpClient)
    lazy var groupMetadataService = GroupMetadataService(client: httpClient)
    lazy var groupVolumeService = GroupVolumeService(client: httpClient)
    lazy var playerService = PlayerService(client: httpClient)
    lazy var playerVolumeService = PlayerVolumeService(client: httpClient)
    lazy var homeTheaterService = HomeTheaterService(client: httpClient)
    lazy var playerSettingsService = PlayerSettingsService(client: httpClient)
    lazy var audioClipService = AudioClipService(client: httpClient)
    lazy var favoriteService = FavoriteService(client: httpClient)
    lazy var playbackSessionService = PlaybackSessionService(client: httpClient)
    lazy var playlistService = PlaylistService(client: httpClient)
    lazy var musicServiceAccountsService = MusicServiceAccountsService(client: httpClient)
    lazy var authService = AuthService(tokenManager: tokenManager)

    // MARK: - Initialization

    public init(keyName: String, key: String, secret: String, redirectURI: String, callbackURL: String) {
        self.client = Client(keyName: keyName, key: key, secret: secret, redirectURI: redirectURI, callbackURL: callbackURL)

        let tokenMgr = TokenManager(clientKey: key, clientSecret: secret, redirectURI: redirectURI)
        self.tokenManager = tokenMgr
        self.httpClient = SonosHTTPClient(tokenManager: tokenMgr)

        // Sync initial auth state
        Task { [weak self] in
            let authenticated = await tokenMgr.isAuthenticated
            await MainActor.run {
                self?.isAuthenticated = authenticated
            }
        }

        // Listen for auth state changes
        Task { [weak self] in
            await tokenMgr.setOnAuthenticationChanged { isAuth in
                Task { @MainActor in
                    self?.isAuthenticated = isAuth
                }
            }
        }
    }

    /// Initialize with custom HTTP client (for testing)
    public init(client: Client, httpClient: HTTPClientProtocol, tokenManager: TokenManager) {
        self.client = client
        self.httpClient = httpClient
        self.tokenManager = tokenManager
    }
}

// MARK: - TokenManager helper for setting callback

extension TokenManager {
    func setOnAuthenticationChanged(_ callback: @escaping @Sendable (Bool) -> Void) {
        self.onAuthenticationChanged = callback
    }
}
