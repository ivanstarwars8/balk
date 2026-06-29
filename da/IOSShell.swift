import SwiftUI

// Large-title nav header — wordmark/back row on top, big title below.
struct IOSNav<Trailing: View>: View {
    @Environment(\.theme) var t
    let title: String
    var back: String? = nil
    var onBack: (() -> Void)? = nil
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if let back {
                    Button {
                        onBack?()
                    } label: {
                        HStack(spacing: 3) {
                            QXIcon(name: "chevL", size: 22, color: t.accentText, weight: .semibold)
                            Text(back)
                                .font(AppFont.ui(17))
                                .foregroundStyle(t.accentText)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Wordmark(size: 14)
                }
                Spacer()
                trailing()
            }
            .frame(minHeight: 36)

            Text(title)
                .font(AppFont.title(32, .bold))
                .tracking(0.3)
                .foregroundStyle(t.text)
                .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }
}

extension IOSNav where Trailing == EmptyView {
    init(title: String, back: String? = nil, onBack: (() -> Void)? = nil) {
        self.init(title: title, back: back, onBack: onBack, trailing: { EmptyView() })
    }
}

// Round 36×36 icon button often used as IOSNav trailing (e.g. bell).
struct IOSCircleIconButton: View {
    @Environment(\.theme) var t
    let icon: String
    var action: () -> Void = {}
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(t.surface)
                    .overlay(Circle().strokeBorder(t.line, lineWidth: 1))
                    .frame(width: 36, height: 36)
                QXIcon(name: icon, size: 17, color: t.muted, weight: .medium)
            }
        }
        .buttonStyle(.plain)
    }
}
