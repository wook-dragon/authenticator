import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers
import AuthenticatorCore
import AuthenticatorPlatform

struct AddAccountView: View {
    enum Mode: Hashable { case camera, file }

    var onComplete: ([OTPAccount]) -> Void
    var onCancel: () -> Void

    @State private var mode: Mode = .camera
    @State private var statusMessage: String?
    @State private var statusIsError = false
    @State private var hasResolved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("새 계정 추가")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("취소", action: onCancel)
                    .keyboardShortcut(.cancelAction)
            }

            Picker("입력 방식", selection: $mode) {
                Text("카메라").tag(Mode.camera)
                Text("이미지 파일").tag(Mode.file)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            footerText
        }
        .padding(16)
        .frame(width: 480, height: 520)
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .camera:
            CameraPreviewView(
                onPayload: handle(payload:),
                onError: { setStatus($0, isError: true) }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.3))
            )
        case .file:
            FileDropZone(onSelect: decodeFile(url:))
        }
    }

    @ViewBuilder
    private var footerText: some View {
        if let msg = statusMessage {
            Text(msg)
                .font(.callout)
                .foregroundStyle(statusIsError ? Color.red : Color.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(defaultHint)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var defaultHint: String {
        switch mode {
        case .camera:
            return "Google Authenticator → 우상단 메뉴 → 계정 내보내기에서 표시되는 QR 코드를 비추세요."
        case .file:
            return "QR 코드가 포함된 이미지 또는 스크린샷을 드롭하거나 클릭해서 선택하세요."
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

// MARK: - 카메라 미리보기

private struct CameraPreviewView: NSViewRepresentable {
    var onPayload: (String) -> Void
    var onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPayload: onPayload, onError: onError)
    }

    func makeNSView(context: Context) -> CameraHostView {
        let view = CameraHostView()
        view.attach(layer: context.coordinator.scanner.previewLayer)
        context.coordinator.startIfNeeded()
        return view
    }

    func updateNSView(_ nsView: CameraHostView, context: Context) {}

    static func dismantleNSView(_ nsView: CameraHostView, coordinator: Coordinator) {
        Task { @MainActor in coordinator.scanner.stop() }
    }

    @MainActor
    final class Coordinator {
        let scanner = CameraQRScanner()
        let onPayload: (String) -> Void
        let onError: (String) -> Void
        private var started = false

        init(onPayload: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onPayload = onPayload
            self.onError = onError
        }

        func startIfNeeded() {
            guard !started else { return }
            started = true
            Task { @MainActor in
                do {
                    try await scanner.start { [weak self] payload in
                        self?.onPayload(payload)
                    }
                } catch {
                    onError("\(error)")
                }
            }
        }
    }

    final class CameraHostView: NSView {
        private weak var preview: CALayer?

        func attach(layer: CALayer) {
            wantsLayer = true
            if self.layer == nil { self.layer = CALayer() }
            self.layer?.backgroundColor = NSColor.black.cgColor
            preview?.removeFromSuperlayer()
            layer.frame = bounds
            self.layer?.addSublayer(layer)
            preview = layer
        }

        override func layout() {
            super.layout()
            preview?.frame = bounds
        }
    }
}

// MARK: - 파일 드롭존

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
                    .font(.system(size: 40))
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
