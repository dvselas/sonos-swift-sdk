//
//  SonosLocalConnection.swift
//  SonosSDK
//
//  Keeps one WebSocket to one player alive: connect, keepalive pings,
//  command/reply correlation, and reconnect with capped exponential backoff.
//  Subscriptions are owned by `SonosLiveClient`, which re-issues them after
//  every reconnect.
//

import Foundation

/// Tuning for live updates. The defaults keep idle traffic to one ping per
/// player every 45 s.
public struct SonosLiveConfiguration: Sendable {
    /// Seconds to wait for a command's reply.
    public var commandTimeout: TimeInterval
    /// Seconds to wait for loading a favorite or Sonos playlist in local-only
    /// mode: a playlist with thousands of tracks keeps the player busy for a while.
    public var loadTimeout: TimeInterval
    /// Seconds to wait for the WebSocket handshake.
    public var connectTimeout: TimeInterval
    /// Seconds between keepalive pings on an idle connection.
    public var pingInterval: TimeInterval
    /// First reconnect delay; doubles per failed attempt.
    public var initialReconnectDelay: TimeInterval
    /// Upper bound for the reconnect delay (players that are off stay cheap).
    public var maxReconnectDelay: TimeInterval
    /// Seconds before a failed subscription is retried.
    public var subscriptionRetryDelay: TimeInterval
    /// Receives diagnostic lines. `nil` disables logging.
    public var logger: (@Sendable (String) -> Void)?
    /// Also log every raw frame (verbose).
    public var traceFrames: Bool
    /// Where the app receives its integration's events. When set, live updates
    /// run through the Sonos cloud (`SonosCloudLiveClient`) instead of the
    /// players' local sockets, which published apps may not use.
    public var eventRelay: (any SonosEventRelaying)?
    /// The players the app shows; cloud live updates subscribe only to them
    /// and their groups. `nil` follows the whole household.
    public var focusPlayerIds: Set<String>?

    public init(
        commandTimeout: TimeInterval = 5,
        connectTimeout: TimeInterval = 10,
        pingInterval: TimeInterval = 45,
        initialReconnectDelay: TimeInterval = 1,
        maxReconnectDelay: TimeInterval = 60,
        subscriptionRetryDelay: TimeInterval = 15,
        logger: (@Sendable (String) -> Void)? = nil,
        traceFrames: Bool = false,
        eventRelay: (any SonosEventRelaying)? = nil,
        focusPlayerIds: Set<String>? = nil,
        loadTimeout: TimeInterval = 20
    ) {
        self.commandTimeout = commandTimeout
        self.loadTimeout = loadTimeout
        self.connectTimeout = connectTimeout
        self.pingInterval = pingInterval
        self.initialReconnectDelay = initialReconnectDelay
        self.maxReconnectDelay = maxReconnectDelay
        self.subscriptionRetryDelay = subscriptionRetryDelay
        self.logger = logger
        self.traceFrames = traceFrames
        self.eventRelay = eventRelay
        self.focusPlayerIds = focusPlayerIds
    }
}

/// State of one player connection.
public enum SonosLiveConnectionState: Sendable, Equatable {
    case connecting
    case connected
    /// Waiting before the next attempt; `retryIn` is nil when not retrying.
    case disconnected(retryIn: TimeInterval?)
    /// Paused on purpose (system sleep); `resume()` reconnects.
    case suspended

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

enum SonosLocalConnectionOutput: Sendable {
    case state(SonosLiveConnectionState)
    case event(SonosLocalHeader, frame: Data)
}

actor SonosLocalConnection {

    nonisolated let playerId: String
    nonisolated let outputs: AsyncStream<SonosLocalConnectionOutput>

    private let outputContinuation: AsyncStream<SonosLocalConnectionOutput>.Continuation
    private let apiKey: String
    private let factory: any SonosLocalTransportFactory
    private let configuration: SonosLiveConfiguration

    private(set) var url: URL
    private(set) var state: SonosLiveConnectionState = .disconnected(retryIn: nil)
    private var transport: (any SonosLocalTransport)?
    private var runTask: Task<Void, Never>?
    private var pending: [String: CheckedContinuation<Data, Error>] = [:]
    private var timeouts: [String: Task<Void, Never>] = [:]
    private var failedAttempts = 0
    private var nextCommandId = 0

    init(playerId: String, url: URL, apiKey: String, factory: any SonosLocalTransportFactory, configuration: SonosLiveConfiguration) {
        self.playerId = playerId
        self.url = url
        self.apiKey = apiKey
        self.factory = factory
        self.configuration = configuration
        var continuation: AsyncStream<SonosLocalConnectionOutput>.Continuation!
        self.outputs = AsyncStream(bufferingPolicy: .unbounded) { continuation = $0 }
        self.outputContinuation = continuation
    }

    // MARK: Lifecycle

    /// Starts connecting (no-op while already running).
    func start() {
        guard runTask == nil else { return }
        runTask = Task { [weak self] in await self?.run() }
    }

    /// Closes the socket and stops reconnecting. `finish` ends `outputs`.
    func stop(finish: Bool = false) {
        halt(as: .disconnected(retryIn: nil))
        if finish { outputContinuation.finish() }
    }

    /// Closes the socket until `resume()` (system sleep).
    func suspend() {
        halt(as: .suspended)
    }

    /// Reconnects at once if the connection is down or waiting to retry.
    func reconnectNow() {
        guard !state.isConnected else { return }
        if case .connecting = state { return }
        halt(as: state)
        failedAttempts = 0
        start()
    }

    /// Points the connection at a new address (player got a new IP).
    func update(url newURL: URL) {
        guard newURL != url else { return }
        url = newURL
        guard runTask != nil else { return }
        if state.isConnected {
            // The run loop notices the closed socket and reconnects to the new URL.
            transport?.close()
        } else {
            reconnectNow()
        }
    }

    /// Verifies a connection that looks healthy (e.g. after a network change).
    func probe() async {
        guard state.isConnected, let transport else { return }
        do {
            try await withWatchdog(configuration.connectTimeout, closing: transport) {
                try await transport.ping()
            }
        } catch {
            log("ping after network change failed: \(error.localizedDescription)")
            transport.close()
        }
    }

    private func halt(as newState: SonosLiveConnectionState) {
        runTask?.cancel()
        runTask = nil
        transport?.close()
        transport = nil
        failAllPending(.closed)
        setState(newState)
    }

    // MARK: Commands

    /// Sends a command and returns the raw reply frame.
    func send(_ command: SonosLocalCommand) async throws -> Data {
        guard state.isConnected, let transport else { throw SonosLocalError.notConnected }
        nextCommandId += 1
        let cmdId = "\(nextCommandId)"
        let text = try SonosLocalFrameCodec.encode(command, cmdId: cmdId)
        trace("→ \(text)")

        return try await withCheckedThrowingContinuation { continuation in
            pending[cmdId] = continuation
            let timeout = command.timeout ?? configuration.commandTimeout
            timeouts[cmdId] = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self?.complete(cmdId, with: .failure(SonosLocalError.timeout))
            }
            Task { [weak self] in
                do {
                    try await transport.send(text)
                } catch {
                    await self?.complete(cmdId, with: .failure(SonosLocalError.notConnected))
                }
            }
        }
    }

