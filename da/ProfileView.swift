import SwiftUI

struct ProfileView: View {
    @Environment(\.theme) var t
    @EnvironmentObject var session: AuthSession
    @Environment(\.openURL) var openURL
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

                        // Backend-managed notice board (moved here from the
                        // Connect tab in build 18 — Connect stays purely about
                        // installing + importing).
                        if !session.notices.isEmpty {
                            VStack(spacing: 14) {
                                ForEach(session.notices) { n in
                                    noticeCard(n)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 18)
                        }

                        // "Язык"/"Тема"/"Уведомления" rows were decorative
                        // dead-ends (no real setting behind them) — dropped.
                        // Language follows the device locale since 1.0 (3).
                        GroupCard(label: "Аккаунт") {
                            RowItem(icon: "devices", title: "Устройства",
                                    accent: true, chev: true,
                                    onTap: { showDevices = true })
                            RowItem(icon: "key", title: "Сменить пароль", last: true, chev: true,
                                    onTap: openHomeLK)
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
        }
        .task {
            await session.loadNotices()
        }
        .refreshable {
            await session.loadNotices()
        }
    }

    /// Backend-managed notice: text arrives already localized; the optional
    /// button either opens a plain URL or — for "lk:<go>" — mints a magic-login
    /// and opens the web cabinet signed in.
    private func noticeCard(_ n: Notice) -> some View {
        let (icon, tint): (String, Color) = {
            switch n.kind {
            case "warn":    return ("clock", t.warn)
            case "success": return ("check", t.success)
            default:        return ("bell", t.accent)
            }
        }()
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(tint.opacity(0.16))
                        .frame(width: 36, height: 36)
                    QXIcon(name: icon, size: 18, color: tint, weight: .medium)
                }
                Text(n.title)
                    .font(AppFont.ui(14, .semibold))
                    .foregroundStyle(t.text)
                Spacer()
            }
            if let body = n.body, !body.isEmpty {
                Text(body)
                    .font(AppFont.ui(13.5))
                    .foregroundStyle(t.muted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let urlStr = n.url, !urlStr.isEmpty {
                Button(action: { openNoticeURL(urlStr) }) {
                    HStack(spacing: 6) {
                        Text(n.url_title?.isEmpty == false ? n.url_title! : String(localized: "Открыть"))
                            .font(AppFont.ui(13.5, .semibold))
                            .foregroundStyle(t.accent)
                        QXIcon(name: "arrowR", size: 14, color: t.accent, weight: .semibold)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(t.surface)
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(t.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func openNoticeURL(_ raw: String) {
        if raw.hasPrefix("lk:") {
            let go = String(raw.dropFirst(3))
            Task {
                if let url = await session.lkSession(go: go.isEmpty ? "home" : go) {
                    openURL(url)
                }
            }
        } else if let url = URL(string: raw) {
            openURL(url)
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
