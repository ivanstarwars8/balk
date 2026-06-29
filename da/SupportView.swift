import SwiftUI

struct SupportView: View {
    @Environment(\.theme) var t
    @EnvironmentObject var session: AuthSession
    @StateObject private var chat = ChatSession()
    @State private var draft: String = ""

    private let chips = ["Не приходит подписка", "Оплата", "Сменить устройство"]

    var body: some View {
        VStack(spacing: 0) {
            header

            messagesScroll

            quickChips

            inputBar
        }
        .task {
            await chat.start(email: session.user?.email)
        }
        .onDisappear { chat.stop() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Wordmark(size: 14)
                Spacer()
                HStack(spacing: 7) {
                    Circle().fill(t.success).frame(width: 7, height: 7)
                    Text("Онлайн")
                        .font(AppFont.ui(12.5, .semibold))
                        .foregroundStyle(t.muted)
                }
            }
            .frame(minHeight: 36)

            Text("Поддержка")
                .font(AppFont.title(32, .bold))
                .tracking(0.3)
                .foregroundStyle(t.text)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private var messagesScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 11) {
                    if chat.bootstrapping && chat.messages.isEmpty {
                        ProgressView().padding(.top, 40)
                    } else if chat.messages.isEmpty {
                        Text("Чат пустой. Напишите свой вопрос — оператор ответит в течение нескольких минут.")
                            .font(AppFont.ui(13))
                            .foregroundStyle(t.muted)
                            .multilineTextAlignment(.center)
                            .padding(.top, 40)
                            .padding(.horizontal, 24)
                    } else {
                        ForEach(chat.messages) { m in
                            Bubble(message: m)
                                .id(m.id)
                        }
                    }

                    if let err = chat.error {
                        Text(err)
                            .font(AppFont.ui(12))
                            .foregroundStyle(t.danger)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 8)
            }
            .onChange(of: chat.messages.last?.id) { _, last in
                if let last { withAnimation { proxy.scrollTo(last, anchor: .bottom) } }
            }
        }
    }

    private var quickChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { c in
                    Button {
                        draft = c
                    } label: {
                        Text(c)
                            .font(AppFont.ui(13, .medium))
                            .foregroundStyle(t.text)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(t.surface)
                            .overlay(Capsule().strokeBorder(t.lineStrong, lineWidth: 1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.vertical, 6)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                TextField("", text: $draft,
                          prompt: Text("Сообщение…").foregroundColor(t.faint))
                    .font(AppFont.ui(14.5))
                    .foregroundStyle(t.text)
                    .tint(t.accent)
                    .onSubmit(submit)
                QXIcon(name: "plus", size: 19, color: t.faint, weight: .medium)
            }
            .padding(.horizontal, 16)
            .frame(height: 46)
            .background(t.surface)
            .overlay(Capsule().strokeBorder(t.line, lineWidth: 1))
            .clipShape(Capsule())

            Button(action: submit) {
                ZStack {
                    Circle().fill(t.accent)
                    QXIcon(name: "send", size: 19, color: t.onAccent, weight: .medium)
                }
                .frame(width: 46, height: 46)
                .opacity(canSend ? 1 : 0.5)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private var canSend: Bool {
        chat.isReady && !chat.sending &&
            !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        let text = draft
        draft = ""
        Task { await chat.send(text) }
    }
}

private struct Bubble: View {
    @Environment(\.theme) var t
    let message: ChatMessage

    var body: some View {
        if message.isSystem {
            systemBubble
        } else {
            chatBubble
        }
    }

    private var systemBubble: some View {
        Text(message.body)
            .font(AppFont.mono(10.5))
            .tracking(0.4)
            .foregroundStyle(t.faint)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }

    private var chatBubble: some View {
        let me = message.isMe
        return VStack(alignment: me ? .trailing : .leading, spacing: 3) {
            Text(message.body)
                .font(AppFont.ui(14.5))
                .lineSpacing(2)
                .foregroundStyle(me ? t.onAccent : t.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(me ? t.accent : t.surface)
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 19,
                        bottomLeadingRadius: me ? 19 : 6,
                        bottomTrailingRadius: me ? 6 : 19,
                        topTrailingRadius: 19
                    ).strokeBorder(me ? .clear : t.line, lineWidth: 1)
                )
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 19,
                        bottomLeadingRadius: me ? 19 : 6,
                        bottomTrailingRadius: me ? 6 : 19,
                        topTrailingRadius: 19
                    )
                )
                .frame(maxWidth: 280, alignment: me ? .trailing : .leading)

            Text(message.displayTime)
                .font(AppFont.mono(9.5))
                .foregroundStyle(t.faint)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, alignment: me ? .trailing : .leading)
    }
}
