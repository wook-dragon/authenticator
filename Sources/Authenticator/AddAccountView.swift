import SwiftUI
import AppKit
import UniformTypeIdentifiers
import AuthenticatorCore
import AuthenticatorPlatform

struct AddAccountView: View {
    var onComplete: ([OTPAccount]) -> Void
    var onCancel: () -> Void

    @State private var statusMessage: String?
    @State private var statusIsError = false
    @State private var hasResolved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("새 계정 추가")
                    .font(.headline)
                Spacer()
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }

            FileDropZone(onSelect: decodeFile(url:))
                .frame(height: 220)

            footerText
        }
        .padding(16)
        .frame(width: 380)
    }

    @ViewBuilder
    private var footerText: some View {
        if let msg = statusMessage {
            Text(msg)
                .font(.callout)
                .foregroundStyle(statusIsError ? Color.red : Color.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Google Authenticator → 우상단 메뉴 → ‘계정 내보내기’ 화면을 핸드폰에서 스크린샷한 뒤,")
                Text("이미지 파일을 드롭하거나 클릭해서 선택하세요.")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func handle(payload: String) {
        guard !hasResolved else { return }
        do {
            let accounts = try OTPURLParser.parseAny(payload)
            guard !accounts.isEmpty else {
                setStatus("QR에 계정 정보가 포함되어 있지 않습니다.", isError: true)
                return
            }
            hasResolved = true
            onComplete(accounts)
        } catch {
            setStatus("QR 형식을 해석하지 못했습니다.", isError: true)
        }
    }

    private func decodeFile(url: URL) {
        do {
            let payloads = try QRImageDecoder.decode(url: url)
            for payload in payloads {
                handle(payload: payload)
                if hasResolved { return }
            }
            if !hasResolved {
                setStatus("이미지에서 유효한 OTP QR을 찾지 못했습니다.", isError: true)
            }
        } catch {
            setStatus("이미지 처리 실패: \(error)", isError: true)
        }
    }

    private func setStatus(_ message: String, isError: Bool) {
        statusMessage = message
        statusIsError = isError
    }
}

// MARK: - 이미지 파일 드롭존

private struct FileDropZone: View {
    var onSelect: (URL) -> Void
    @State private var isHovering = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(isHovering ? 0.18 : 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                        )
                        .foregroundStyle(isHovering ? Color.accentColor : Color.secondary.opacity(0.5))
                )
            VStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("이미지를 끌어다 놓으세요")
                    .font(.subheadline)
                Text("또는 클릭해서 파일 선택")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: pickFile)
        .onDrop(of: [.fileURL, .image], isTargeted: $isHovering, perform: handleDrop)
    }

    private func pickFile() {
        // LSUIElement 앱은 시작 시 inactive라 NSOpenPanel을 그냥 띄우면 클릭이 안 먹는다.
        // 사용자 명령으로 panel을 띄우는 시점에 앱을 명시적으로 활성화한다.
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            onSelect(url)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let resolved: URL? = {
                if let url = item as? URL { return url }
                if let data = item as? Data { return URL(dataRepresentation: data, relativeTo: nil) }
                if let str = item as? String { return URL(string: str) }
                return nil
            }()
            if let url = resolved {
                Task { @MainActor in onSelect(url) }
            }
        }
        return true
    }
}
