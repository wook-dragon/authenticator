import Foundation

public enum OTPURLParser {
    public enum Error: Swift.Error, Equatable {
        case invalidURL
        case unsupportedScheme
        case missingDataParameter
        case invalidBase64
        case missingSecret
        case malformedPayload
    }

    public static func parseAny(_ urlString: String) throws -> [OTPAccount] {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("otpauth-migration://") {
            return try parseMigration(trimmed)
        } else if trimmed.hasPrefix("otpauth://") {
            return [try parseSingle(trimmed)]
        } else {
            throw Error.unsupportedScheme
        }
    }

    public static func parseMigration(_ urlString: String) throws -> [OTPAccount] {
        guard let url = URL(string: urlString),
              url.scheme == "otpauth-migration" else {
            throw Error.invalidURL
        }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let dataValue = components?.queryItems?.first(where: { $0.name == "data" })?.value,
              !dataValue.isEmpty else {
            throw Error.missingDataParameter
        }
        guard let payload = decodeBase64Flexible(dataValue) else {
            throw Error.invalidBase64
        }
        return try decodeMigrationPayload(payload)
    }

    public static func parseSingle(_ urlString: String) throws -> OTPAccount {
        guard let url = URL(string: urlString),
              url.scheme == "otpauth",
              let host = url.host?.lowercased() else {
            throw Error.invalidURL
        }
        let type: OTPType
        switch host {
        case "totp": type = .totp
        case "hotp": type = .hotp
        default: throw Error.unsupportedScheme
        }

        let label = (url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path)
            .removingPercentEncoding ?? ""
        var issuer = ""
        var name = label
        if let colonIdx = label.firstIndex(of: ":") {
            issuer = String(label[..<colonIdx]).trimmingCharacters(in: .whitespaces)
            name = String(label[label.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
        }

        var secretRaw: String?
        var algorithm: OTPAlgorithm = .sha1
        var digits = 6
        var period = 30
        var counter: UInt64 = 0

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        for item in components?.queryItems ?? [] {
            switch item.name.lowercased() {
            case "secret":
                secretRaw = item.value
            case "issuer":
                if let v = item.value, !v.isEmpty { issuer = v }
            case "algorithm":
                switch item.value?.uppercased() {
                case "SHA256": algorithm = .sha256
                case "SHA512": algorithm = .sha512
                default: algorithm = .sha1
                }
            case "digits":
                if let v = item.value, let n = Int(v) { digits = n }
            case "period":
                if let v = item.value, let n = Int(v) { period = n }
            case "counter":
                if let v = item.value, let n = UInt64(v) { counter = n }
            default:
                break
            }
        }

        guard let secretBase32 = secretRaw, !secretBase32.isEmpty else {
            throw Error.missingSecret
        }
        let secret: Data
        do {
            secret = try Base32.decode(secretBase32)
        } catch {
            throw Error.malformedPayload
        }
        return OTPAccount(
            issuer: issuer,
            name: name,
            secret: secret,
            algorithm: algorithm,
            digits: digits,
            type: type,
            counter: counter,
            period: period
        )
    }

    // MARK: - 내부 디코딩

    private static func decodeBase64Flexible(_ s: String) -> Data? {
        var padded = s
        while padded.count % 4 != 0 { padded.append("=") }
        if let d = Data(base64Encoded: padded) { return d }
        let urlSafe = padded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        return Data(base64Encoded: urlSafe)
    }

    private static func decodeMigrationPayload(_ data: Data) throws -> [OTPAccount] {
        var reader = ProtobufReader(data)
        var accounts: [OTPAccount] = []
        while !reader.isAtEnd {
            let tag = try reader.readVarint()
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x7)
            switch (fieldNumber, wireType) {
            case (1, 2):
                let bytes = try reader.readLengthDelimited()
                accounts.append(try decodeOtpParameters(bytes))
            default:
                try reader.skipField(wireType: wireType)
            }
        }
        return accounts
    }

    private static func decodeOtpParameters(_ data: Data) throws -> OTPAccount {
        var reader = ProtobufReader(data)
        var secret = Data()
        var name = ""
        var issuer = ""
        var algorithmRaw: UInt64 = 1
        var digitsRaw: UInt64 = 1
        var typeRaw: UInt64 = 2
        var counter: UInt64 = 0

        while !reader.isAtEnd {
            let tag = try reader.readVarint()
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x7)
            switch (fieldNumber, wireType) {
            case (1, 2): secret = try reader.readLengthDelimited()
            case (2, 2):
                let raw = try reader.readLengthDelimited()
                name = String(data: raw, encoding: .utf8) ?? ""
            case (3, 2):
                let raw = try reader.readLengthDelimited()
                issuer = String(data: raw, encoding: .utf8) ?? ""
            case (4, 0): algorithmRaw = try reader.readVarint()
            case (5, 0): digitsRaw = try reader.readVarint()
            case (6, 0): typeRaw = try reader.readVarint()
            case (7, 0): counter = try reader.readVarint()
            default:
                try reader.skipField(wireType: wireType)
            }
        }

        let algorithm: OTPAlgorithm
        switch algorithmRaw {
        case 2: algorithm = .sha256
        case 3: algorithm = .sha512
        default: algorithm = .sha1
        }
        let digits: Int = (digitsRaw == 2) ? 8 : 6
        let type: OTPType = (typeRaw == 1) ? .hotp : .totp

        return OTPAccount(
            issuer: issuer,
            name: name,
            secret: secret,
            algorithm: algorithm,
            digits: digits,
            type: type,
            counter: counter,
            period: 30
        )
    }
}
