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

    /// The HTTP client used for API requests. Calls go over the local
    /// network while live updates run (see `startLiveUpdates`), otherwise
    /// to the Sonos cloud.
    public let httpClient: HTTPClientProtocol

    /// Holds the running live client for local command routing.
    let liveRouter: SonosLiveRouter

    /// Watches the network path while live updates run.
    let networkObserver = SonosLiveNetworkObserver()

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

    /// Exchanges tokens with Sonos directly, so the integration's secret lives in the app.
    /// - Parameter tokenStore: Where the OAuth token is kept between launches; the Keychain by default.
    public convenience init(keyName: String, key: String, secret: String, redirectURI: String, callbackURL: String,
                            tokenStore: TokenStoring = KeychainTokenStore()) {
        self.init(client: Client(keyName: keyName, key: key, secret: secret, redirectURI: redirectURI, callbackURL: callbackURL),
                  tokenManager: TokenManager(clientKey: key, clientSecret: secret, redirectURI: redirectURI, tokenStore: tokenStore))
    }

    /// For published apps, which keep the integration's secret on a server:
    /// tokens are exchanged through `tokenExchange` (e.g. `SonosBackendTokenExchange`).
    public convenience init(keyName: String, key: String, redirectURI: String, tokenExchange: SonosTokenExchanging,
                            tokenStore: TokenStoring = KeychainTokenStore()) {
        self.init(client: Client(keyName: keyName, key: key, secret: "", redirectURI: redirectURI, callbackURL: ""),
                  tokenManager: TokenManager(clientKey: key, redirectURI: redirectURI, exchange: tokenExchange, tokenStore: tokenStore))
    }

    /// Local-only mode: talks to the players on the local network and never to
    /// the cloud, so it needs no Sonos account, no sign-in and no server. Players
    /// are found over Bonjour; every call goes to their local API, and
    /// `isAuthenticated` is always true. Live updates run over the players'
    /// sockets as usual (`startLiveUpdates`).
    ///
    /// The Sonos terms license the players' local API only "for internal
    /// evaluation and testing"; publishing an app that uses it needs a separate
    /// license from Sonos.
    ///
    /// - Parameters:
    ///   - localAPIKey: Sent to the players with every call (`X-Sonos-Api-Key`);
    ///     use your integration's key.
    ///   - discovery: How players are found; Bonjour (`_sonos._tcp`) by default.
    public convenience init(keyName: String, localAPIKey key: String,
                            discovery: any SonosPlayerDiscovering = SonosBonjourDiscovery()) {
        let tokenManager = TokenManager(clientKey: key, clientSecret: "", redirectURI: "", tokenStore: InMemoryTokenStore(),
                                        legacyDefaults: UserDefaults(suiteName: "com.sonossdk.local-only") ?? .standard)
        self.init(client: Client(keyName: keyName, key: key, secret: "", redirectURI: "", callbackURL: ""),
                  cloud: SonosLocalHTTPClient(apiKey: key, discovery: discovery),
                  tokenManager: tokenManager, routesContentLocally: true)
        isAuthenticated = true
    }

    private init(client: Client, tokenManager tokenMgr: TokenManager) {
        self.client = client
        self.tokenManager = tokenMgr
        let router = SonosLiveRouter()
        self.liveRouter = router
        self.httpClient = SonosRoutingHTTPClient(cloud: SonosHTTPClient(tokenManager: tokenMgr), router: router)

        Task { [weak self] in
            // Listen for auth state changes
            await tokenMgr.setOnAuthenticationChanged { isAuth in
                Task { @MainActor in
                    self?.isAuthenticated = isAuth
                }
            }
            // Signed in while a token is stored. One that expired since the last launch
            // is refreshed now; if Sonos refuses the refresh, the callback signs out.
            let hasToken = await tokenMgr.hasToken
            await MainActor.run {
                self?.isAuthenticated = hasToken
            }
            if hasToken {
                _ = try? await tokenMgr.validToken()
            }
        }
    }

    /// Initialize with custom HTTP client (for testing)
    public convenience init(client: Client, httpClient: HTTPClientProtocol, tokenManager: TokenManager) {
        self.init(client: client, cloud: httpClient, tokenManager: tokenManager, routesContentLocally: false)
    }

    init(client: Client, cloud: HTTPClientProtocol, tokenManager: TokenManager, routesContentLocally: Bool) {
        self.client = client
        let router = SonosLiveRouter()
        self.liveRouter = router
        self.httpClient = SonosRoutingHTTPClient(cloud: cloud, router: router, routesContentLocally: routesContentLocally)
        self.tokenManager = tokenManager
    }
}

// MARK: - TokenManager helper for setting callback

extension TokenManager {
    func setOnAuthenticationChanged(_ callback: @escaping @Sendable (Bool) -> Void) {
        self.onAuthenticationChanged = callback
    }
}
