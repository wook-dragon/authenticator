import Foundation
import Security
import AuthenticatorCore

public final class KeychainAccountStore: AccountStore {
    public enum KeychainError: Error, CustomStringConvertible {
        case osStatus(OSStatus)
        case decodingFailed(Error)
        case encodingFailed(Error)

        public var description: String {
            switch self {
            case .osStatus(let status):
                let msg = SecCopyErrorMessageString(status, nil) as String? ?? "알 수 없는 Keychain 오류"
                return "Keychain 오류 (\(status)): \(msg)"
            case .decodingFailed(let error):
                return "Keychain 데이터 디코딩 실패: \(error)"
            case .encodingFailed(let error):
                return "Keychain 데이터 인코딩 실패: \(error)"
            }
        }
    }

    private let service: String
    private let account: String

    public init(
        service: String = "kr.danbiedu.wook.Authenticator",
        account: String = "accounts"
    ) {
        self.service = service
        self.account = account
    }

    public func load() throws -> [OTPAccount] {
        var query: [String: Any] = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.osStatus(status)
        }
        do {
            return try JSONDecoder().decode([OTPAccount].self, from: data)
        } catch {
            throw KeychainError.decodingFailed(error)
        }
    }

    public func save(_ accounts: [OTPAccount]) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(accounts)
        } catch {
            throw KeychainError.encodingFailed(error)
        }

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        if updateStatus == errSecItemNotFound {
            var addAttributes = baseQuery
            addAttributes.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(addAttributes as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.osStatus(addStatus) }
            return
        }
        throw KeychainError.osStatus(updateStatus)
    }

    public func reset() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.osStatus(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
