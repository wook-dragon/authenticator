import SwiftUI
import AppKit
import AuthenticatorCore

struct MenuBarContentView: View {
    @EnvironmentObject var state: AppState
    @State private var showingAdd = false
    @State private var search = ""

    private var filtered: [OTPAccount] {
        guard !search.isEmpty else { return state.accounts }
        let q = search.lowercased()
        return state.accounts.filter {
            $0.issuer.lowercased().contains(q) || $0.name.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if !state.accounts.isEmpty {
                searchField
            }
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 380)
        .sheet(isPresented: $showingAdd) {
            AddAccountView(
                onComplete: { added in
                    let count = state.addAccounts(added)
                    showingAdd = false
                    if count == 0 && !added.isEmpty {
                        state.errorMessage = "이미 등록된 계정입니다."
                    }
                },
                onCancel: { showingAdd = false }
            )
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "key.fill")
                .foregroundStyle(.tint)
            Text("Authenticator")
                .font(.headline)
            Spacer()
            if let error = state.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(error)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("검색", text: $search)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var content: some View {
        if state.accounts.isEmpty {
            emptyState
        } else if filtered.isEmpty {
            VStack(spacing: 4) {
                Text("검색 결과 없음").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { account in
                        AccountRow(account: account)
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .frame(maxHeight: 440)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("등록된 계정이 없습니다")
                .font(.subheadline)
            Text("아래 ‘QR 추가’로 시작하세요")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var footer: some View {
        HStack {
            Button {
                showingAdd = true
            } label: {
                Label("QR 추가", systemImage: "qrcode.viewfinder")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            Spacer()

            Menu {
                Button("새로고침") { state.reload() }
                Divider()
                Button("종료") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct AccountRow: View {
    @EnvironmentObject var state: AppState
    let account: OTPAccount

    @State private var justCopied = false
    @State private var renaming = false
    @State private var editIssuer = ""
    @State private var editName = ""

    private var code: String {
        OTPGenerator.code(for: account, at: state.now)
    }

    private var remaining: Int {
        max(0, Int(OTPGenerator.remainingSeconds(for: account, at: state.now).rounded(.up)))
    }

    private var progress: Double {
        OTPGenerator.progress(for: account, at: state.now)
    }

    private var formattedCode: String {
        switch code.count {
        case 6: return "\(code.prefix(3)) \(code.suffix(3))"
        case 8: return "\(code.prefix(4)) \(code.suffix(4))"
        default: return code
        }
    }

    var body: some View {
        Button(action: copyCode) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.displayLabel)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(formattedCode)
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                        .foregroundStyle(remaining <= 5 ? .red : .primary)
                        .contentTransition(.numericText())
                }
                Spacer()
                if account.type == .totp {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 2)
                        Circle()
                            .trim(from: 0, to: CGFloat(progress))
                            .stroke(remaining <= 5 ? Color.red : Color.accentColor,
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(remaining)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 28, height: 28)
                }
                if justCopied {
                    Text("복사됨")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("코드 복사", action: copyCode)
            Button("이름 변경") {
                editIssuer = account.issuer
                editName = account.name
                renaming = true
            }
            Divider()
            Button("삭제", role: .destructive) {
                state.removeAccount(account)
            }
        }
        .sheet(isPresented: $renaming) {
            RenameSheet(
                issuer: $editIssuer,
                name: $editName,
                onSave: {
                    state.rename(account, issuer: editIssuer, name: editName)
                    renaming = false
                },
                onCancel: { renaming = false }
            )
        }
    }

    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        withAnimation(.easeOut(duration: 0.15)) {
            justCopied = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.2)) { justCopied = false }
            }
        }
    }
}

private struct RenameSheet: View {
    @Binding var issuer: String
    @Binding var name: String
    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("계정 이름 변경").font(.headline)
            Form {
                TextField("발급자(issuer)", text: $issuer)
                TextField("계정 이름", text: $name)
            }
            HStack {
                Spacer()
                Button("취소", action: onCancel)
                Button("저장", action: onSave).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
