import SwiftUI

struct DevicesView: View {
    @Environment(\.theme) var t
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: AuthSession

    var body: some View {
        VStack(spacing: 0) {
            IOSNav(title: "Устройства", back: "Профиль", onBack: { dismiss() })

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    intro
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 14)

                    if session.devices.isEmpty {
                        Text("Пока нет активных устройств.")
                            .font(AppFont.ui(13))
                            .foregroundStyle(t.muted)
                            .padding(.horizontal, 20)
                    } else {
                        GroupCard {
                            ForEach(Array(session.devices.enumerated()), id: \.element.id) { i, d in
                                RowItem(icon: "devices",
                                        title: deviceTitle(d),
                                        subtitle: deviceSub(d),
                                        last: i == session.devices.count - 1,
                                        trailing: AnyView(
                                            Button {
                                                Task { await session.revokeDevice(d.id) }
                                            } label: {
                                                Text("Отозвать")
                                                    .font(AppFont.ui(13, .semibold))
                                                    .foregroundStyle(t.danger)
                                            }
                                            .buttonStyle(.plain)
                                        ))
                            }
                        }
                    }
                }
            }
            .refreshable { await session.loadDevices() }
        }
        .task { await session.loadDevices() }
        .navigationBarBackButtonHidden(true)
    }

    private var intro: some View {
        Text("Здесь показаны устройства, где выполнен вход. Отзовите ненужные, чтобы завершить их сессии.")
            .font(AppFont.ui(14))
            .foregroundStyle(t.muted)
            .lineSpacing(3)
    }

    private func deviceTitle(_ d: Device) -> String {
        if let m = d.model, !m.isEmpty { return m }
        if d.platform == "ios" { return "iPhone" }
        if d.platform == "android" { return "Android" }
        return String(localized: "Устройство")
    }

    private func deviceSub(_ d: Device) -> String {
        var parts: [String] = []
        if let os = d.os, !os.isEmpty {
            parts.append((d.platform == "ios" ? "iOS " : "") + os)
        } else if let p = d.platform { parts.append(p.capitalized) }
        if let seen = d.last_seen { parts.append(relativeAgo(seen)) }
        return parts.joined(separator: " · ")
    }

    private func relativeAgo(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return "" }
        let f = RelativeDateTimeFormatter()
        f.locale = Locale.current
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: .now)
    }
}
