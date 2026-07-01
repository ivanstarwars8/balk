import SwiftUI

struct LoginEmailView: View {
    @Environment(\.theme) var t
    @EnvironmentObject var session: AuthSession
    @State private var email: String = ""
    @State private var noAccount: Bool = false
    var onContinue: (String) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(t.surface)
                        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(t.line, lineWidth: 1))
                        .frame(width: 72, height: 72)
                    Mark(size: 42)
                }
                Text("Вход в аккаунт")
                    .font(AppFont.title(28, .bold))
                    .tracking(0.2)
                    .foregroundStyle(t.text)
                    .padding(.top, 20)
                Text("Войдите по почте — доступ к вашей конфигурации, устройствам и поддержке.")
                    .font(AppFont.ui(15))
                    .foregroundStyle(t.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 280)
                    .padding(.top, 8)
            }
            .padding(.top, 30)

            VStack(alignment: .leading, spacing: 8) {
                InputField(icon: "mail", label: "Почта",
                           placeholder: "you@badrimgu.gg",
                           value: $email,
                           focused: true)
                    .keyboardType(.emailAddress)

                if noAccount {
                    HStack(spacing: 6) {
                        QXIcon(name: "lock", size: 13, color: t.danger, weight: .medium)
                        Text("Аккаунт не найден. Проверьте адрес почты.")
                            .font(AppFont.ui(12.5))
                            .foregroundStyle(t.danger)
                    }
                    .padding(.horizontal, 4)
                } else if let err = session.lastError {
                    Text(err)
                        .font(AppFont.ui(12.5))
                        .foregroundStyle(t.danger)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.top, 34)

            Spacer(minLength: 0)

            PrimaryButton(
                title: session.emailCheckInFlight ? "Проверяем…" : "Продолжить",
                icon: "arrowR"
            ) {
                Task {
                    let exists = await session.checkEmail(email.trimmingCharacters(in: .whitespacesAndNewlines))
                    if exists {
                        onContinue(email)
                    } else {
                        noAccount = true
                    }
                }
            }
            .disabled(email.isEmpty || session.emailCheckInFlight)
            .opacity(email.isEmpty ? 0.55 : 1)

            HStack(spacing: 8) {
                QXIcon(name: "lock", size: 13, color: t.faint, weight: .medium)
                Text("Защищённое соединение · api.badrimgu.com")
                    .font(AppFont.ui(12.5))
                    .foregroundStyle(t.muted)
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .frame(maxHeight: .infinity)
        .onChange(of: email) { _, _ in noAccount = false }
    }
}
