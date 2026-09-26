//
//  SonosLiveNetworkObserver.swift
//  SonosSDK
//
//  Nudges the live client when the network path changes (Wi-Fi rejoined,
//  interface switched), so dead sockets reconnect at once instead of waiting
//  for their backoff and stale ones are verified.
//

import Foundation
#if canImport(Network)
import Network
#endif

final class SonosLiveNetworkObserver: @unchecked Sendable {

    private let lock = NSLock()
    #if canImport(Network)
    private var monitor: NWPathMonitor?
    private var lastSignature: String?
    #endif

    func start(onChange: @escaping @Sendable () -> Void) {
        #if canImport(Network)
        stop()
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let signature = "\(path.status)|" + path.availableInterfaces.map(\.name).joined(separator: ",")
            self.lock.lock()
            let previous = self.lastSignature
            self.lastSignature = signature
            self.lock.unlock()
            // The first callback only reports the current path.
            if previous != nil, previous != signature, path.status == .satisfied {
                onChange()
            }
        }
        lock.lock()
        self.monitor = monitor
        lock.unlock()
        monitor.start(queue: DispatchQueue(label: "com.sonos.sdk.network", qos: .utility))
        #endif
    }

    func stop() {
        #if canImport(Network)
        lock.lock()
        let monitor = self.monitor
        self.monitor = nil
        lastSignature = nil
        lock.unlock()
        monitor?.cancel()
        #endif
    }
}

extension SonosManager {

    func startNetworkObservation(for client: SonosLiveClient) {
        networkObserver.start {
            Task { await client.networkChanged() }
        }
    }

    func stopNetworkObservation() {
        networkObserver.stop()
    }
}
