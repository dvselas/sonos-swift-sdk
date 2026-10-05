//
//  TokenExchangeTests.swift
//  SonosSDKTests
//
//  Tokens exchanged through a server that keeps the integration's secret,
//  and what a failed refresh does to the stored token.
//

import Foundation
import XCTest
@testable import SonosSDK

/// Answers every request of its session with the next stubbed response.
final class StubURLProtocol: URLProtocol {
    struct Stub {
        var status: Int = 200
        var body: String = ""
        var error: URLError?
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var stubs: [Stub] = []
    nonisolated(unsafe) private static var _requests: [(request: URLRequest, body: Data?)] = []

    static func reset(_ stubs: [Stub]) {
        lock.lock(); self.stubs = stubs; _requests = []; lock.unlock()
    }

    static var requests: [(request: URLRequest, body: Data?)] {
        lock.lock(); defer { lock.unlock() }
        return _requests
    }

    static var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self._requests.append((request, Self.body(of: request)))
        let stub = Self.stubs.isEmpty ? Stub(status: 500) : Self.stubs.removeFirst()
        Self.lock.unlock()

        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: stub.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(stub.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// URLSession hands protocols the body as a stream.
    private static func body(of request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

final class TokenExchangeTests: XCTestCase {

    private let tokenJSON = #"{"access_token":"A2","refresh_token":"R2","token_type":"Bearer","expires_in":86400,"scope":"playback-control-all"}"#

    private func makeManager() -> TokenManager {
        let exchange = SonosBackendTokenExchange(baseURL: URL(string: "https://backend.test")!, session: StubURLProtocol.session)
        return TokenManager(clientKey: "key", clientSecret: nil, redirectURI: "https://backend.test/sonos/callback",
                            exchange: exchange, tokenStore: InMemoryTokenStore(),
                            legacyDefaults: UserDefaults(suiteName: "TokenExchangeTests-\(UUID())")!)
    }

    /// A stored token that has already expired, so the next use refreshes it.
    private func storeExpiredToken(in manager: TokenManager) async {
        await manager.storeToken(from: TokenManager.TokenResponse(accessToken: "A1", refreshToken: "R1", tokenType: "Bearer",
                                                                   expiresIn: 0, scope: "playback-control-all"))
    }

    private func json(_ data: Data?) -> [String: String] {
        (data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: String]) ?? [:]
    }

    func testTheCodeIsExchangedThroughTheBackendWithoutTheSecret() async throws {
        StubURLProtocol.reset([.init(body: tokenJSON)])
        let manager = makeManager()

        _ = try await manager.exchangeCode("CODE")

        let sent = try XCTUnwrap(StubURLProtocol.requests.first)
        XCTAssertEqual(sent.request.url?.absoluteString, "https://backend.test/sonos/token")
        XCTAssertEqual(sent.request.httpMethod, "POST")
        XCTAssertNil(sent.request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(json(sent.body), ["code": "CODE"])
        let token = try await manager.validToken()
        XCTAssertEqual(token, "A2")
    }

    func testAnExpiredTokenIsRefreshedThroughTheBackend() async throws {
        StubURLProtocol.reset([.init(body: tokenJSON)])
        let manager = makeManager()
        await storeExpiredToken(in: manager)

        let token = try await manager.validToken()

        XCTAssertEqual(token, "A2")
        let sent = try XCTUnwrap(StubURLProtocol.requests.first)
        XCTAssertEqual(sent.request.url?.path, "/sonos/refresh")
        XCTAssertEqual(json(sent.body), ["refreshToken": "R1"])
    }

    func testARefusedRefreshSignsOut() async {
        StubURLProtocol.reset([.init(status: 400, body: #"{"error":"invalid_grant"}"#)])
        let manager = makeManager()
        await storeExpiredToken(in: manager)

        do {
            _ = try await manager.validToken()
            XCTFail("expected an error")
        } catch {
            guard case SonosError.notAuthenticated = error else { return XCTFail("\(error)") }
        }
        let hasToken = await manager.hasToken
        XCTAssertFalse(hasToken)
    }

    func testARefreshWhileOfflineKeepsTheToken() async {
        StubURLProtocol.reset([.init(error: URLError(.notConnectedToInternet))])
        let manager = makeManager()
        await storeExpiredToken(in: manager)

        do {
            _ = try await manager.validToken()
            XCTFail("expected an error")
        } catch {
            if case SonosError.notAuthenticated = error { XCTFail("being offline isn't a sign-out") }
        }
        let hasToken = await manager.hasToken
        XCTAssertTrue(hasToken, "the next try may succeed")
    }

    func testServerTroubleKeepsTheTokenToo() async {
        StubURLProtocol.reset([.init(status: 502, body: "Bad Gateway")])
        let manager = makeManager()
        await storeExpiredToken(in: manager)

        _ = try? await manager.validToken()

        let hasToken = await manager.hasToken
        XCTAssertTrue(hasToken)
    }

    func testWithoutTheSecretThereIsNoBasicAuthorization() async {
        do {
            _ = try await makeManager().encodedClientKey()
            XCTFail("expected an error")
        } catch {}
    }
}
