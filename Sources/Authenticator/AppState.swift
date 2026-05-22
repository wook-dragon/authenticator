import Foundation
import SwiftUI
import AuthenticatorCore

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var accounts: [OTPAccount] = []
    @Published var now: Date = Date()
    @Published var errorMessage: String?

    private let store: AccountStore
    private var ticker: Timer?

    init(store: AccountStore) {
        self.store = store
        reload()
        startTicker()
    }

    deinit {
        ticker?.invalidate()
    }

    func reload() {
        do {
            accounts = try store.load()
            errorMessage = nil
        } catch {
            errorMessage = "계정을 불러오지 못했습니다: \(error)"
        }
    }

    /// 새 계정 추가. 동일 issuer/name/secret이면 중복으로 보고 무시한다.
    @discardableResult
    func addAccounts(_ incoming: [OTPAccount]) -> Int {
        var merged = accounts
        var added = 0
        for account in incoming {
            let isDuplicate = merged.contains {
                $0.issuer == account.issuer && $0.name == account.name && $0.secret == account.secret
            }
            if isDuplicate { continue }
            merged.append(account)
            added += 1
        }
        guard added > 0 else { return 0 }
        accounts = merged
        persist()
        return added
    }

    func removeAccount(_ account: OTPAccount) {
        accounts.removeAll { $0.id == account.id }
        persist()
    }

    func rename(_ account: OTPAccount, issuer: String, name: String) {
        guard let idx = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[idx].issuer = issuer
        accounts[idx].name = name
        persist()
    }

    private func persist() {
        do {
            try store.save(accounts)
        } catch {
            errorMessage = "저장 실패: \(error)"
        }
    }

    private func startTicker() {
        ticker = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.now = Date()
            }
        }
    }
}
