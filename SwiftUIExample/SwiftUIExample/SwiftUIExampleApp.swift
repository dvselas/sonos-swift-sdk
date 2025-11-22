//
//  SwiftUIExampleApp.swift
//  SwiftUIExample
//
//  Created by James Hickman on 2/21/21.
//

import SwiftUI
import SonosSDK
import Swinject

struct SonosConfiguration {

    static let keyName = "default"
    static let key = "f79521cc-5f45-4da4-bf0d-82f2382fad71"
    static let secret = "a624f024-2e8e-4db9-954f-515aad07771f"
    static let redirectURI = "sonos-swift-sdk://authorize"
    static let callbackURL = "your-webhook-api-url"

}

@main
struct SwiftUIExampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ExampleListView()
                .accentColor(Color.theme)
                .onAppear(perform: {
                    UIApplication.shared.addTapGestureRecognizer()
                })
        }
    }

}

class AppDelegate: NSObject, UIApplicationDelegate {
    let container: Container = Container()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Register a new Sonos Manager
        let sonosManager = SonosManager(keyName: SonosConfiguration.keyName,
                                        key: SonosConfiguration.key,
                                        secret: SonosConfiguration.secret,
                                        redirectURI: SonosConfiguration.redirectURI,
                                        callbackURL: SonosConfiguration.callbackURL)
        ConfigurationProvider.shared.container.register(SonosManager.self) { _ in sonosManager }

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        debugPrint("[DEBUG] applicationDidEnterBackground...")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        debugPrint("[DEBUG] applicationDidBecomeActive...")
    }

    private func updateAppearance() {
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: Color.theme]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: Color.theme]
        UISwitch.appearance().onTintColor = UIColor(Color.theme)
    }
}

class ConfigurationProvider {

    static let shared = ConfigurationProvider()

    let container = Container()

    private init() {}

    func register<T>(_ interface: T.Type, to assembly: T) {
        container.register(interface) { _ in assembly }
    }

    func resolve<T>(_ interface: T.Type) -> T! {
        return container.resolve(interface)
    }

}
