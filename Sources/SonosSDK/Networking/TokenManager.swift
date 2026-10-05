//
//  TokenManager.swift
//  SonosSDK
//
//  Created on 2026-02-23.
//

import Foundation
import os

/// Thread-safe actor managing Sonos OAuth tokens with automatic refresh
public actor TokenManager {

    // MARK: - Types

    /// Internal representation persisted by the token store
    struct StoredToken: Codable {
        let accessToken: String
        let refreshToken: String
        let tokenType: String
        let scope: String
        let expiresAt: Date

        var isExpired: Bool {
            // Treat as expired 60 seconds before actual expiry for safety margin
            expiresAt.addingTimeInterval(-60) < Date()
        }

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case tokenType = "token_type"
            case scope
            case expiresAt = "expire_date"
        }
    }

    /// Token response from the Sonos API
    public struct TokenResponse: Codable, Sendable {
        public let accessToken: String
        public let refreshToken: String
        public let tokenType: String
        public let expiresIn: Int
        public let scope: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case tokenType = "token_type"
            case expiresIn = "expires_in"
            case scope
        }
    }

    // MARK: - Properties

    private let clientKey: String
    /// Only known when the app exchanges tokens with Sonos directly.
    private let clientSecret: String?
    private let redirectURI: String
    private let exchange: SonosTokenExchanging
    private let tokenStore: TokenStoring
    private let legacyDefaults: UserDefaults

    /// Where SDK versions before the Keychain store kept the token, as plaintext
    static let legacyDefaultsKey = "com.sonossdk.token"
    private static let logger = Logger(subsystem: "com.sonossdk", category: "TokenManager")

    private var currentToken: StoredToken?
    private var refreshTask: Task<String, Error>?

    /// Called when authentication state changes
    public var onAuthenticationChanged: (@Sendable (Bool) -> Void)?

    // MARK: - Initialization

    /// Exchanges tokens with Sonos directly, so the integration's secret lives in the app.
    /// - Parameter tokenStore: Where the token is kept between launches; the Keychain by default.
    ///   A token left in UserDefaults by an earlier SDK version is moved into it.
    public init(clientKey: String, clientSecret: String, redirectURI: String, session: URLSession = .shared,
                tokenStore: TokenStoring = KeychainTokenStore()) {
        self.init(clientKey: clientKey, clientSecret: clientSecret, redirectURI: redirectURI,
                  exchange: SonosDirectTokenExchange(clientKey: clientKey, clientSecret: clientSecret, session: session),
                  tokenStore: tokenStore, legacyDefaults: .standard)
    }

    /// Exchanges tokens through `exchange`, e.g. a server that keeps the secret
    /// (`SonosBackendTokenExchange`).
    public init(clientKey: String, redirectURI: String, exchange: SonosTokenExchanging,
                tokenStore: TokenStoring = KeychainTokenStore()) {
        self.init(clientKey: clientKey, clientSecret: nil, redirectURI: redirectURI, exchange: exchange,
                  tokenStore: tokenStore, legacyDefaults: .standard)
    }

    init(clientKey: String, clientSecret: String, redirectURI: String, session: URLSession = .shared,
         tokenStore: TokenStoring, legacyDefaults: UserDefaults) {
        self.init(clientKey: clientKey, clientSecret: clientSecret, redirectURI: redirectURI,
                  exchange: SonosDirectTokenExchange(clientKey: clientKey, clientSecret: clientSecret, session: session),
                  tokenStore: tokenStore, legacyDefaults: legacyDefaults)
    }

    init(clientKey: String, clientSecret: String?, redirectURI: String, exchange: SonosTokenExchanging,
         tokenStore: TokenStoring, legacyDefaults: UserDefaults) {
        self.clientKey = clientKey
        self.clientSecret = clientSecret
        self.redirectURI = redirectURI
        self.exchange = exchange
        self.tokenStore = tokenStore
        self.legacyDefaults = legacyDefaults
        self.currentToken = Self.loadToken(from: tokenStore, migratingFrom: legacyDefaults)
    }

    // MARK: - Public Methods

    /// Get a valid access token, refreshing if needed
    public func validToken() async throws -> String {
        // If we have an in-flight refresh, await it
        if let refreshTask {
            return try await refreshTask.value
        }

        guard let token = currentToken else {
            throw SonosError.notAuthenticated
        }

        if !token.isExpired {
            return token.accessToken
        }

        // Token expired — refresh
        return try await refreshAndReturn(token.refreshToken)
    }

    /// Get the Base64-encoded client key for Basic auth. Throws when the
    /// secret stays on a server (`init(clientKey:redirectURI:exchange:tokenStore:)`).
    public func encodedClientKey() throws -> String {
        guard let clientSecret else { throw SonosError.notAuthenticated }
        return Data("\(clientKey):\(clientSecret)".utf8).base64EncodedString()
    }

    /// Whether a token exists (may be expired)
    public var hasToken: Bool {
        currentToken != nil
    }

    /// Whether the current token is valid (not expired)
    public var isAuthenticated: Bool {
        guard let token = currentToken else { return false }
        return !token.isExpired
    }

    /// Exchange an authorization code for tokens
    public func exchangeCode(_ authCode: String) async throws -> TokenResponse {
        let tokenResponse = try await exchange.exchange(code: authCode, redirectURI: redirectURI)
        storeToken(from: tokenResponse)
        return tokenResponse
    }

    /// Force a token refresh
    public func forceRefresh() async throws {
        guard let token = currentToken else {
            throw SonosError.notAuthenticated
        }
        _ = try await refreshAndReturn(token.refreshToken)
    }

    /// Clear all stored tokens (logout)
    public func clearTokens() {
        currentToken = nil
        refreshTask = nil
        do {
            try tokenStore.deleteTokenData()
        } catch {
            Self.logger.error("Failed to delete the stored token: \(String(describing: error), privacy: .public)")
        }
        // A token whose migration failed must not come back on the next launch
        legacyDefaults.removeObject(forKey: Self.legacyDefaultsKey)
        onAuthenticationChanged?(false)
    }

    /// Store a token received from external auth flow
    public func storeToken(from response: TokenResponse) {
        let stored = StoredToken(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            scope: response.scope,
            expiresAt: Date(timeIntervalSinceNow: TimeInterval(response.expiresIn))
        )
        currentToken = stored
        persist(stored)
        onAuthenticationChanged?(true)
    }

    /// Get the authorization URL for OAuth flow
    public func authorizationURL(state: String = "sonos_auth") -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = SonosHost.authorization
        components.path = "/login/v3/oauth"
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientKey),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: "playback-control-all"),
            URLQueryItem(name: "redirect_uri", value: redirectURI)
        ]
        return components.url
    }

    // MARK: - Private Methods

    private func refreshAndReturn(_ refreshToken: String) async throws -> String {
        // Coalesce concurrent refresh requests
        if let refreshTask {
            return try await refreshTask.value
        }

        let task = Task<String, Error> {
            defer { self.refreshTask = nil }

            do {
                let response = try await exchange.refresh(refreshToken: refreshToken)
                storeToken(from: response)
                return response.accessToken
            } catch where Self.isRejection(error) {
                // Sonos no longer accepts the refresh token: signed out.
                clearTokens()
                throw SonosError.notAuthenticated
            }
            // Anything else (offline, server trouble) keeps the token for the next try.
        }

        self.refreshTask = task
        return try await task.value
    }

    /// The authorization server refused the grant, as opposed to not being reachable.
    static func isRejection(_ error: Error) -> Bool {
        if case SonosError.httpError(let statusCode, _) = error {
            return statusCode == 400 || statusCode == 401
        }
        return false
    }

    // MARK: - Persistence

    /// Load the persisted token, first moving one that an earlier SDK version left in UserDefaults into the store
    private static func loadToken(from store: TokenStoring, migratingFrom defaults: UserDefaults) -> StoredToken? {
        let legacyData = defaults.data(forKey: legacyDefaultsKey)

        let storedData: Data?
        do {
            storedData = try store.loadTokenData()
        } catch {
            // Unknown whether the store already holds a token: use the legacy one for now
            // and leave it in place so a later launch can migrate it.
            logger.error("Failed to read the stored token: \(String(describing: error), privacy: .public)")
            return legacyData.flatMap(decodeToken)
        }

        if let storedData {
            // The store wins; a leftover plaintext copy is only a liability
            if legacyData != nil {
                defaults.removeObject(forKey: legacyDefaultsKey)
            }
            return decodeToken(storedData)
        }

        guard let legacyData else { return nil }
        guard let legacyToken = decodeToken(legacyData) else {
            defaults.removeObject(forKey: legacyDefaultsKey)
            return nil
        }
        do {
            try store.saveTokenData(legacyData)
            defaults.removeObject(forKey: legacyDefaultsKey)
        } catch {
            logger.error("Failed to move the token out of UserDefaults: \(String(describing: error), privacy: .public)")
        }
        return legacyToken
    }

    private static func decodeToken(_ data: Data) -> StoredToken? {
        try? JSONDecoder().decode(StoredToken.self, from: data)
    }

    private func persist(_ token: StoredToken) {
        do {
            try tokenStore.saveTokenData(JSONEncoder().encode(token))
        } catch {
            Self.logger.error("Failed to save the token: \(String(describing: error), privacy: .public)")
        }
    }
}
