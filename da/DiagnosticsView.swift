import SwiftUI

struct DiagnosticsView: View {
    @Environment(\.theme) var t
    @Environment(\.dismiss) var dismiss
    @StateObject private var diag = NetworkDiagnostics()

    var body: some View {
        VStack(spacing: 0) {
            IOSNav(title: "Устранение неполадок", back: "Назад", onBack: { dismiss() })

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    intro
                    speedCard
                    hostsCard

                    PrimaryButton(title: diag.running ? "Проверяем…" : "Проверить соединение",
                                  icon: "refresh") {
                        Task { await diag.runAll() }
                    }
                    .disabled(diag.running)
                    .opacity(diag.running ? 0.6 : 1)

                    Text("Задержка измеряется временем ответа сервера (не ICMP-ping). Тест скорости качает пробный файл ~8 МБ.")
                        .font(AppFont.ui(12))
                        .foregroundStyle(t.faint)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            if case .idle = diag.speed { await diag.runAll() }
        }
    }

    private var intro: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(t.accentSoft).frame(width: 36, height: 36)
                QXIcon(name: "pulse", size: 18, color: t.accent, weight: .medium)
            }
            Text("Проверьте, что интернет и серверы отвечают. Если что-то красное — пришлите скрин в поддержку.")
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

    private var speedCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                QXIcon(name: "gauge", size: 20, color: t.accent, weight: .medium)
                Text("Скорость загрузки")
                    .font(AppFont.ui(14, .semibold))
                    .foregroundStyle(t.text)
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                switch diag.speed {
                case .idle:
                    Text("—").font(AppFont.mono(34, .medium)).foregroundStyle(t.faint)
                case .running:
                    ProgressView().tint(t.accent)
                    Text("измеряем…").font(AppFont.ui(14)).foregroundStyle(t.muted)
                case .done(let mbps):
                    Text(String(format: "%.1f", mbps))
                        .font(AppFont.mono(34, .medium)).foregroundStyle(t.text)
                    Text("Мбит/с").font(AppFont.ui(14)).foregroundStyle(t.muted)
                case .fail:
                    QXIcon(name: "xmark", size: 20, color: t.danger, weight: .semibold)
                    Text("не удалось").font(AppFont.ui(14)).foregroundStyle(t.danger)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(t.surface)
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(t.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var hostsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Доступность и задержка".uppercased())
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
                Text("нет ответа").font(AppFont.ui(13, .medium)).foregroundStyle(t.danger)
            }
        }
    }

    private func color(forMs ms: Int) -> Color {
        if ms < 100 { return t.success }
        if ms < 300 { return t.warn }
        return t.danger
    }
}
