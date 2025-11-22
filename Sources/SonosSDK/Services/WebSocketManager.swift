//
//  WebSocketManager.swift
//  SonosSDK
//
//  Created on 2025-01-22.
//

import Foundation
import Combine

/// Manages WebSocket connections for real-time state updates from Sonos players
public class WebSocketManager: NSObject {

    // MARK: - Public Properties

    /// Publisher for connection state changes
    public let connectionStatePublisher = PassthroughSubject<ConnectionState, Never>()

    /// Publisher for received messages
    public let messagePublisher = PassthroughSubject<WebSocketMessage, Never>()

    /// Current connection state
    @Published public private(set) var connectionState: ConnectionState = .disconnected

    // MARK: - Private Properties

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var reconnectionTimer: Timer?
    private var pingTimer: Timer?
    private let reconnectionDelay: TimeInterval = 3.0
    private let pingInterval: TimeInterval = 30.0
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 5
    private var websocketURL: URL?

    // MARK: - Connection State

    public enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case reconnecting(attempt: Int)
        case failed(Error)
    }

    // MARK: - Initialization

    public override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    // MARK: - Public Methods

    /// Connect to a WebSocket URL
    /// - Parameter url: The WebSocket URL from the Player model
    public func connect(to url: URL) {
        // Check if already connected or connecting
        switch connectionState {
        case .connected, .connecting:
            return
        default:
            break
        }

        self.websocketURL = url
        self.reconnectAttempts = 0
        updateConnectionState(.connecting)
        establishConnection()
    }

    /// Disconnect from the WebSocket
    public func disconnect() {
        cancelReconnectionTimer()
        cancelPingTimer()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        updateConnectionState(.disconnected)
    }

    /// Send a message through the WebSocket
    /// - Parameter message: The message to send
    public func send(_ message: String) {
        let message = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(message) { [weak self] error in
            if let error = error {
                print("WebSocket send error: \(error)")
                self?.handleConnectionError(error)
            }
        }
    }

    // MARK: - Private Methods

    private func establishConnection() {
        guard let url = websocketURL else {
            updateConnectionState(.failed(WebSocketError.invalidURL))
            return
        }

        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveMessage()
        startPingTimer()
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                self.handleReceivedMessage(message)
                self.receiveMessage() // Continue listening

            case .failure(let error):
                self.handleConnectionError(error)
            }
        }
    }

    private func handleReceivedMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            do {
                let wsMessage = try WebSocketMessage.parse(from: text)
                messagePublisher.send(wsMessage)
            } catch {
                print("Failed to parse WebSocket message: \(error)")
            }

        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                do {
                    let wsMessage = try WebSocketMessage.parse(from: text)
                    messagePublisher.send(wsMessage)
                } catch {
                    print("Failed to parse WebSocket data message: \(error)")
                }
            }

        @unknown default:
            break
        }
    }

    private func handleConnectionError(_ error: Error) {
        cancelPingTimer()

        if reconnectAttempts < maxReconnectAttempts {
            updateConnectionState(.reconnecting(attempt: reconnectAttempts + 1))
            scheduleReconnection()
        } else {
            updateConnectionState(.failed(error))
        }
    }

    private func scheduleReconnection() {
        cancelReconnectionTimer()
        reconnectAttempts += 1

        let delay = reconnectionDelay * Double(reconnectAttempts)
        reconnectionTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.establishConnection()
        }
    }

    private func cancelReconnectionTimer() {
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil
    }

    private func startPingTimer() {
        cancelPingTimer()
        pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func cancelPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    private func sendPing() {
        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                print("WebSocket ping failed: \(error)")
                self?.handleConnectionError(error)
            }
        }
    }

    private func updateConnectionState(_ newState: ConnectionState) {
        connectionState = newState
        connectionStatePublisher.send(newState)

        // Reset reconnect attempts on successful connection
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
        if let error = error {
            handleConnectionError(error)
        }
    }
}

// MARK: - WebSocket Message Model

public struct WebSocketMessage {
    public let namespace: String
    public let type: String
    public let groupId: String?
    public let playerId: String?
    public let data: [String: Any]

    static func parse(from jsonString: String) throws -> WebSocketMessage {
        guard let data = jsonString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WebSocketError.invalidMessageFormat
        }

        guard let namespace = json["namespace"] as? String,
              let type = json["type"] as? String else {
            throw WebSocketError.missingRequiredFields
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

// MARK: - WebSocket Error

public enum WebSocketError: LocalizedError {
    case invalidURL
    case invalidMessageFormat
    case missingRequiredFields
    case connectionFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid WebSocket URL"
        case .invalidMessageFormat:
            return "Invalid WebSocket message format"
        case .missingRequiredFields:
            return "WebSocket message missing required fields"
        case .connectionFailed(let error):
            return "WebSocket connection failed: \(error.localizedDescription)"
        }
    }
}
