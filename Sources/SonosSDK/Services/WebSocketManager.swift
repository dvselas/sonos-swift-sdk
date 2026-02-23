//
//  WebSocketManager.swift
//  SonosSDK
//
//  Modernized with async/await and structured concurrency
//

import Foundation
import Combine

/// Manages a single WebSocket connection for real-time state updates from a Sonos player
public class WebSocketManager: NSObject, @unchecked Sendable {

    // MARK: - Public Properties

    /// Publisher for connection state changes (Combine)
    public let connectionStatePublisher = PassthroughSubject<ConnectionState, Never>()

    /// Publisher for received messages (Combine)
    public let messagePublisher = PassthroughSubject<WebSocketMessage, Never>()

    /// Current connection state
    @Published public private(set) var connectionState: ConnectionState = .disconnected

    // MARK: - Connection State

    public enum ConnectionState: Sendable {
        case disconnected
        case connecting
        case connected
        case reconnecting(attempt: Int)
        case failed(String)
    }

    // MARK: - Private Properties

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var reconnectionTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 5
    private let baseReconnectionDelay: TimeInterval = 2.0
    private let pingInterval: TimeInterval = 30.0
    private var websocketURL: URL?
    private var accessToken: String?

    // MARK: - Initialization

    public override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    // MARK: - Public Methods

    /// Connect to a WebSocket URL with authentication
    public func connect(to url: URL, accessToken: String? = nil) {
        switch connectionState {
        case .connected, .connecting:
            return
        default:
            break
        }

        self.websocketURL = url
        self.accessToken = accessToken
        self.reconnectAttempts = 0
        updateConnectionState(.connecting)
        establishConnection()
    }

    /// Disconnect from the WebSocket
    public func disconnect() {
        reconnectionTask?.cancel()
        reconnectionTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        pingTask?.cancel()
        pingTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        updateConnectionState(.disconnected)
    }

    /// Send a message through the WebSocket
    public func send(_ message: String) async throws {
        guard let webSocketTask else {
            throw SonosError.webSocketError(.connectionFailed("Not connected"))
        }
        try await webSocketTask.send(.string(message))
    }

    // MARK: - Private Methods

    private func establishConnection() {
        guard let url = websocketURL else {
            updateConnectionState(.failed("Invalid WebSocket URL"))
            return
        }

        var request = URLRequest(url: url)
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        webSocketTask = urlSession?.webSocketTask(with: request)
        webSocketTask?.resume()
        startReceiveLoop()
        startPingLoop()
    }

    private func startReceiveLoop() {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                guard let webSocketTask = self.webSocketTask else { break }

                do {
                    let message = try await webSocketTask.receive()
                    self.handleReceivedMessage(message)
                } catch {
                    if !Task.isCancelled {
                        self.handleConnectionError(error)
                    }
                    break
                }
            }
        }
    }

    private func handleReceivedMessage(_ message: URLSessionWebSocketTask.Message) {
        let text: String
        switch message {
        case .string(let str):
            text = str
        case .data(let data):
            guard let str = String(data: data, encoding: .utf8) else { return }
            text = str
        @unknown default:
            return
        }

        do {
            let wsMessage = try WebSocketMessage.parse(from: text)
            messagePublisher.send(wsMessage)
        } catch {
            print("[WebSocket] Failed to parse message: \(error)")
        }
    }

    private func handleConnectionError(_ error: Error) {
        pingTask?.cancel()
        receiveTask?.cancel()

        if reconnectAttempts < maxReconnectAttempts {
            updateConnectionState(.reconnecting(attempt: reconnectAttempts + 1))
            scheduleReconnection()
        } else {
            updateConnectionState(.failed(error.localizedDescription))
        }
    }

    private func scheduleReconnection() {
        reconnectionTask?.cancel()
        reconnectAttempts += 1

        let delay = baseReconnectionDelay * pow(2.0, Double(reconnectAttempts - 1)) // Exponential backoff
        reconnectionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.establishConnection()
        }
    }

    private func startPingLoop() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self?.pingInterval ?? 30) * 1_000_000_000)
                guard !Task.isCancelled else { break }
                self?.webSocketTask?.sendPing { error in
                    if let error {
                        print("[WebSocket] Ping failed: \(error)")
                        self?.handleConnectionError(error)
                    }
                }
            }
        }
    }

    private func updateConnectionState(_ newState: ConnectionState) {
        connectionState = newState
        connectionStatePublisher.send(newState)
        if case .connected = newState {
            reconnectAttempts = 0
        }
    }

    deinit {
        disconnect()
    }
}

// MARK: - URLSessionWebSocketDelegate

extension WebSocketManager: URLSessionWebSocketDelegate {

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        updateConnectionState(.connected)
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        if closeCode != .normalClosure {
            scheduleReconnection()
        } else {
            updateConnectionState(.disconnected)
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            handleConnectionError(error)
        }
    }
}

// MARK: - WebSocket Message Model

public struct WebSocketMessage: Sendable {
    public let namespace: String
    public let type: String
    public let groupId: String?
    public let playerId: String?
    public let data: [String: Any]

    static func parse(from jsonString: String) throws -> WebSocketMessage {
        guard let data = jsonString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SonosError.webSocketError(.invalidMessageFormat)
        }

        guard let namespace = json["namespace"] as? String,
              let type = json["type"] as? String else {
            throw SonosError.webSocketError(.missingRequiredFields)
        }

        return WebSocketMessage(
            namespace: namespace,
            type: type,
            groupId: json["groupId"] as? String,
            playerId: json["playerId"] as? String,
            data: json
        )
    }
}
