//
//  SonosPlayerDiscovery.swift
//  SonosSDK
//
//  Finds the players on the local network over Bonjour (`_sonos._tcp`).
//  Every player announces its id (`uuid`), its address (`location`) and a
//  short form of its household's id (`hhid`) in its TXT record, so finding
//  them needs no request to a player.
//

import Foundation
#if canImport(Network)
import Network
#endif

/// A player announcing itself on the local network.
public struct SonosDiscoveredPlayer: Sendable, Hashable {
    /// `RINCON_…`
    public let id: String
    /// The room's name, e.g. "Kids Room".
    public let name: String
    /// The player's IP address.
    public let host: String
    /// The household as Bonjour announces it (`hhid`): the beginning of the
    /// Control API's household id, which continues after a dot.
    public let householdTag: String?

    public init(id: String, name: String, host: String, householdTag: String? = nil) {
        self.id = id
        self.name = name
        self.host = host
        self.householdTag = householdTag
    }

    /// From a Bonjour announcement: instance name `RINCON_…@Kids Room`, TXT
    /// `uuid`, `hhid` and `location` (`http://<ip>:1400/xml/device_description.xml`).
    public init?(instanceName: String, txt: [String: String]) {
        let parts = instanceName.split(separator: "@", maxSplits: 1).map(String.init)
        guard let id = txt["uuid"] ?? parts.first, id.hasPrefix("RINCON_"),
              let host = txt["location"].flatMap(URL.init(string:))?.host else { return nil }
        self.init(id: id, name: parts.count > 1 ? parts[1] : id, host: host, householdTag: txt["hhid"])
    }

    /// Whether the player announces itself as part of `householdId`.
    /// Players without a tag could belong to any household.
    public func belongs(to householdId: String) -> Bool {
        guard let householdTag else { return true }
        return householdId == householdTag || householdId.hasPrefix(householdTag + ".")
    }
}

/// Finds the players on the local network.
public protocol SonosPlayerDiscovering: AnyObject, Sendable {
    /// The players announcing themselves now. Waits up to `timeout` for the first one.
    func players(waitingUpTo timeout: Duration) async -> [SonosDiscoveredPlayer]
}

#if canImport(Network)
/// Browses `_sonos._tcp` from the first request on and keeps browsing, so
/// later requests answer at once. Apps need `_sonos._tcp` in
/// `NSBonjourServices` and an `NSLocalNetworkUsageDescription`: iOS asks for
/// access to the local network the first time.
public final class SonosBonjourDiscovery: SonosPlayerDiscovering, @unchecked Sendable {

    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.sonos.sdk.discovery")
    private var browser: NWBrowser?
    private var found: [String: SonosDiscoveredPlayer] = [:]

    public init() {}

    deinit {
        browser?.cancel()
    }

    public func players(waitingUpTo timeout: Duration) async -> [SonosDiscoveredPlayer] {
        startIfNeeded()
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while current.isEmpty, clock.now < deadline, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
        }
        return current
    }

    private var current: [SonosDiscoveredPlayer] {
        lock.lock()
        defer { lock.unlock() }
        return found.values.sorted { $0.id < $1.id }
    }

    private func startIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard browser == nil else { return }
        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: "_sonos._tcp", domain: "local."), using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.update(results)
        }
        browser.stateUpdateHandler = { [weak self, weak browser] state in
            guard let self, let browser else { return }
            switch state {
            case .failed, .cancelled:
                // iOS ends a browse now and then, e.g. in the background; the next request starts over.
                self.discard(browser)
            default:
                break
            }
        }
        browser.start(queue: queue)
        self.browser = browser
    }

    private func discard(_ browser: NWBrowser) {
        lock.lock()
        if self.browser === browser { self.browser = nil }
        lock.unlock()
        browser.cancel()
    }

    private func update(_ results: Set<NWBrowser.Result>) {
        let players = results.compactMap { result -> SonosDiscoveredPlayer? in
            guard case .service(let name, _, _, _) = result.endpoint,
                  case .bonjour(let record) = result.metadata else { return nil }
            return SonosDiscoveredPlayer(instanceName: name, txt: record.dictionary)
        }
        lock.lock()
        found = Dictionary(players.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        lock.unlock()
    }
}
#endif
