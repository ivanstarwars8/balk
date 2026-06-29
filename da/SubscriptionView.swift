import SwiftUI

struct SubscriptionView: View {
    @Environment(\.theme) var t
    @EnvironmentObject var session: AuthSession
    @Environment(\.openURL) var openURL

    var body: some View {
        VStack(spacing: 0) {
            IOSNav(title: "Подписка") {
                IOSCircleIconButton(icon: "bell")
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    planHero
                    trafficCard
                    quickStats
                    extraGroup
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .refreshable { await session.refreshMe() }
        }
        .task { await session.refreshMe() }
    }

    private var planHero: some View {
        ZStack(alignment: .topLeading) {
            Circle()
                .fill(RadialGradient(colors: [t.accentSoft, .clear],
                                     center: .center, startRadius: 0, endRadius: 100))
                .frame(width: 150, height: 150)
                .offset(x: 200, y: -30)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Pill(text: planTitle, tone: .accent, solid: true)
                    Spacer()
                    Pill(text: statusTitle, tone: statusTone)
                }

                Text(session.user?.email ?? "—")
                    .font(AppFont.title(24, .bold))
                    .tracking(0.2)
                    .foregroundStyle(t.text)
                    .padding(.top, 18)

                HStack(spacing: 22) {
                    statBlock(label: "Активна до", value: expiresDate, mono: true, valueColor: t.text)
                    Rectangle().fill(t.line).frame(width: 1, height: 36)
                    statBlock(label: "Осталось", value: daysLeftText, mono: true, valueColor: t.accentText)
                }
                .padding(.top, 18)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
        }
        .background(t.surface)
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(t.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .padding(.horizontal, 16)
    }

    private func statBlock(label: String, value: String, mono: Bool, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(LX(label).uppercased())
                .font(AppFont.ui(11, .semibold))
                .tracking(0.5)
                .foregroundStyle(t.faint)
            Text(value)
                .font(mono ? AppFont.mono(15) : AppFont.ui(15, .semibold))
                .foregroundStyle(valueColor)
        }
    }

    private var trafficCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Трафик")
                    .font(AppFont.ui(14, .semibold))
                    .foregroundStyle(t.text)
                Spacer()
                Text(trafficLabel)
                    .font(AppFont.mono(13))
                    .foregroundStyle(t.muted)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(t.surface2)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(t.accent)
                        .frame(width: geo.size.width * trafficRatio)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(t.surface)
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(t.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 16)
    }

    private var quickStats: some View {
        HStack(spacing: 11) {
            StatTile(icon: "devices", label: "Устройства", value: devicesLabel)
            StatTile(icon: "clock", label: "Тариф", value: planShortLabel, tone: t.accent)
        }
        .padding(.horizontal, 16)
    }

    private var extraGroup: some View {
        GroupCard {
            RowItem(icon: "link", title: "Открыть ЛК на сайте",
                    subtitle: "Вы уже авторизованы",
                    accent: true, last: true, chev: true,
                    onTap: {
                        Task {
                            if let url = await session.lkSession(go: "home") {
                                openURL(url)
                            }
                        }
                    })
        }
        .padding(.top, 6)
    }

    // MARK: - Derived values

    private var planTitle: String {
        let p = session.subscription?.plan ?? "—"
        let map: [String: String.LocalizationValue] = [
            "1m": "Premium · мес", "3m": "Premium · 3 мес",
            "6m": "Premium · 6 мес", "12m": "Premium · год", "1y": "Premium · год"]
        if let key = map[p] { return String(localized: key) }
        return "Premium · \(p)"
    }

    private var planShortLabel: String {
        switch session.subscription?.plan ?? "" {
        case "1m": return String(localized: "Мес")
        case "3m": return String(localized: "3 мес")
        case "6m": return String(localized: "6 мес")
        case "12m", "1y": return String(localized: "Год")
        default: return session.subscription?.plan ?? "—"
        }
    }

    private var statusTitle: String {
        let s = session.subscription?.status ?? ""
        switch s {
        case "active": return String(localized: "Активна")
        case "expired": return String(localized: "Истекла")
        case "trial": return String(localized: "Триал")
        case "": return "—"
        default: return s.capitalized
        }
    }

    private var statusTone: Pill.Tone {
        switch session.subscription?.status ?? "" {
        case "active": return .success
        case "expired": return .warn
        default: return .muted
        }
    }

    private var expiresDate: String {
        guard let iso = session.subscription?.expires_at,
              let date = ISO8601DateFormatter().date(from: iso) else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        return f.string(from: date)
    }

    private var daysLeftText: String {
        guard let iso = session.subscription?.expires_at,
              let date = ISO8601DateFormatter().date(from: iso) else { return "—" }
        let days = Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 0
        if days < 0 { return String(localized: "истекла") }
        return "\(days) \(pluralizeDays(days))"
    }

    private func pluralizeDays(_ n: Int) -> String {
        let m10 = n % 10, m100 = n % 100
        if m10 == 1 && m100 != 11 { return String(localized: "день") }
        if (2...4).contains(m10) && !(12...14).contains(m100) { return String(localized: "дня") }
        return String(localized: "дней")
    }

    private var devicesLabel: String {
        guard let s = session.subscription else { return "—" }
        return "\(s.devices_used ?? 0) / \(s.devices_limit ?? 0)"
    }

    private var trafficLabel: String {
        guard let s = session.subscription else { return "—" }
        let used = formatGB(s.traffic_used_bytes ?? 0)
        guard let limit = s.traffic_limit_bytes else {
            return "\(used) / ∞"
        }
        return "\(used) / \(formatGB(limit))"
    }

    private var trafficRatio: CGFloat {
        guard let s = session.subscription,
              let limit = s.traffic_limit_bytes, limit > 0
        else { return 0.04 }   // безлимит → тонкая полоска
        let used = Double(s.traffic_used_bytes ?? 0)
        return CGFloat(min(max(used / Double(limit), 0), 1))
    }

    private func formatGB(_ bytes: Int64) -> String {
        let unit = String(localized: "ГБ")
        let gb = Double(bytes) / 1_073_741_824
        if gb < 0.1 { return "0 \(unit)" }
        if gb < 10 { return String(format: "%.1f \(unit)", gb) }
        return "\(Int(gb)) \(unit)"
    }
}
