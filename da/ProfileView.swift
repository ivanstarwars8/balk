import SwiftUI

struct ProfileView: View {
    @Environment(\.theme) var t
    @EnvironmentObject var session: AuthSession
    @Environment(\.openURL) var openURL
    @State private var notificationsOn: Bool = true
    @State private var showDevices: Bool = false

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

                        GroupCard(label: "Аккаунт") {
                            RowItem(icon: "devices", title: "Устройства",
                                    value: devicesValue, accent: true, chev: true,
                                    onTap: { showDevices = true })
                            RowItem(icon: "key", title: "Сменить пароль", chev: true,
                                    onTap: openHomeLK)
                            RowItem(icon: "bell", title: "Уведомления", last: true,
                                    toggleOn: $notificationsOn)
                        }

                        GroupCard(label: "Приложение") {
                            RowItem(icon: "translate", title: "Язык",
                                    value: "Русский", chev: true)
                            RowItem(icon: "sparkle", title: "Тема",
                                    value: "Системная", last: true, chev: true)
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

                        Text("BADRIMGU · iOS 1.0.0 · ЛК")
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
        }
    }

    private var devicesValue: String {
        guard let s = session.subscription else { return "—" }
        return "\(s.devices_used ?? 0) / \(s.devices_limit ?? 0)"
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
                Text(planLine)
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

    private var planLine: String {
        guard let s = session.subscription else { return "—" }
        let plan = s.plan.map { "Premium · \($0)" } ?? "Premium"
        if let iso = s.expires_at,
           let date = ISO8601DateFormatter().date(from: iso) {
            let f = DateFormatter(); f.dateFormat = "dd.MM.yyyy"
            return "\(plan) · до \(f.string(from: date))"
        }
        return plan
    }

    private func openHomeLK() {
        Task {
            if let url = await session.lkSession(go: "home") {
                openURL(url)
            }
        }
    }
}
