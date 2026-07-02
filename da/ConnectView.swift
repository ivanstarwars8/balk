import SwiftUI

struct ConnectView: View {
    @Environment(\.theme) var t
    @EnvironmentObject var session: AuthSession
    @Environment(\.openURL) var openURL
    @State private var importInFlight: Bool = false
    @State private var showDiagnostics: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            IOSNav(title: "Подключение")

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    ForEach(session.notices) { n in
                        noticeCard(n)
                    }
                    happCard
                    if session.subscriptionURL == nil {
                        expiredCard
                    } else {
                        actions
                        stepsCard
                        extraDeviceCard
                    }
                    troubleshootCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .refreshable {
                await session.loadSubscriptionURL()
                await session.loadNotices()
            }
        }
        .sheet(isPresented: $showDiagnostics) {
            DiagnosticsView()
        }
        .task {
            if session.subscriptionURL == nil {
                await session.loadSubscriptionURL()
            }
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

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Как подключиться")
                .font(AppFont.ui(14, .semibold))
                .foregroundStyle(t.text)
            stepRow(1, "Скачайте Happ из App Store — кнопка «Скачать Happ» ниже (ссылка для России и остального мира подберётся сама).")
            stepRow(2, "Нажмите «Импортировать в Happ» — подписка добавится в приложение автоматически и в зашифрованном виде.")
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
                    Text("Импорт конфигурации")
                        .font(AppFont.ui(14, .semibold))
                        .foregroundStyle(t.text)
                    Text("VPN работает в приложении Happ")
                        .font(AppFont.ui(12.5))
                        .foregroundStyle(t.muted)
                }
                Spacer()
            }
            Text("Сначала установите Happ, затем нажмите «Импортировать в Happ» — подписка добавится автоматически и в зашифрованном виде.")
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
                Text("Конфигурация недоступна")
                    .font(AppFont.ui(14, .semibold))
                    .foregroundStyle(t.text)
                Spacer()
            }
            Text("Конфигурация появится здесь автоматически. Если её нет — напишите нам в разделе «Поддержка».")
                .font(AppFont.ui(13.5))
                .foregroundStyle(t.muted)
                .lineSpacing(3)
        }
        .padding(16)
        .background(t.surface)
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(t.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var actions: some View {
        VStack(spacing: 11) {
            PrimaryButton(title: "Скачать Happ", icon: "download",
                          kind: .secondary, action: openHappStore)

            PrimaryButton(title: importInFlight ? "Готовим ссылку…" : "Импортировать в Happ",
                          icon: "arrowR",
                          action: openInHapp)
                .disabled(session.subscriptionURL == nil || importInFlight)
                .opacity((session.subscriptionURL == nil || importInFlight) ? 0.55 : 1)
        }
    }

    /// Adding another device: the encrypted import is the only supported path —
    /// there is deliberately NO copyable subscription link (a raw, unencrypted
    /// link must never be shared).
    private var extraDeviceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(t.accentSoft).frame(width: 36, height: 36)
                    QXIcon(name: "devices", size: 18, color: t.accent, weight: .medium)
                }
                Text("Другое устройство")
                    .font(AppFont.ui(14, .semibold))
                    .foregroundStyle(t.text)
                Spacer()
            }
            Text("Чтобы подключить ещё одно iOS-устройство — установите на нём приложение BADRIMGU и импортируйте подписку кнопкой. Другого способа нет: подписка передаётся только в зашифрованном виде.")
                .font(AppFont.ui(13.5))
                .foregroundStyle(t.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(t.surface)
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(t.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var troubleshootCard: some View {
        Button {
            showDiagnostics = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(t.surface2).frame(width: 36, height: 36)
                    QXIcon(name: "pulse", size: 18, color: t.muted, weight: .medium)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Устранение неполадок")
                        .font(AppFont.ui(15.5, .medium))
                        .foregroundStyle(t.text)
                    Text("Проверить скорость и доступность")
                        .font(AppFont.ui(12.5))
                        .foregroundStyle(t.muted)
                }
                Spacer(minLength: 0)
                QXIcon(name: "chevR", size: 17, color: t.faint, weight: .semibold)
            }
            .padding(16)
            .background(t.surface)
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(t.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

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

}
