//
//  SonosLiveStore+System.swift
//  SonosLive
//
//  Launch wiring: follow the Sonos sign-in state and the system lifecycle.
//  macOS closes the sockets for sleep; iOS drops them as soon as the app
//  goes to the background, so both reconnect when they come back.
//

import Combine
import Foundation
import SonosSDK
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

extension SonosLiveStore {

    /// Call once at launch. Connects whenever the user is signed in and
    /// live updates are enabled; disconnects on sign-out; closes the
    /// sockets for system sleep (macOS) or the background (iOS) and
    /// reopens them on wake or in the foreground.
    public func activate() {
        guard !isActivated else { return }
        isActivated = true

        let authentication = backend.authenticationPublisher
            .removeDuplicates()
            .sink { [weak self] isAuthenticated in
                Task { @MainActor in
                    guard let self else { return }
                    if isAuthenticated {
                        self.connect()
                    } else {
                        await self.disconnect()
                    }
                }
            }
        systemObservers.append(authentication)

        #if canImport(AppKit)
        let center = NSWorkspace.shared.notificationCenter
        let pause = center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.suspend() }
        }
        let wake = center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.resume() }
        }
        #elseif canImport(UIKit)
        let center = NotificationCenter.default
        let pause = center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.suspend() }
        }
        let wake = center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.resume() }
        }
        #endif
        #if canImport(AppKit) || canImport(UIKit)
        systemObservers.append(pause as AnyObject)
        systemObservers.append(wake as AnyObject)
        #endif
    }

    /// Applies a change of the "live updates" setting.
    public func liveUpdatesSettingChanged() {
        guard backend.isAuthenticated else { return }
        Task { await reconnect() }
    }
}
