//
//  SonosLocalHTTPClient.swift
//  SonosSDK
//
//  Sends Control API calls to the players' local REST API instead of the
//  cloud (local-only mode, see `SonosManager.init(keyName:localAPIKey:discovery:)`).
//  Players answer on `https://<player>:1443/api/v1/…` with the cloud's paths
//  and bodies: group calls go to the group's coordinator, player calls to
//  the player, household calls to any player of the household. Their
//  certificates are checked like on the local sockets.
//
//  Players don't list households, so `getHouseholds` asks one player per
//  household it finds on the network which household it belongs to.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class SonosLocalHTTPClient: HTTPClientProtocol, @unchecked Sendable {

    private let apiKey: String
    private let discovery: any SonosPlayerDiscovering
    private let discoveryTimeout: Duration
    private let delegate: SonosLocalSessionDelegate
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// - Parameters:
    ///   - requestTimeout: Loading a long playlist keeps the player busy for a
    ///     while; after this, a call fails with `504` like the cloud's.
    ///   - protocolClasses: For tests.
    init(apiKey: String, discovery: any SonosPlayerDiscovering, requestTimeout: TimeInterval = 20,
         discoveryTimeout: Duration = .seconds(5), protocolClasses: [AnyClass]? = nil) {
        self.apiKey = apiKey
        self.discovery = discovery
        self.discoveryTimeout = discoveryTimeout
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        if let protocolClasses {
            configuration.protocolClasses = protocolClasses
        }
        let delegate = SonosLocalSessionDelegate()
        self.delegate = delegate
        self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    deinit {
        session.invalidateAndCancel()
    }

    // MARK: HTTPClientProtocol

    func request<T: Decodable>(_ endpoint: SonosAPIEndpoint) async throws -> T {
        let data = try await requestData(endpoint)
        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw SonosError.decodingError(error)
        }
    }

    func request(_ endpoint: SonosAPIEndpoint) async throws {
        _ = try await requestData(endpoint)
    }

    func requestData(_ endpoint: SonosAPIEndpoint) async throws -> Data {
        let players = await discovery.players(waitingUpTo: discoveryTimeout)
        trust(players)
        if case .getHouseholds = endpoint {
            return try await households(among: players)
        }
        guard let target = endpoint.localTarget else {
            throw SonosLocalError.noRoute(String(describing: endpoint))
        }
        let candidates = Self.players(for: target, among: players)
        guard !candidates.isEmpty else {
            throw SonosLocalError.noRoute(target.id)
        }
        // Any player of a household can answer; a group or player call has exactly one.
        var lastError: Error?
        for player in candidates.prefix(3) {
            do {
                return try await send(endpoint, to: player)
            } catch SonosError.networkError(let error) {
                lastError = SonosError.networkError(error)
            }
        }
        throw lastError ?? SonosLocalError.noRoute(target.id)
    }

    // MARK: Routing

    /// The players that answer for `target`, most suitable first.
    static func players(for target: SonosLocalTarget, among players: [SonosDiscoveredPlayer]) -> [SonosDiscoveredPlayer] {
        switch target {
        case .household(let householdId):
            return players.filter { $0.belongs(to: householdId) }
        case .group(let groupId):
            guard let coordinatorId = SonosLiveClient.coordinatorId(fromGroupId: groupId) else { return [] }
            return players.filter { $0.id == coordinatorId }
        case .player(let playerId):
            return players.filter { $0.id == playerId }
        }
    }

    private func trust(_ players: [SonosDiscoveredPlayer]) {
        delegate.setTrustedPlayers(Dictionary(players.map { ($0.host, $0.id) }, uniquingKeysWith: { first, _ in first }))
    }

    // MARK: Requests

    private func send(_ endpoint: SonosAPIEndpoint, to player: SonosDiscoveredPlayer) async throws -> Data {
        var request = URLRequest(url: try Self.url(path: endpoint.localPath, host: player.host))
        request.httpMethod = endpoint.method.rawValue
        if let body = endpoint.body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }
        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        var request = request
        request.setValue(apiKey, forHTTPHeaderField: SonosLocalAPI.apiKeyHeader)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            // The player is still at it (a long playlist); report it like the cloud does.
            throw SonosError.httpError(statusCode: 504, body: SonosErrorBody(errorCode: "ERROR_COMMAND_TIMEOUT",
                                                                             reason: "The player didn't answer in time."))
        } catch let error as URLError {
            throw SonosError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SonosError.invalidResponse
        }
        switch http.statusCode {
        case 200...299:
            return data.isEmpty ? Data("{}".utf8) : data
        case 429:
            throw SonosError.rateLimited(retryAfter: http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init))
        default:
            throw SonosError.httpError(statusCode: http.statusCode, body: try? decoder.decode(SonosErrorBody.self, from: data))
        }
    }

    static func url(path: String, host: String) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.port = SonosLocalAPI.port
        components.path = path
        guard let url = components.url else { throw SonosError.invalidResponse }
        return url
    }

    // MARK: Households

    private struct PlayerInfo: Decodable {
        let householdId: String
    }

    /// One household per `hhid` announced on the network, asked of its first player that answers.
    private func households(among players: [SonosDiscoveredPlayer]) async throws -> Data {
        var households: [Household] = []
        var lastError: Error?
        let byTag = Dictionary(grouping: players) { $0.householdTag ?? $0.id }
        for tag in byTag.keys.sorted() {
            for player in byTag[tag, default: []].prefix(3) {
                do {
                    let request = URLRequest(url: try Self.url(path: "/api/v1/players/local/info", host: player.host))
                    let info = try decoder.decode(PlayerInfo.self, from: try await perform(request))
                    if !households.contains(where: { $0.id == info.householdId }) {
                        households.append(Household(id: info.householdId, name: nil))
                    }
                    break
                } catch {
                    lastError = error
                }
            }
        }
        if households.isEmpty, let lastError {
            throw lastError
        }
        return try JSONEncoder().encode(HouseholdsResponse(households: households))
    }
}
