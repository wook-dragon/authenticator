import Foundation

public enum OTPAlgorithm: String, Codable, Sendable, CaseIterable {
    case sha1
    case sha256
    case sha512
}

public enum OTPType: String, Codable, Sendable, CaseIterable {
    case totp
    case hotp
}

public struct OTPAccount: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var issuer: String
    public var name: String
    public var secret: Data
    public var algorithm: OTPAlgorithm
    public var digits: Int
    public var type: OTPType
    public var counter: UInt64
    public var period: Int

    public init(
        id: UUID = UUID(),
        issuer: String,
        name: String,
        secret: Data,
        algorithm: OTPAlgorithm = .sha1,
        digits: Int = 6,
        type: OTPType = .totp,
        counter: UInt64 = 0,
        period: Int = 30
    ) {
        self.id = id
        self.issuer = issuer
        self.name = name
        self.secret = secret
        self.algorithm = algorithm
        self.digits = digits
        self.type = type
        self.counter = counter
        self.period = period
    }

    public var displayLabel: String {
        if issuer.isEmpty { return name.isEmpty ? "(이름 없음)" : name }
        if name.isEmpty { return issuer }
        return "\(issuer) — \(name)"
    }
}
