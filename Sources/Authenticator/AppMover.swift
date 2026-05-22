import AppKit

/// 앱이 `/Applications` 또는 `~/Applications` 밖에서 실행되면 첫 실행 시
/// dialog를 띄우고 사용자가 동의하면 자기 자신을 그 위치로 복사한 뒤
/// 새 위치에서 재실행하고 현재 프로세스를 종료한다.
///
/// 옛 위치의 .app과 zip을 자동으로 휴지통으로 옮기는 동작은 macOS 16의 App Management
/// 정책에 막혀서 빼버렸다. 사용자가 직접 정리한다.
@MainActor
enum AppMover {
    static func moveToApplicationsIfNeeded() {
        let bundleURL = Bundle.main.bundleURL

        if isInApplicationsFolder(bundleURL) { return }
        // 마운트된 디스크 이미지(.dmg)에서 실행 중이면 LetsMove 대신
        // 사용자가 드래그로 옮기는 표준 흐름을 따른다.
        if bundleURL.path.hasPrefix("/Volumes/") { return }

        let target = preferredApplicationsFolder()
        let destination = target.appendingPathComponent(bundleURL.lastPathComponent)

        let alert = NSAlert()
        alert.messageText = "OTP Bar를 Applications 폴더로 옮기시겠습니까?"
        alert.informativeText = "메뉴바 앱은 \(target.path) 안에 두는 것이 권장됩니다.\n옮긴 뒤 자동으로 재실행됩니다."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Applications 폴더로 옮기기")
        alert.addButton(withTitle: "옮기지 않음")

        // LSUIElement 앱이라 default로 inactive — alert이 보이도록 활성화.
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            // 같은 위치에 이전 버전이 있다면 휴지통으로
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.trashItem(at: destination, resultingItemURL: nil)
            }
            try FileManager.default.copyItem(at: bundleURL, to: destination)
            // copyItem은 xattr까지 복사하므로 destination에 quarantine flag가 남는다.
            // 그대로 두면 새 instance 실행이 또 Gatekeeper에 막히므로 명시적으로 제거한다.
            removeQuarantine(at: destination)
            // 새 위치에서 재실행. 같은 bundle ID라 createsNewApplicationInstance=true가 없으면
            // macOS가 옛 instance를 활성화만 하고 새 process를 띄우지 않는다.
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            config.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: destination, configuration: config) { _, error in
                if let error {
                    DispatchQueue.main.async {
                        let a = NSAlert()
                        a.messageText = "이동 후 재실행에 실패했습니다."
                        a.informativeText = "\(error.localizedDescription)\n\n수동으로 \(destination.path)을(를) 열어주세요."
                        a.alertStyle = .warning
                        a.runModal()
                    }
                }
            }
            // 새 instance가 spawn되도록 잠시 대기 후 강제 종료.
            // NSApp.terminate(nil)은 applicationDidFinishLaunching 초기에 호출되면
            // NSApp 부트스트랩이 끝나지 않아 이상하게 동작할 수 있어서 exit(0)을 쓴다.
            RunLoop.current.run(until: Date().addingTimeInterval(1.5))
            exit(0)
        } catch {
            let errorAlert = NSAlert()
            errorAlert.messageText = "이동에 실패했습니다."
            errorAlert.informativeText = "\(error.localizedDescription)\n\n수동으로 Finder에서 \(bundleURL.lastPathComponent)을(를) Applications 폴더로 끌어다 놓아 주세요."
            errorAlert.alertStyle = .warning
            errorAlert.runModal()
        }
    }

    private static func isInApplicationsFolder(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let userApps = (NSHomeDirectory() as NSString).appendingPathComponent("Applications")
        return path.hasPrefix("/Applications/") || path.hasPrefix(userApps + "/")
    }

    private static func preferredApplicationsFolder() -> URL {
        let global = URL(fileURLWithPath: "/Applications")
        if FileManager.default.isWritableFile(atPath: global.path) {
            return global
        }
        // /Applications에 쓸 권한이 없으면 사용자 ~/Applications로 fallback
        let userApps = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications")
        try? FileManager.default.createDirectory(at: userApps, withIntermediateDirectories: true)
        return userApps
    }

    /// .app 안의 모든 파일에서 com.apple.quarantine 속성을 제거한다.
    /// (xattr -dr com.apple.quarantine <path> 와 동치)
    private static func removeQuarantine(at url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-dr", "com.apple.quarantine", url.path]
        process.standardOutput = nil
        process.standardError = nil
        try? process.run()
        process.waitUntilExit()
    }
}
