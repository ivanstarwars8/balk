import SwiftUI

struct ConnectView: View {
    @Environment(\.theme) var t
    @EnvironmentObject var session: AuthSession
    @Environment(\.openURL) var openURL
    @State private var importInFlight: Bool = false
    // Happ-version reminder shown right before importing (not at launch): if
    // the user just installed Happ via our button it's fine, otherwise they
    // should verify the app isn't an outdated build.
    @State private var showImportNotice: Bool = false

    // Server-side switch: which client this screen hands out (happ | incy).
    private var isIncy: Bool { session.connectConfig.isIncy }
    private var appName: String { isIncy ? "Incy" : "Happ" }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                IOSNav(title: "Подключение")

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        // The notice board lives on the Profile tab since build 18.
                        clientCard
                        // Install + import buttons are ALWAYS shown — installing
                        // the client needs no network, and the import button must
                        // not vanish on an offline launch. The "config unavailable"
                        // banner appears only when the server actually confirmed
                        // there's no active subscription.
                        if !isIncy { happVersionCard }
                        actions
                        if session.subscriptionURL == nil && session.subscriptionKnownEmpty {
                            expiredCard
                        }
                        stepsCard
                        extraDeviceCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }
                .refreshable {
                    await session.loadSubscriptionURL()
                    await session.loadConnectConfig()   // forced (bypasses the 24h cache)
                    await session.loadGuides()
                }
            }
        }
        .task {
            // Refresh the subscription link and the connect-app switch at most
            // once a day — the cached copies keep the import flow working
            // (incl. offline) between refreshes.
            await session.loadSubscriptionURLIfStale()
            await session.loadConnectConfigIfStale()
        }
        .sheet(isPresented: $showImportNotice) {
            HappNoticeView(
                onCheckRU: { openHappStore(russia: true) },
                onCheckGlobal: { openHappStore(russia: false) },
                onProceed: {
                    showImportNotice = false
                    openInClient()
                }
            )
        }
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Как подключиться")
                .font(AppFont.ui(14, .semibold))
                .foregroundStyle(t.text)
            if isIncy {
                stepRow(1, "Скачайте Incy из App Store кнопкой ниже.")
                stepRow(2, "Нажмите «Импортировать в Incy» — подписка добавится в приложение автоматически.")
                stepRow(3, "В Incy выберите сервер и нажмите «Подключиться». Дальше VPN управляется в Incy.")
            } else {
                stepRow(1, "Скачайте Happ из App Store — кнопкой «Россия» или «Global» ниже (какая откроется — та ваша).")
                stepRow(2, "Нажмите «Импортировать в Happ» — подписка добавится в приложение автоматически и в зашифрованном виде.")
                stepRow(3, "В Happ выберите сервер и нажмите «Подключиться». Дальше VPN управляется в Happ.")
            }
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

    private var clientCard: some View {
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
                    Text(LX("VPN работает в приложении \(appName)"))
                        .font(AppFont.ui(12.5))
                        .foregroundStyle(t.muted)
                }
                Spacer()
            }
            Text(LX("Сначала установите \(appName), затем нажмите «Импортировать в \(appName)» — подписка добавится автоматически."))
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

    // Import is blocked only when the server CONFIRMED there's no subscription.
    // Offline (unknown) keeps it tappable — openInClient fails over to the store.
    private var importDisabled: Bool {
        importInFlight || (session.subscriptionURL == nil && session.subscriptionKnownEmpty)
    }

    private var actions: some View {
        VStack(spacing: 11) {
            if isIncy {
                PrimaryButton(title: "Скачать Incy", icon: "download",
                              kind: .secondary) { openIncyStore() }
            } else {
                PrimaryButton(title: "Скачать Happ (Россия)", icon: "download",
                              kind: .secondary) { openHappStore(russia: true) }
                PrimaryButton(title: "Скачать Happ (Global)", icon: "download",
                              kind: .secondary) { openHappStore(russia: false) }
            }

            PrimaryButton(title: importInFlight ? "Готовим ссылку…" : "Импортировать в \(appName)",
                          icon: "arrowR",
                          action: {
                              // The version advisory is Happ-specific (two store
                              // listings, frequent takedowns) — Incy imports directly.
                              if isIncy { openInClient() } else { showImportNotice = true }
                          })
                .disabled(importDisabled)
                .opacity(importDisabled ? 0.55 : 1)
        }
    }

    /// Happ ships as TWO separate App Store apps (different bundle IDs): a
    /// Russia-only listing and a Global one. Apple's rules make each
    /// unavailable in the other storefront, so we can't rely on auto-detection —
    /// we show both and explain, letting the user pick the one that opens.
    private var happVersionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(t.warn.opacity(0.16))
                        .frame(width: 36, height: 36)
                    QXIcon(name: "download", size: 18, color: t.warn, weight: .medium)
                }
                Text("Две версии Happ")
                    .font(AppFont.ui(14, .semibold))
                    .foregroundStyle(t.text)
                Spacer()
            }
            Text("В App Store два разных приложения Happ: для России и глобальное (Global). Из-за правил Apple российское не открыть в зарубежном App Store, а глобальное — в российском. Нажмите ту кнопку, которая откроется у вас.")
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

    // MARK: - Actions

    private func openInClient() {
        guard !importInFlight else { return }
        importInFlight = true
        Task {
            // The backend builds the deep link for the configured client
            // (happ://crypt5/… or incy://import/…) — single source of truth,
            // same logic the website uses. We just open it.
            let link = await session.importLink()
            await MainActor.run {
                importInFlight = false
                guard let link, let url = URL(string: link) else {
                    openClientStore()   // no link → at least send them to install
                    return
                }
                openURL(url) { ok in
                    if !ok { openClientStore() }   // client not installed
                }
            }
        }
    }

    /// Store fallback for the configured client (import failed / not installed).
    private func openClientStore() {
        if isIncy { openIncyStore() } else { openHappStore() }
    }

    private func openIncyStore() {
        let link = session.connectConfig.stores?.incy
            ?? "https://apps.apple.com/ru/app/incy/id6756943388"
        if let url = URL(string: link) { openURL(url) }
    }

    /// Explicit store link — used by the two user-facing download buttons.
    /// russia=true → the RU-only listing, false → the Global one.
    /// Links come from the server config so a re-published listing (new bundle
    /// id after a takedown) is fixable without an app update.
    private func openHappStore(russia: Bool) {
        let stores = session.connectConfig.stores
        let link = (russia ? stores?.happ_ru : stores?.happ_global)
            ?? (russia ? "https://apps.apple.com/ru/app/happ-proxy-utility/id6783623643"
                       : "https://apps.apple.com/us/app/happ-proxy-utility/id6504287215")
        if let url = URL(string: link) { openURL(url) }
    }

    /// Auto-detected store link (by real App Store storefront) — used by the
    /// import fallback and the Happ-version advisory's "Проверить Happ" button.
    private func openHappStore() {
        Task {
            let ru = await AppStoreRegion.isRussia()
            await MainActor.run { openHappStore(russia: ru) }
        }
    }

}
/// Pre-import reminder to verify the Happ version. Shown when the user taps
/// "Импортировать" — not at launch. "Проверить Happ" opens the store;
/// "Импортировать" proceeds with the actual import.
struct HappNoticeView: View {
    @Environment(\.theme) var t
    var onCheckRU: () -> Void
    var onCheckGlobal: () -> Void
    var onProceed: () -> Void

