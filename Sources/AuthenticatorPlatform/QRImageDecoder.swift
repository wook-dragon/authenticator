import Foundation
import Vision
import AppKit
import CoreImage

public enum QRImageDecoder {
    public enum Error: Swift.Error, CustomStringConvertible {
        case invalidImage
        case visionFailed(Swift.Error)
        case noQRFound

        public var description: String {
            switch self {
            case .invalidImage: return "이미지를 읽을 수 없습니다."
            case .visionFailed(let error): return "QR 분석 실패: \(error)"
            case .noQRFound: return "이미지에서 QR 코드를 찾지 못했습니다."
            }
        }
    }

    public static func decode(url: URL) throws -> [String] {
        guard let image = NSImage(contentsOf: url) else { throw Error.invalidImage }
        return try decode(image: image)
    }

    public static func decode(image: NSImage) throws -> [String] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw Error.invalidImage
        }
        return try decode(cgImage: cgImage)
    }

    public static func decode(cgImage: CGImage) throws -> [String] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw Error.visionFailed(error)
        }
        let payloads = (request.results ?? []).compactMap { $0.payloadStringValue }
        if payloads.isEmpty { throw Error.noQRFound }
        return payloads
    }
}
