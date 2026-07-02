import SwiftUI

struct ProfileView: View {
    @Environment(\.theme) var t
    @EnvironmentObject var session: AuthSession
    @Environment(\.openURL) var openURL
    @State private var showDevices: Bool = false
    @State private var showDiagnostics: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                IOSNav(title: "Профиль")

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        accountCard
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 18)

                        // "Язык"/"Тема"/"Уведомления" rows were decorative
                        // dead-ends (no real setting behind them) — dropped.
                        // Language follows the device locale since 1.0 (3).
                        GroupCard(label: "Аккаунт") {
                            RowItem(icon: "devices", title: "Устройства",
                                    accent: true, chev: true,
                                    onTap: { showDevices = true })
                            RowItem(icon: "key", title: "Сменить пароль", chev: true,
                                    onTap: openHomeLK)
                            RowItem(icon: "pulse", title: "Устранение неполадок",
                                    accent: true, last: true, chev: true,
                                    onTap: { showDiagnostics = true })
                        }

                        GroupCard(label: "Правовое") {
                            // No payments happen in the iOS app, so the refund
                            // policy is intentionally omitted here. Links point
                            // to the real document pages (the bare /offer path
                            // falls through to the marketing landing).
                            RowItem(icon: "doc", title: "Условия использования",
                                    trailing: AnyView(QXIcon(name: "link", size: 16, color: t.faint, weight: .medium)),
                                    onTap: { openURL(URL(string: "https://badrimgu.com/terms/")!) })
                            RowItem(icon: "shield", title: "Конфиденциальность", last: true,
                                    trailing: AnyView(QXIcon(name: "link", size: 16, color: t.faint, weight: .medium)),
                                    onTap: { openURL(URL(string: "https://badrimgu.com/privacy/")!) })
                        }

                        PrimaryButton(title: "Выйти", icon: "logout", kind: .secondary) {
                            Task { await session.logout() }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                        Text("BADRIMGU · iOS \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))")
                            .font(AppFont.mono(11))
                            .foregroundStyle(t.faint)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 8)
                    }
                }
            }
            .navigationDestination(isPresented: $showDevices) {
                DevicesView()
            }
            .navigationDestination(isPresented: $showDiagnostics) {
                DiagnosticsView()
            }
        }
    }

    private var accountCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(t.accentSoft)
                QXIcon(name: "user", size: 26, color: t.accent, weight: .medium)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.user?.email ?? "—")
                    .font(AppFont.ui(17, .semibold))
                    .foregroundStyle(t.text)
                Text("Личный аккаунт")
                    .font(AppFont.ui(13))
                    .foregroundStyle(t.muted)
            }
            Spacer()
        }
        .padding(16)
        .background(t.surface)
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(t.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func openHomeLK() {
        Task {
            if let url = await session.lkSession(go: "home") {
                openURL(url)
            }
        }
    }
}
