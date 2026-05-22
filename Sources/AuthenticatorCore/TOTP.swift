import Foundation
import CryptoKit

public enum OTPGenerator {
    public static func code(for account: OTPAccount, at date: Date = Date()) -> String {
        let counter: UInt64
        switch account.type {
        case .totp:
            let period = max(1, account.period)
            let epoch = max(0.0, date.timeIntervalSince1970)
            counter = UInt64(epoch) / UInt64(period)
        case .hotp:
            counter = account.counter
        }
        return generate(
            secret: account.secret,
            counter: counter,
            digits: account.digits,
            algorithm: account.algorithm
        )
    }

    public static func remainingSeconds(for account: OTPAccount, at date: Date = Date()) -> Double {
        guard account.type == .totp else { return 0 }
        let period = Double(max(1, account.period))
        let epoch = max(0.0, date.timeIntervalSince1970)
        return period - epoch.truncatingRemainder(dividingBy: period)
    }

    public static func progress(for account: OTPAccount, at date: Date = Date()) -> Double {
        guard account.type == .totp else { return 0 }
        let period = Double(max(1, account.period))
        return remainingSeconds(for: account, at: date) / period
    }

    private static func generate(
        secret: Data,
        counter: UInt64,
        digits: Int,
        algorithm: OTPAlgorithm
    ) -> String {
        var counterBE = counter.bigEndian
        let counterData = withUnsafeBytes(of: &counterBE) { Data($0) }
        let key = SymmetricKey(data: secret)

        let hmac: Data
        switch algorithm {
        case .sha1:
            hmac = Data(HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key))
        case .sha256:
            hmac = Data(HMAC<SHA256>.authenticationCode(for: counterData, using: key))
        case .sha512:
            hmac = Data(HMAC<SHA512>.authenticationCode(for: counterData, using: key))
        }

        let offset = Int(hmac[hmac.count - 1] & 0x0F)
        let truncated =
            (UInt32(hmac[offset] & 0x7F) << 24) |
            (UInt32(hmac[offset + 1] & 0xFF) << 16) |
            (UInt32(hmac[offset + 2] & 0xFF) << 8) |
            UInt32(hmac[offset + 3] & 0xFF)

        let clampedDigits = max(1, min(digits, 9))
        var modulus: UInt32 = 1
        for _ in 0..<clampedDigits { modulus *= 10 }
        let code = truncated % modulus
        return String(format: "%0\(clampedDigits)d", code)
    }
}
