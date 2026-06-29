import SwiftUI

struct ConnectView: View {
    @Environment(\.theme) var t
    @EnvironmentObject var session: AuthSession
    @Environment(\.openURL) var openURL
    @State private var copiedFlash: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            IOSNav(title: "Подключение")

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    happCard
                    if session.checkoutURL != nil || (session.subscriptionURL == nil && session.subscription?.status == "expired") {
                        expiredCard
                    } else {
                        actions
                        linkRow
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)

                GroupCard(label: "Поддерживаемые клиенты") {
                    RowItem(icon: "bolt", title: "Happ",
                            subtitle: "Рекомендуем для iOS",
                            accent: true, chev: true,
                            onTap: openHappStore)
                    RowItem(icon: "layers", title: "v2RayTun", chev: true)
                    RowItem(icon: "shield", title: "Streisand", last: true, chev: true)
                }
                .padding(.top, 14)
            }
            .refreshable { await session.loadSubscriptionURL() }
        }
        .task {
            if session.subscriptionURL == nil {
                await session.loadSubscriptionURL()
            }
        }
    }

    private var happCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(t.accentSoft)
                        .frame(width: 36, height: 36)
                    QXIcon(name: "shieldCheck", size: 18, color: t.accent, weight: .medium)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Это личный кабинет — временно")
                        .font(AppFont.ui(14, .semibold))
                        .foregroundStyle(t.text)
                    Text("Сам VPN работает в Happ")
                        .font(AppFont.ui(12.5))
                        .foregroundStyle(t.muted)
                }
                Spacer()
            }
            Text("Подключение в один тап: «Импортировать в Happ» — конфиг сам пропишется в приложении. Если Happ ещё не стоит — установите из App Store.")
                .font(AppFont.ui(13.5))
                .foregroundStyle(t.muted)
                .lineSpacing(3)
        }
        .padding(16)
        .background(t.surface)
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(t.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var expiredCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(t.warn.opacity(0.18))
                        .frame(width: 36, height: 36)
                    QXIcon(name: "clock", size: 18, color: t.warn, weight: .medium)
                }
                Text("Подписка не активна")
                    .font(AppFont.ui(14, .semibold))
                    .foregroundStyle(t.text)
                Spacer()
            }
            Text("Чтобы получить ссылку для импорта в Happ, продлите подписку на сайте.")
                .font(AppFont.ui(13.5))
                .foregroundStyle(t.muted)
                .lineSpacing(3)
            PrimaryButton(title: "Продлить на сайте", icon: "card") {
                Task {
                    if let direct = session.checkoutURL, let url = URL(string: direct) {
                        openURL(url)
                    } else if let url = await session.lkSession(go: "payment") {
                        openURL(url)
                    }
                }
            }
        }
        .padding(16)
        .background(t.surface)
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(t.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var actions: some View {
        VStack(spacing: 11) {
            PrimaryButton(title: "Импортировать в Happ", icon: "download",
                          action: openInHapp)
                .disabled(session.subscriptionURL == nil)
                .opacity(session.subscriptionURL == nil ? 0.55 : 1)

            PrimaryButton(title: "Скачать Happ", icon: "arrowR",
                          kind: .secondary, action: openHappStore)
        }
    }

    private var linkRow: some View {
        HStack(spacing: 12) {
            QXIcon(name: "link", size: 18, color: t.muted, weight: .medium)
            Text(displayURL)
                .font(AppFont.mono(12))
                .foregroundStyle(t.muted)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            Button(action: copyLink) {
                HStack(spacing: 5) {
                    QXIcon(name: copiedFlash ? "check" : "grid",
                           size: 16, color: t.accentText, weight: .semibold)
                    Text(copiedFlash ? "Скопировано" : "Копировать")
                        .font(AppFont.ui(13, .semibold))
                        .foregroundStyle(t.accentText)
                }
            }
            .buttonStyle(.plain)
            .disabled(session.subscriptionURL == nil)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(t.surface)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(t.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Actions

    private func copyLink() {
        guard let s = session.subscriptionURL?.url else { return }
        UIPasteboard.general.string = s
        copiedFlash = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            copiedFlash = false
        }
    }

    private func openInHapp() {
        guard let s = session.subscriptionURL?.url else { return }
        // Happ deep-link: happ://add/<base64url-encoded subscription URL>
        let encoded = Data(s.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        if let url = URL(string: "happ://add/\(encoded)") {
            openURL(url) { ok in
                if !ok { openHappStore() }
            }
        }
    }

    private func openHappStore() {
        if let url = URL(string: "https://apps.apple.com/app/happ-proxy-utility/id6504287215") {
            openURL(url)
        }
    }

    private var displayURL: String {
        guard let raw = session.subscriptionURL?.url else { return "Загружаем ссылку…" }
        return raw.replacingOccurrences(of: "https://", with: "")
    }
}
