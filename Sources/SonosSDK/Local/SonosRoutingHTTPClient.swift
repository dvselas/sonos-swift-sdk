//
//  SonosRoutingHTTPClient.swift
//  SonosSDK
//
//  Sends Control API calls over the local socket when a live client can
//  reach the target player, otherwise over the cloud. A command only falls
//  back to the cloud when it was never sent locally, so non-idempotent
//  commands (togglePlayPause, skip, relative volume) never run twice.
//

import Foundation

/// Holds the active live client for the routing HTTP client.
final class SonosLiveRouter: @unchecked Sendable {
    private let lock = NSLock()
    private var _client: SonosLiveClient?

    var client: SonosLiveClient? {
        lock.lock()
        defer { lock.unlock() }
        return _client
    }

    func replace(with client: SonosLiveClient?) -> SonosLiveClient? {
        lock.lock()
        defer { lock.unlock() }
        let previous = _client
        _client = client
        return previous
    }

    /// Clears the router only if `client` is still the active one.
    func clear(ifCurrent client: SonosLiveClient) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard _client === client else { return false }
        _client = nil
        return true
    }
}

final class SonosRoutingHTTPClient: HTTPClientProtocol, @unchecked Sendable {

    let cloud: HTTPClientProtocol
    let router: SonosLiveRouter
    /// Local-only mode: loading favorites and playlists goes over the sockets
    /// too (`contentRoute`), because `cloud` is the players' REST API, which
    /// doesn't take them.
    let routesContentLocally: Bool

    init(cloud: HTTPClientProtocol, router: SonosLiveRouter, routesContentLocally: Bool = false) {
        self.cloud = cloud
        self.router = router
        self.routesContentLocally = routesContentLocally
    }

    func request<T: Decodable>(_ endpoint: SonosAPIEndpoint) async throws -> T {
        if let frame = try await performLocally(endpoint) {
            do {
                return try SonosLocalFrameCodec.decodeBody(T.self, from: frame)
            } catch let error as DecodingError {
                throw SonosError.decodingError(error)
            }
        }
        return try await cloud.request(endpoint)
    }

    func request(_ endpoint: SonosAPIEndpoint) async throws {
        if try await performLocally(endpoint) != nil {
            return
        }
        try await cloud.request(endpoint)
    }

    func requestData(_ endpoint: SonosAPIEndpoint) async throws -> Data {
        if let frame = try await performLocally(endpoint) {
            return try SonosLocalFrameCodec.bodyData(from: frame)
        }
        return try await cloud.requestData(endpoint)
    }

    /// The reply frame, or nil when the endpoint must go to the cloud.
    private func performLocally(_ endpoint: SonosAPIEndpoint) async throws -> Data? {
        guard let route = endpoint.localRoute ?? (routesContentLocally ? endpoint.contentRoute : nil),
              let live = router.client else { return nil }
        do {
            return try await live.perform(route)
        } catch let error as SonosLocalError {
            switch error {
            case .notConnected, .noRoute:
                return nil
            case .commandFailed(let code, let reason):
                throw SonosError.apiError(errorCode: code, reason: reason)
            case .timeout where route.waitsLong:
                // The player is still loading; report it like the cloud, so callers wait for the new queue.
                throw SonosError.httpError(statusCode: 504, body: SonosErrorBody(errorCode: "ERROR_COMMAND_TIMEOUT",
                                                                                 reason: error.localizedDescription))
            case .timeout, .invalidFrame, .closed:
                throw SonosError.webSocketError(.connectionFailed(error.localizedDescription))
            }
        }
    }
}
