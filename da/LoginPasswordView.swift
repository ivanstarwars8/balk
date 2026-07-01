import SwiftUI

struct LoginPasswordView: View {
    @Environment(\.theme) var t
    @EnvironmentObject var session: AuthSession
    let email: String
    var onBack: () -> Void = {}

    @State private var password: String = ""
    @State private var hidden: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onBack) {
                HStack(spacing: 3) {
                    QXIcon(name: "chevL", size: 22, color: t.accentText, weight: .semibold)
                    Text("Назад")
                        .font(AppFont.ui(17))
                        .foregroundStyle(t.accentText)
                }
            }
            .buttonStyle(.plain)
            .frame(minHeight: 36)

            VStack(alignment: .leading, spacing: 10) {
                Text("С возвращением")
                    .font(AppFont.title(30, .bold))
                    .tracking(0.2)
                    .foregroundStyle(t.text)
                Text("Аккаунт найден. Введите пароль.")
                    .foregroundStyle(t.muted)
                    .font(AppFont.ui(14.5))
                    .lineSpacing(3)
            }
            .padding(.top, 18)

            VStack(spacing: 14) {
                InputField(icon: "mail", label: "Почта",
                           value: .constant(email),
                           mono: true)
                    .allowsHitTesting(false)
                    .opacity(0.75)

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Пароль".uppercased())
                            .font(AppFont.ui(11.5, .semibold))
                            .tracking(1)
                            .foregroundStyle(t.faint)
                        Spacer()
                        Text("Забыли?")
                            .font(AppFont.ui(12.5, .semibold))
                            .foregroundStyle(t.accentText)
                    }
                    .padding(.bottom, 8)

                    InputField(icon: "lock",
                               placeholder: "Пароль",
                               value: $password,
                               focused: true,
                               secure: hidden,
                               trailing: AnyView(
                                Button {
                                    hidden.toggle()
                                } label: {
                                    QXIcon(name: hidden ? "eyeOff" : "eye",
                                           size: 19, color: t.faint, weight: .medium)
                                }
                                .buttonStyle(.plain)
                               ))
                }

                if let err = session.lastError {
                    Text(err)
                        .font(AppFont.ui(12.5))
                        .foregroundStyle(t.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.top, 26)

            Spacer(minLength: 0)

            PrimaryButton(
                title: session.loginInFlight ? "Входим…" : "Войти",
                icon: "arrowR"
            ) {
                Task {
                    _ = await session.login(email: email, password: password)
                }
            }
            .disabled(password.isEmpty || session.loginInFlight)
            .opacity(password.isEmpty ? 0.55 : 1)
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
        .padding(.bottom, 24)
        .frame(maxHeight: .infinity)
    }
}
