import XCTest
@testable import AuthenticatorCore

final class TOTPTests: XCTestCase {
    // RFC 6238 Appendix B 표준 테스트 벡터 (8 digits)
    private static let sha1Secret = Data("12345678901234567890".utf8)
    private static let sha256Secret = Data("12345678901234567890123456789012".utf8)
    private static let sha512Secret = Data("1234567890123456789012345678901234567890123456789012345678901234".utf8)

    private struct Vector {
        let time: TimeInterval
        let sha1: String
        let sha256: String
        let sha512: String
    }

    private static let vectors: [Vector] = [
        .init(time: 59,          sha1: "94287082", sha256: "46119246", sha512: "90693936"),
        .init(time: 1111111109,  sha1: "07081804", sha256: "68084774", sha512: "25091201"),
        .init(time: 1111111111,  sha1: "14050471", sha256: "67062674", sha512: "99943326"),
        .init(time: 1234567890,  sha1: "89005924", sha256: "91819424", sha512: "93441116"),
        .init(time: 2000000000,  sha1: "69279037", sha256: "90698825", sha512: "38618901"),
        .init(time: 20000000000, sha1: "65353130", sha256: "77737706", sha512: "47863826"),
    ]

    func testRFC6238SHA1() {
        let account = OTPAccount(
            issuer: "RFC",
            name: "sha1",
            secret: Self.sha1Secret,
            algorithm: .sha1,
            digits: 8,
            type: .totp,
            period: 30
        )
        for v in Self.vectors {
            let code = OTPGenerator.code(for: account, at: Date(timeIntervalSince1970: v.time))
            XCTAssertEqual(code, v.sha1, "t=\(v.time) sha1")
        }
    }

    func testRFC6238SHA256() {
        let account = OTPAccount(
            issuer: "RFC",
            name: "sha256",
            secret: Self.sha256Secret,
            algorithm: .sha256,
            digits: 8,
            type: .totp,
            period: 30
        )
        for v in Self.vectors {
            let code = OTPGenerator.code(for: account, at: Date(timeIntervalSince1970: v.time))
            XCTAssertEqual(code, v.sha256, "t=\(v.time) sha256")
        }
    }

    func testRFC6238SHA512() {
        let account = OTPAccount(
            issuer: "RFC",
            name: "sha512",
            secret: Self.sha512Secret,
            algorithm: .sha512,
            digits: 8,
            type: .totp,
            period: 30
        )
        for v in Self.vectors {
            let code = OTPGenerator.code(for: account, at: Date(timeIntervalSince1970: v.time))
            XCTAssertEqual(code, v.sha512, "t=\(v.time) sha512")
        }
    }

    func testRemainingSecondsAtBoundary() {
        let account = OTPAccount(issuer: "x", name: "y", secret: Data([1, 2, 3]), period: 30)
        // 시각 0에서는 남은 시간이 정확히 30초여야 함
        XCTAssertEqual(OTPGenerator.remainingSeconds(for: account, at: Date(timeIntervalSince1970: 0)), 30, accuracy: 0.001)
        XCTAssertEqual(OTPGenerator.remainingSeconds(for: account, at: Date(timeIntervalSince1970: 15)), 15, accuracy: 0.001)
        // 직전 epoch에서는 1초 이하 남음
        XCTAssertEqual(OTPGenerator.remainingSeconds(for: account, at: Date(timeIntervalSince1970: 29.5)), 0.5, accuracy: 0.001)
    }

    func testSixDigitsPadding() {
        // 만일 결과가 짧으면 앞자리에 0 패딩
        let account = OTPAccount(
            issuer: "x",
            name: "y",
            secret: Self.sha1Secret,
            algorithm: .sha1,
            digits: 6,
            type: .totp
        )
        let code = OTPGenerator.code(for: account, at: Date(timeIntervalSince1970: 59))
        XCTAssertEqual(code.count, 6)
        // RFC 표 8자리 "94287082"의 마지막 6자리
        XCTAssertEqual(code, "287082")
    }
}
