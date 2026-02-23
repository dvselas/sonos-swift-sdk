//
//  AuthorizationView.swift
//  SonosSDK
//

import SwiftUI
import BetterSafariView

struct AuthorizationView: ViewModifier {
    @Binding var isPresented: Bool
    var url: URL
    var callbackURLScheme: String
    var sonosManager: SonosManager

    func body(content: Content) -> some View {
        content
        .webAuthenticationSession(isPresented: $isPresented) {
            WebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackURLScheme
            ) { callbackURL, error in
                guard let callbackURL else {
                    return
                }

                Task {
                    do {
                        try await sonosManager.handleAuthRedirect(url: callbackURL)
                    } catch {
                        print("[AuthorizationView] Authentication failed: \(error)")
                    }
                }
            }
            .prefersEphemeralWebBrowserSession(false)
        }
    }
}

public extension View {

    func sonosAuthorizationView(
        url: URL,
        isPresented: Binding<Bool>,
        callbackURLScheme: String = "sonos-sdk-example",
        sonosManager: SonosManager
    ) -> some View {
        self.modifier(
            AuthorizationView(
                isPresented: isPresented,
                url: url,
                callbackURLScheme: callbackURLScheme,
                sonosManager: sonosManager
            )
        )
    }
}