    private func complete(_ cmdId: String, with result: Result<Data, Error>) {
        timeouts.removeValue(forKey: cmdId)?.cancel()
        pending.removeValue(forKey: cmdId)?.resume(with: result)
    }

    private func failAllPending(_ error: SonosLocalError) {
        let waiting = pending
        pending.removeAll()
        timeouts.values.forEach { $0.cancel() }
        timeouts.removeAll()
        waiting.values.forEach { $0.resume(throwing: error) }
    }

    // MARK: Run loop

    private func run() async {
        while !Task.isCancelled {
            setState(.connecting)
            let transport = factory.makeTransport(url: url, apiKey: apiKey)
            self.transport = transport

            do {
                try await withWatchdog(configuration.connectTimeout, closing: transport) {
                    try await transport.open()
                }
                guard !Task.isCancelled else { break }
                failedAttempts = 0
                setState(.connected)
                log("connected to \(url.host ?? url.absoluteString)")

                let pinger = Task { [weak self] in await self?.pingLoop(transport) }
                defer { pinger.cancel() }
                try await receiveLoop(transport)
            } catch {
                if !Task.isCancelled {
                    log("connection lost: \(error.localizedDescription)")
                }
            }

            transport.close()
            // A cancelled loop has already been superseded (halt/reconnect):
            // the shared state belongs to the new loop, so leave it alone.
            guard !Task.isCancelled else { break }
            if self.transport === transport {
                self.transport = nil
            }
            failAllPending(.notConnected)

            failedAttempts += 1
            let delay = reconnectDelay(forAttempt: failedAttempts)
            setState(.disconnected(retryIn: delay))
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }

    private func receiveLoop(_ transport: any SonosLocalTransport) async throws {
        while !Task.isCancelled {
            let text = try await transport.receive()
            trace("← \(text)")
            let inbound: SonosLocalInbound
            do {
                inbound = try SonosLocalFrameCodec.classify(text)
            } catch {
                log("dropped unreadable frame")
                continue
            }
            switch inbound {
            case .reply(let cmdId, let result):
                complete(cmdId, with: result.mapError { $0 as Error })
            case .event(let header, let frame):
                outputContinuation.yield(.event(header, frame: frame))
            case .ignored:
                break
            }
        }
    }

    private func pingLoop(_ transport: any SonosLocalTransport) async {
        let interval = configuration.pingInterval
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            do {
                try await withWatchdog(configuration.connectTimeout, closing: transport) {
                    try await transport.ping()
                }
            } catch {
                log("keepalive failed; reconnecting")
                transport.close()
                return
            }
        }
    }

    /// Delay before reconnect attempt `attempt` (1-based): 1, 2, 4 … capped, ±20 % jitter.
    func reconnectDelay(forAttempt attempt: Int) -> TimeInterval {
        let exponent = Double(max(attempt - 1, 0))
        let base = min(configuration.initialReconnectDelay * pow(2, exponent), configuration.maxReconnectDelay)
        return base * Double.random(in: 0.8...1.2)
    }

    // MARK: Helpers

    private func setState(_ newState: SonosLiveConnectionState) {
        guard newState != state else { return }
        state = newState
        outputContinuation.yield(.state(newState))
    }

    /// Runs `operation`; if it takes longer than `seconds`, closes the
    /// transport so the operation fails instead of hanging.
    private func withWatchdog<T: Sendable>(
        _ seconds: TimeInterval,
        closing transport: any SonosLocalTransport,
        _ operation: () async throws -> T
    ) async throws -> T {
        let watchdog = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            transport.close()
        }
        defer { watchdog.cancel() }
        return try await operation()
    }

    private func log(_ message: String) {
        configuration.logger?("[Sonos WS] \(playerId): \(message)")
    }

    private func trace(_ message: String) {
        guard configuration.traceFrames else { return }
        configuration.logger?("[Sonos WS] \(playerId) \(message)")
    }
}
