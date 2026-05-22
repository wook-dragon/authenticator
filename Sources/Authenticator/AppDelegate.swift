import AppKit
import SwiftUI
import AuthenticatorCore
import AuthenticatorPlatform

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState(store: KeychainAccountStore())
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // /Applications 밖에서 띄운 경우 자동 이동 제안. 사용자가 동의하면
        // 이 호출 안에서 새 위치에서 재실행되고 현재 프로세스는 종료된다.
        AppMover.moveToApplicationsIfNeeded()
        configureStatusItem()
        configurePopover()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "lock.rotation", accessibilityDescription: "OTP Bar")
        button.action = #selector(togglePopover(_:))
        button.target = self
    }

    private func configurePopover() {
        let content = MenuBarContentView().environmentObject(appState)
        let host = NSHostingController(rootView: content)
        host.sizingOptions = [.preferredContentSize]

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = host
        self.popover = popover
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
