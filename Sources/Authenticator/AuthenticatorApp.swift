import SwiftUI
import AuthenticatorCore
import AuthenticatorPlatform

@main
struct AuthenticatorApp: App {
    @StateObject private var state = AppState(store: KeychainAccountStore())

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(state)
        } label: {
            Image(systemName: "key.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