    var body: some View {
        ZStack {
            t.bg.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    ZStack {
                        Circle().fill(t.warn.opacity(0.16)).frame(width: 72, height: 72)
                        QXIcon(name: "shield", size: 36, color: t.warn, weight: .medium)
                    }
                    .padding(.top, 30)

                    Text("Проверьте версию Happ")
                        .font(AppFont.title(24, .bold))
                        .foregroundStyle(t.text)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Happ несколько раз удаляли из App Store. Перед импортом убедитесь, что у вас актуальная версия — иначе VPN будет работать нестабильно.")
                        Text("Если вы только что скачали Happ по кнопке выше — всё в порядке, продолжайте. Если Happ был установлен раньше — лучше проверьте:")
                            .foregroundStyle(t.text)
                            .fontWeight(.semibold)
                        bullet("Нажмите «Проверить Happ». Кнопка «Открыть» или «Обновить» — всё в порядке.")
                        bullet("Кнопка «Загрузить»/«Установить» — удалите старый Happ и установите заново, потом импортируйте.")
                    }
                    .font(AppFont.ui(14.5))
                    .foregroundStyle(t.muted)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(t.surface)
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(t.line, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    Spacer(minLength: 0)

                    VStack(spacing: 11) {
                        PrimaryButton(title: "Проверить Happ (Россия)", icon: "download",
                                      kind: .secondary, action: onCheckRU)
                        PrimaryButton(title: "Проверить Happ (Global)", icon: "download",
                                      kind: .secondary, action: onCheckGlobal)
                        PrimaryButton(title: "Импортировать", icon: "arrowR", action: onProceed)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .frame(minHeight: 640)
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(t.accent).frame(width: 6, height: 6).padding(.top, 7)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

