//
//  SonosLocalTransport.swift
//  SonosSDK
//
//  One WebSocket to one player. All players share a single URLSession so the
//  footprint stays at one session, one delegate and one delegate queue no
//  matter how many speakers the household has.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A text WebSocket. Abstracted so the connection logic can be tested
/// without a network.
protocol SonosLocalTransport: AnyObject, Sendable {
    /// Performs the handshake. Throws if it fails; `close()` aborts it.
    func open() async throws
    func send(_ text: String) async throws
    func receive() async throws -> String
    func ping() async throws
    /// Idempotent. Makes pending `open`, `receive` and `ping` calls fail.
    func close()
}

protocol SonosLocalTransportFactory: Sendable {
    func makeTransport(url: URL, apiKey: String) -> any SonosLocalTransport
    /// The household's players by host: only they are trusted, each with
    /// its own certificate (see `SonosPlayerCertificate`).
    func setTrustedPlayers(_ playerIdsByHost: [String: String])
}

// MARK: - URLSession implementation

final class URLSessionSonosLocalTransportFactory: SonosLocalTransportFactory, @unchecked Sendable {

    private let delegate: SonosLocalSessionDelegate
    private let session: URLSession

    init(maximumMessageSize: Int = 4 * 1024 * 1024) {
        let delegate = SonosLocalSessionDelegate()
        let queue = OperationQueue()
        queue.name = "com.sonos.sdk.local"
        queue.maxConcurrentOperationCount = 1
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        self.delegate = delegate
        self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: queue)
        self.maximumMessageSize = maximumMessageSize
    }

    private let maximumMessageSize: Int

    func makeTransport(url: URL, apiKey: String) -> any SonosLocalTransport {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(apiKey, forHTTPHeaderField: SonosLocalAPI.apiKeyHeader)
        request.setValue(SonosLocalAPI.subprotocol, forHTTPHeaderField: "Sec-WebSocket-Protocol")
        // Players reject browser-originated connections; URLSession sends no Origin by default.
        let task = session.webSocketTask(with: request)
        task.maximumMessageSize = maximumMessageSize
        return URLSessionSonosLocalTransport(task: task, delegate: delegate)
    }

    func setTrustedPlayers(_ playerIdsByHost: [String: String]) {
        delegate.setTrustedPlayers(playerIdsByHost)
    }

    deinit {
        session.invalidateAndCancel()
    }
}

final class URLSessionSonosLocalTransport: SonosLocalTransport, @unchecked Sendable {

    private let task: URLSessionWebSocketTask
    private let delegate: SonosLocalSessionDelegate

    init(task: URLSessionWebSocketTask, delegate: SonosLocalSessionDelegate) {
        self.task = task
        self.delegate = delegate
    }

    func open() async throws {
        try await delegate.open(task)
    }

    func send(_ text: String) async throws {
        try await task.send(.string(text))
    }

    func receive() async throws -> String {
        switch try await task.receive() {
        case .string(let text):
            return text
        case .data(let data):
            return String(decoding: data, as: UTF8.self)
        @unknown default:
            throw SonosLocalError.invalidFrame
        }
    }

    private let lock = NSLock()
    private var pendingPings: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var isClosed = false

    func ping() async throws {
        let id = UUID()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            lock.lock()
            if isClosed {
                lock.unlock()
                continuation.resume(throwing: SonosLocalError.closed)
                return
            }
            pendingPings[id] = continuation
            lock.unlock()
            task.sendPing { [weak self] error in
                self?.resumePing(id, error: error)
            }
        }
    }

    private func resumePing(_ id: UUID, error: Error?) {
        lock.lock()
        let continuation = pendingPings.removeValue(forKey: id)
        lock.unlock()
        if let error {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume()
        }
    }

    func close() {
        lock.lock()
        isClosed = true
        let pings = pendingPings
        pendingPings.removeAll()
        lock.unlock()
        task.cancel(with: .goingAway, reason: nil)
        delegate.failOpen(task, with: SonosLocalError.closed)
        pings.values.forEach { $0.resume(throwing: SonosLocalError.closed) }
    }
}

// MARK: - Delegate

/// Resolves handshakes and checks the players' certificates.
final class SonosLocalSessionDelegate: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {

    private let lock = NSLock()
    private var trustedPlayers: [String: String] = [:]
    private var openWaiters: [Int: CheckedContinuation<Void, Error>] = [:]

    func setTrustedPlayers(_ playerIdsByHost: [String: String]) {
        lock.lock()
        trustedPlayers = Dictionary(playerIdsByHost.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { $1 })
        lock.unlock()
    }

    /// The player expected at `host`, if it is one of the household's on the local API port.
    func playerId(host: String, port: Int) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return port == SonosLocalAPI.port ? trustedPlayers[host.lowercased()] : nil
    }

    func open(_ task: URLSessionWebSocketTask) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            lock.lock()
            openWaiters[task.taskIdentifier] = continuation
            lock.unlock()
            task.resume()
        }
    }

    func failOpen(_ task: URLSessionTask, with error: Error) {
        resumeOpen(task, with: .failure(error))
    }

    private func resumeOpen(_ task: URLSessionTask, with result: Result<Void, Error>) {
        lock.lock()
        let waiter = openWaiters.removeValue(forKey: task.taskIdentifier)
        lock.unlock()
        waiter?.resume(with: result)
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        resumeOpen(webSocketTask, with: .success(()))
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        resumeOpen(webSocketTask, with: .failure(SonosLocalError.closed))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        resumeOpen(task, with: .failure(error ?? SonosLocalError.closed))
    }

    #if canImport(Security)
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        evaluate(challenge, completionHandler: completionHandler)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        evaluate(challenge, completionHandler: completionHandler)
    }

    /// Players present certificates issued by Sonos' private CA, which the
    /// system doesn't trust. Accept one only for this household's players
    /// on the local API port, and only if it is that player's certificate;
    /// everything else gets default handling.
    private func evaluate(_ challenge: URLAuthenticationChallenge,
                          completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let space = challenge.protectionSpace
        guard space.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = space.serverTrust,
              let playerId = playerId(host: space.host, port: space.port) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        guard SonosPlayerCertificate.matches(trust, playerId: playerId) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
    #endif
}
