import SwiftUI

struct ConnectView: View {
    @Environment(\.theme) var t
    @EnvironmentObject var session: AuthSession
    @Environment(\.openURL) var openURL
    @State private var copiedFlash: Bool = false
    @State private var importInFlight: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            IOSNav(title: "Подключение")

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    happCard
                    if session.subscriptionURL == nil {
                        expiredCard
                    } else {
                        actions
                        stepsCard
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

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Как подключиться")
                .font(AppFont.ui(14, .semibold))
                .foregroundStyle(t.text)
            stepRow(1, "Установите Happ из App Store — кнопка «Скачать Happ» выше (для России и остального мира ссылка подберётся сама).")
            stepRow(2, "Нажмите «Импортировать в Happ» — конфигурация добавится в приложение автоматически.")
            stepRow(3, "В Happ выберите сервер и нажмите «Подключиться». Дальше VPN управляется в Happ.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(t.surface)
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(t.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func stepRow(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            ZStack {
                Circle().fill(t.accentSoft).frame(width: 24, height: 24)
                Text("\(n)")
                    .font(AppFont.ui(13, .semibold))
                    .foregroundStyle(t.accent)
            }
            Text(LX(text))
                .font(AppFont.ui(13.5))
                .foregroundStyle(t.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
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
            Text("Ссылка для импорта в Happ появится здесь, когда подписка станет активной. Управление аккаунтом доступно в личном кабинете на сайте.")
                .font(AppFont.ui(13.5))
                .foregroundStyle(t.muted)
                .lineSpacing(3)
            PrimaryButton(title: "Открыть ЛК на сайте", icon: "link") {
                Task {
                    if let url = await session.lkSession(go: "home") {
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
            PrimaryButton(title: importInFlight ? "Готовим ссылку…" : "Импортировать в Happ",
                          icon: "download",
                          action: openInHapp)
                .disabled(session.subscriptionURL == nil || importInFlight)
                .opacity((session.subscriptionURL == nil || importInFlight) ? 0.55 : 1)

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
        guard !importInFlight else { return }
        importInFlight = true
        Task {
            // The backend builds the encrypted happ://crypt5/… link (single
            // source of truth — same logic the website uses). We just open it.
            let link = await session.happImportLink()
            await MainActor.run {
                importInFlight = false
                guard let link, let url = URL(string: link) else {
                    openHappStore()   // no link → at least send them to install Happ
                    return
                }
                openURL(url) { ok in
                    if !ok { openHappStore() }   // Happ not installed
                }
            }
        }
    }

    /// Happ ships as two separate App Store apps — Global and a Russia-only
    /// listing (different bundle IDs). The happ:// scheme is shared, so the
    /// import deep-link doesn't branch; only the *download* link does. Pick by
    /// the real App Store storefront, not the phone's language.
    private func openHappStore() {
        Task {
            let ru = await AppStoreRegion.isRussia()
            let region = ru ? "ru" : "us"
            let appID  = ru ? "id6783623643" : "id6504287215"
            if let url = URL(string: "https://apps.apple.com/\(region)/app/happ-proxy-utility/\(appID)") {
                await MainActor.run { openURL(url) }
            }
        }
    }

    private var displayURL: String {
        guard let raw = session.subscriptionURL?.url else { return String(localized: "Загружаем ссылку…") }
        return raw.replacingOccurrences(of: "https://", with: "")
    }
}
