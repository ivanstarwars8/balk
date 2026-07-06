import SwiftUI

// Instruction / help section, fully managed from the admin panel (/v1/guides).
// Root shows topics; a topic shows its photo + text and a list of subtopics;
// a subtopic shows its own photo + text. All pushed inside ConnectView's stack.

// MARK: - Root: list of topics

struct GuideRootView: View {
    @Environment(\.theme) var t
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: AuthSession

    var body: some View {
        VStack(spacing: 0) {
            IOSNav(title: "Инструкция")

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    // Pinned troubleshooting entry (always available).
                    NavigationLink(destination: DiagnosticsView()) {
                        GuideRow(title: String(localized: "Устранение неполадок"),
                                 subtitle: String(localized: "Проверка DNS и советы, если VPN плохо работает"),
                                 image: nil)
                    }
                    .buttonStyle(.plain)

                    if session.guides.isEmpty {
                        Text("Другие инструкции появятся здесь.")
                            .font(AppFont.ui(13))
                            .foregroundStyle(t.faint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 6)
                            .padding(.top, 6)
                    } else {
                        ForEach(session.guides) { topic in
                            NavigationLink(destination: GuideTopicDetail(topic: topic)) {
                                GuideRow(title: topic.title,
                                         subtitle: topic.subtopics?.isEmpty == false
                                             ? String(localized: "Разделов: ") + "\(topic.subtopics!.count)"
                                             : nil,
                                         image: topic.image)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .refreshable { await session.loadGuides() }
        }
        .navigationBarBackButtonHidden(true)
        .task { await session.loadGuides() }
    }
}

// MARK: - Topic detail: photo + text + subtopics

struct GuideTopicDetail: View {
    @Environment(\.theme) var t
    @Environment(\.dismiss) var dismiss
    let topic: GuideTopic

    var body: some View {
        VStack(spacing: 0) {
            IOSNav(title: topic.title, back: "Инструкция", onBack: { dismiss() })

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    GuideBody(image: topic.image, text: topic.body)

                    if let subs = topic.subtopics, !subs.isEmpty {
                        Text("Разделы")
                            .font(AppFont.ui(13, .semibold))
                            .foregroundStyle(t.muted)
                            .padding(.top, 4)
                        VStack(spacing: 12) {
                            ForEach(subs) { sub in
                                NavigationLink(destination: GuideItemDetail(item: sub)) {
                                    GuideRow(title: sub.title, subtitle: nil, image: sub.image)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Subtopic detail: photo + text

struct GuideItemDetail: View {
    @Environment(\.dismiss) var dismiss
    let item: GuideItem

    var body: some View {
        VStack(spacing: 0) {
            IOSNav(title: item.title, back: "Назад", onBack: { dismiss() })

            ScrollView(.vertical, showsIndicators: false) {
                GuideBody(image: item.image, text: item.body)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Shared pieces

/// A tappable card row: optional thumbnail + title (+ subtitle) + chevron.
private struct GuideRow: View {
    @Environment(\.theme) var t
    let title: String
    let subtitle: String?
    let image: String?

    var body: some View {
        HStack(spacing: 13) {
            GuideThumb(image: image, size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppFont.ui(15, .semibold))
                    .foregroundStyle(t.text)
                    .multilineTextAlignment(.leading)
                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.ui(12.5))
                        .foregroundStyle(t.muted)
                }
            }
            Spacer(minLength: 0)
            QXIcon(name: "chevR", size: 16, color: t.faint, weight: .semibold)
        }
        .padding(14)
        .background(t.surface)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(t.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// Full-width photo (if any) followed by the body text.
private struct GuideBody: View {
    @Environment(\.theme) var t
    let image: String?
    let text: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let image, let url = URL(string: image) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFit()
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 16).fill(t.surface2).frame(height: 180)
                            ProgressView().tint(t.muted)
                        }
                    default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(t.line, lineWidth: 1))
            }
            if let text, !text.isEmpty {
                Text(text)
                    .font(AppFont.ui(14.5))
                    .foregroundStyle(t.muted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// Small rounded thumbnail with a placeholder when there's no image.
private struct GuideThumb: View {
    @Environment(\.theme) var t
    let image: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let image, let url = URL(string: image) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image { img.resizable().scaledToFill() }
                    else { placeholder }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(t.line, lineWidth: 1))
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(t.accentSoft)
            QXIcon(name: "book", size: 20, color: t.accent, weight: .medium)
        }
    }
}
