import AppKit

// NSApp 관련 작업은 모두 main thread에서 일어나야 하므로 MainActor 격리 안에서 실행한다.
// AppDelegate가 @MainActor라 init도 격리 안에서 호출해야 한다.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
