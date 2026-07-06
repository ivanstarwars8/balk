import SwiftUI

struct DiagnosticsView: View {
    @Environment(\.theme) var t
    @Environment(\.dismiss) var dismiss
    @StateObject private var diag = NetworkDiagnostics()

    var body: some View {
        VStack(spacing: 0) {
            IOSNav(title: "Устранение неполадок", back: "Инструкция", onBack: { dismiss() })

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    intro

                    PrimaryButton(title: diag.running ? "Проверяем…" : "Запустить проверку",
                                  icon: "refresh") {
                        Task { await diag.runAll() }
                    }
                    .disabled(diag.running)
                    .opacity(diag.running ? 0.6 : 1)

                    hostsCard

                    Text("Это проверка резолвинга DNS (не пинг сервера): показывает, доходит ли устройство до DNS и за сколько мс. Если адрес не резолвится — у вас проблема с сетью или DNS-блокировка.")
                        .font(AppFont.ui(12))
                        .foregroundStyle(t.faint)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    vpnHelpCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    /// Static help for "VPN works poorly" — the most common fixes, in order.
    private var vpnHelpCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(t.accentSoft).frame(width: 36, height: 36)
                    QXIcon(name: "shield", size: 18, color: t.accent, weight: .medium)
                }
                Text("Если VPN плохо работает")
                    .font(AppFont.ui(14, .semibold))
                    .foregroundStyle(t.text)
                Spacer()
            }
            helpRow("Проверьте, что установлена актуальная версия Happ (кнопка «Скачать Happ» на экране «Подключение»: «Открыть/Обновить» — ок, «Установить» — переустановите Happ).")
            helpRow("В Happ выберите другой сервер и переподключитесь.")
            helpRow("Выключите и снова включите VPN в Happ.")
            helpRow("Если DNS выше «не резолвится» — проблема с сетью, попробуйте другую сеть (Wi-Fi / моб. интернет).")
            helpRow("Если не помогло — напишите в «Поддержку» и приложите скрин этого экрана.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(t.surface)
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(t.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func helpRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(t.accent).frame(width: 6, height: 6).padding(.top, 7)
            Text(text)
                .font(AppFont.ui(13.5))
                .foregroundStyle(t.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var intro: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(t.accentSoft).frame(width: 36, height: 36)
                QXIcon(name: "pulse", size: 18, color: t.accent, weight: .medium)
            }
            Text("Нажмите «Запустить проверку»: проверим DNS серверов и скорость загрузки. Если что-то красное — пришлите скрин в поддержку.")
                .font(AppFont.ui(13.5))
                .foregroundStyle(t.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(t.surface)
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(t.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var hostsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DNS-проверка".uppercased())
                .font(AppFont.ui(11.5, .semibold))
                .tracking(1.2)
                .foregroundStyle(t.faint)
                .padding(.horizontal, 6)
                .padding(.bottom, 9)
            VStack(spacing: 0) {
                ForEach(Array(diag.probes.enumerated()), id: \.element.id) { i, p in
                    probeRow(p, last: i == diag.probes.count - 1)
                }
            }
            .background(t.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(t.line, lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func probeRow(_ p: Probe, last: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(t.surface2).frame(width: 36, height: 36)
                QXIcon(name: "globe", size: 18, color: t.muted, weight: .medium)
            }
            Text(p.name)
                .font(AppFont.ui(15.5, .medium))
                .foregroundStyle(t.text)
            Spacer(minLength: 0)
            statusView(p.state)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            if !last { Rectangle().fill(t.line).frame(height: 1) }
        }
    }

    @ViewBuilder
    private func statusView(_ s: ProbeState) -> some View {
        switch s {
        case .idle:
            Text("—").font(AppFont.mono(13)).foregroundStyle(t.faint)
        case .running:
            ProgressView().tint(t.muted)
        case .ok(let ms):
            HStack(spacing: 5) {
                Circle().fill(color(forMs: ms)).frame(width: 7, height: 7)
                Text("\(ms)").font(AppFont.mono(14, .medium)).foregroundStyle(color(forMs: ms))
                Text("мс").font(AppFont.mono(10)).foregroundStyle(t.faint)
            }
        case .fail:
            HStack(spacing: 5) {
                QXIcon(name: "xmark", size: 13, color: t.danger, weight: .semibold)
                Text("не резолвится").font(AppFont.ui(13, .medium)).foregroundStyle(t.danger)
            }
        }
    }

    private func color(forMs ms: Int) -> Color {
        if ms < 100 { return t.success }
        if ms < 400 { return t.warn }
        return t.danger
    }
}
