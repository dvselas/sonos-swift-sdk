//
//  TokenManagerTests.swift
//  SonosSDKTests
//

import XCTest
@testable import SonosSDK

final class TokenManagerTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "TokenManagerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Save, load, clear

    func testStoringATokenSavesItToTheStore() async throws {
        let store = InMemoryTokenStore()
        let manager = makeManager(store: store)

        await manager.storeToken(from: response(access: "A1", refresh: "R1"))

        let saved = try decodedToken(store.loadTokenData())
        XCTAssertEqual(saved.accessToken, "A1")
        XCTAssertEqual(saved.refreshToken, "R1")
        let token = try await manager.validToken()
        XCTAssertEqual(token, "A1")
    }

    func testANewManagerLoadsTheSavedToken() async throws {
        let store = InMemoryTokenStore()
        await makeManager(store: store).storeToken(from: response(access: "A1"))

        let relaunched = makeManager(store: store)

        let isAuthenticated = await relaunched.isAuthenticated
        XCTAssertTrue(isAuthenticated)
        let token = try await relaunched.validToken()
        XCTAssertEqual(token, "A1")
    }

    func testClearingTokensDeletesTheSavedToken() async {
        let store = InMemoryTokenStore()
        let manager = makeManager(store: store)
        await manager.storeToken(from: response())

        await manager.clearTokens()

        XCTAssertNil(store.loadTokenData())
        let hasToken = await makeManager(store: store).hasToken
        XCTAssertFalse(hasToken)
    }

    func testStartsSignedOutWithNothingStored() async {
        let manager = makeManager(store: InMemoryTokenStore())

        let hasToken = await manager.hasToken
        XCTAssertFalse(hasToken)
        do {
            _ = try await manager.validToken()
            XCTFail("expected notAuthenticated")
        } catch {
            guard case SonosError.notAuthenticated = error else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }

    // MARK: - Migration from UserDefaults

    func testMovesALegacyTokenIntoTheStore() async throws {
        let legacy = try encodedToken(access: "legacy")
        defaults.set(legacy, forKey: TokenManager.legacyDefaultsKey)
        let store = InMemoryTokenStore()

        let manager = makeManager(store: store)

        XCTAssertEqual(store.loadTokenData(), legacy)
        XCTAssertNil(defaults.object(forKey: TokenManager.legacyDefaultsKey))
        let token = try await manager.validToken()
        XCTAssertEqual(token, "legacy")
    }

    func testKeepsTheStoredTokenOverALegacyOne() async throws {
        let stored = try encodedToken(access: "stored")
        let store = InMemoryTokenStore(tokenData: stored)
        defaults.set(try encodedToken(access: "legacy"), forKey: TokenManager.legacyDefaultsKey)

        let manager = makeManager(store: store)

        XCTAssertEqual(store.loadTokenData(), stored)
        XCTAssertNil(defaults.object(forKey: TokenManager.legacyDefaultsKey))
        let token = try await manager.validToken()
        XCTAssertEqual(token, "stored")
    }

    func testKeepsTheLegacyTokenWhenTheStoreCannotSave() async throws {
        let legacy = try encodedToken(access: "legacy")
        defaults.set(legacy, forKey: TokenManager.legacyDefaultsKey)

        let manager = makeManager(store: FailingTokenStore())

        XCTAssertEqual(defaults.data(forKey: TokenManager.legacyDefaultsKey), legacy)
        let token = try await manager.validToken()
        XCTAssertEqual(token, "legacy")
    }

    func testKeepsTheLegacyTokenWhenTheStoreCannotBeRead() async throws {
        let legacy = try encodedToken(access: "legacy")
        defaults.set(legacy, forKey: TokenManager.legacyDefaultsKey)

        let manager = makeManager(store: FailingTokenStore(failsLoading: true))

        XCTAssertEqual(defaults.data(forKey: TokenManager.legacyDefaultsKey), legacy)
        let token = try await manager.validToken()
        XCTAssertEqual(token, "legacy")
    }

    func testClearingTokensRemovesAnUnmigratedLegacyToken() async throws {
        defaults.set(try encodedToken(access: "legacy"), forKey: TokenManager.legacyDefaultsKey)
        let manager = makeManager(store: FailingTokenStore(failsLoading: true))

        await manager.clearTokens()

        XCTAssertNil(defaults.object(forKey: TokenManager.legacyDefaultsKey))
    }

    func testDropsAnUnreadableLegacyEntry() async {
        defaults.set(Data("not a token".utf8), forKey: TokenManager.legacyDefaultsKey)
        let store = InMemoryTokenStore()

        let manager = makeManager(store: store)

        XCTAssertNil(store.loadTokenData())
        XCTAssertNil(defaults.object(forKey: TokenManager.legacyDefaultsKey))
        let hasToken = await manager.hasToken
        XCTAssertFalse(hasToken)
    }

    // MARK: - Helpers

    private func makeManager(store: TokenStoring) -> TokenManager {
        TokenManager(clientKey: "k", clientSecret: "s", redirectURI: "r://", tokenStore: store, legacyDefaults: defaults)
    }

    private func response(access: String = "access", refresh: String = "refresh") -> TokenManager.TokenResponse {
        TokenManager.TokenResponse(accessToken: access, refreshToken: refresh, tokenType: "Bearer",
                                   expiresIn: 3600, scope: "playback-control-all")
    }

    private func encodedToken(access: String) throws -> Data {
        try JSONEncoder().encode(TokenManager.StoredToken(
            accessToken: access, refreshToken: "refresh", tokenType: "Bearer",
            scope: "playback-control-all", expiresAt: Date(timeIntervalSinceNow: 3600)))
    }

    private func decodedToken(_ data: Data?) throws -> TokenManager.StoredToken {
        try JSONDecoder().decode(TokenManager.StoredToken.self, from: XCTUnwrap(data))
    }
}

/// A store whose writes always fail, and optionally its reads too
private struct FailingTokenStore: TokenStoring {
    struct Failure: Error {}

    var failsLoading = false

    func loadTokenData() throws -> Data? {
        if failsLoading { throw Failure() }
        return nil
    }

    func saveTokenData(_ data: Data) throws { throw Failure() }

    func deleteTokenData() throws { throw Failure() }
}

/// Exercises the real Keychain under a throwaway service, so it never touches the SDK's own item
final class KeychainTokenStoreTests: XCTestCase {

    func testSavesReplacesAndDeletesTokenData() throws {
        let store = KeychainTokenStore(service: "com.sonossdk.tests.\(UUID().uuidString)")
        defer { try? store.deleteTokenData() }

        do {
            try store.saveTokenData(Data("first".utf8))
        } catch let error as KeychainTokenStore.KeychainError
                    where [errSecInteractionNotAllowed, errSecMissingEntitlement, errSecNotAvailable].contains(error.status) {
            throw XCTSkip("No usable keychain here: \(error)")
        }
        XCTAssertEqual(try store.loadTokenData(), Data("first".utf8))

        try store.saveTokenData(Data("second".utf8))
        XCTAssertEqual(try store.loadTokenData(), Data("second".utf8))

        try store.deleteTokenData()
        XCTAssertNil(try store.loadTokenData())
        XCTAssertNoThrow(try store.deleteTokenData())
    }
}
