import Foundation
import AVFoundation
import AppKit

@MainActor
public final class CameraQRScanner: NSObject {
    public enum ScanError: Error, CustomStringConvertible {
        case cameraAccessDenied
        case noCamera
        case cannotConfigureSession(String)

        public var description: String {
            switch self {
            case .cameraAccessDenied:
                return "카메라 접근이 거부되었습니다. 시스템 설정 > 개인정보 보호 및 보안 > 카메라에서 권한을 허용해 주세요."
            case .noCamera:
                return "사용 가능한 카메라를 찾을 수 없습니다."
            case .cannotConfigureSession(let reason):
                return "카메라 세션 구성 실패: \(reason)"
            }
        }
    }

    public typealias PayloadHandler = @MainActor (String) -> Void

    private let session = AVCaptureSession()
    private let sampleQueue = DispatchQueue(label: "kr.danbiedu.wook.Authenticator.camera.metadata")
    private let output = AVCaptureMetadataOutput()
    private var configured = false
    private var payloadHandler: PayloadHandler?

    /// AppKit 뷰에 직접 부착할 수 있는 미리보기 레이어.
    public let previewLayer: AVCaptureVideoPreviewLayer

    public override init() {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        self.previewLayer = layer
        super.init()
    }

    /// 카메라 권한을 요청하고 세션을 시작한다. QR 페이로드가 감지되면 `onPayload`로 전달.
    public func start(onPayload: @escaping PayloadHandler) async throws {
        self.payloadHandler = onPayload
        if !configured {
            try await configureSession()
            configured = true
        }
        if !session.isRunning {
            await Task.detached(priority: .userInitiated) { [session] in
                session.startRunning()
            }.value
        }
    }

    public func stop() {
        if session.isRunning {
            let session = self.session
            Task.detached(priority: .utility) {
                session.stopRunning()
            }
        }
        payloadHandler = nil
    }

    private func configureSession() async throws {
        let granted = await requestAuthorization()
        guard granted else { throw ScanError.cameraAccessDenied }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified)
                ?? AVCaptureDevice.default(for: .video) else {
            throw ScanError.noCamera
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            throw ScanError.cannotConfigureSession(error.localizedDescription)
        }

        session.beginConfiguration()
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw ScanError.cannotConfigureSession("입력을 추가할 수 없음")
        }
        session.addInput(input)

        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            throw ScanError.cannotConfigureSession("출력을 추가할 수 없음")
        }
        session.addOutput(output)

        // setMetadataObjectsDelegate -> metadataObjectTypes 순서가 필수.
        // availableMetadataObjectTypes는 commitConfiguration 이후에야 채워지므로
        // 여기서는 .qr을 바로 지정하고, commit 후에 실제로 등록되었는지 확인한다.
        output.setMetadataObjectsDelegate(self, queue: sampleQueue)
        output.metadataObjectTypes = [.qr]
        session.commitConfiguration()

        if !output.metadataObjectTypes.contains(.qr) {
            throw ScanError.cannotConfigureSession("이 카메라는 QR 메타데이터를 지원하지 않음")
        }
    }

    private func requestAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }
}

extension CameraQRScanner: AVCaptureMetadataOutputObjectsDelegate {
    public nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        let payloads = metadataObjects
            .compactMap { $0 as? AVMetadataMachineReadableCodeObject }
            .filter { $0.type == .qr }
            .compactMap { $0.stringValue }
        guard !payloads.isEmpty else { return }
        Task { @MainActor in
            for payload in payloads {
                self.payloadHandler?(payload)
            }
        }
    }
}
