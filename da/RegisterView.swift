import SwiftUI

/// Native in-app account creation. Shown when the email step reports no
/// existing account. Creating the account here (instead of linking out to the
/// website) both keeps the funnel inside the advertised app and avoids the
/// App Store 3.1.1 "external purchase link" problem — no payment happens here,
/// the backend just grants a short trial so the fresh user can start using it.
struct RegisterView: View {
    @Environment(\.theme) var t
    @EnvironmentObject var session: AuthSession
    let email: String
    var onBack: () -> Void = {}

    @State private var password: String = ""
    @State private var hidden: Bool = true

    // Mirror the backend rules (pwd_validate): ≥8 chars, at least one letter
    // and one digit. Purely to guide the user — the server is authoritative.
    private var longEnough: Bool { password.count >= 8 }
    private var hasLetter: Bool { password.range(of: "\\p{L}", options: .regularExpression) != nil }
    private var hasDigit: Bool { password.range(of: "[0-9]", options: .regularExpression) != nil }
    private var passwordValid: Bool { longEnough && hasLetter && hasDigit }

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
                Text("Создать аккаунт")
                    .font(AppFont.title(30, .bold))
                    .tracking(0.2)
                    .foregroundStyle(t.text)
                Text("Придумайте пароль — аккаунт создастся сразу, а пробный доступ активируется автоматически.")
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("Пароль".uppercased())
                        .font(AppFont.ui(11.5, .semibold))
                        .tracking(1)
                        .foregroundStyle(t.faint)

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

                    HStack(spacing: 6) {
                        QXIcon(name: passwordValid ? "check" : "lock",
                               size: 12,
                               color: passwordValid ? t.success : t.faint,
                               weight: .medium)
                        Text("Минимум 8 символов, буква и цифра")
                            .font(AppFont.ui(12))
                            .foregroundStyle(passwordValid ? t.success : t.faint)
                    }
                    .padding(.horizontal, 2)
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
                title: session.registerInFlight ? "Создаём…" : "Создать аккаунт",
                icon: "arrowR"
            ) {
                Task {
                    _ = await session.register(email: email, password: password)
                }
            }
            .disabled(!passwordValid || session.registerInFlight)
            .opacity(passwordValid ? 1 : 0.55)
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
        .padding(.bottom, 24)
        .frame(maxHeight: .infinity)
    }
}
