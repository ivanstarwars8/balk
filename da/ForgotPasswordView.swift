import SwiftUI

/// Password recovery inside the app: request a 6-digit code by email, then
/// type it with a new password. Mirrors the website's "Забыли пароль?" flow —
/// both consume the same /auth/forgot + /auth/reset endpoints.
struct ForgotPasswordView: View {
    @Environment(\.theme) var t
    @EnvironmentObject var session: AuthSession
    @Environment(\.dismiss) var dismiss
    let email: String

    private enum Step { case request, reset, done }
    @State private var step: Step = .request
    @State private var code: String = ""
    @State private var password: String = ""
    @State private var hidden: Bool = true
    @State private var inFlight: Bool = false

    // Mirror the backend rules (pwd_validate): ≥8 chars, letter + digit.
    private var passwordValid: Bool {
        password.count >= 8
            && password.range(of: "\\p{L}", options: .regularExpression) != nil
            && password.range(of: "[0-9]", options: .regularExpression) != nil
    }
    private var codeValid: Bool { code.filter(\.isNumber).count == 6 }

    var body: some View {
        ZStack {
            t.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 3) {
                        QXIcon(name: "chevL", size: 22, color: t.accentText, weight: .semibold)
                        Text("Назад")
                            .font(AppFont.ui(17))
                            .foregroundStyle(t.accentText)
                    }
                }
                .buttonStyle(.plain)
                .frame(minHeight: 36)

                switch step {
                case .request: requestStep
                case .reset:   resetStep
                case .done:    doneStep
                }

                Spacer(minLength: 0)

                actionButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private var requestStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Восстановление пароля")
                .font(AppFont.title(28, .bold))
                .tracking(0.2)
                .foregroundStyle(t.text)
            Text("Отправим 6-значный код на вашу почту. Введите его на следующем шаге вместе с новым паролем.")
                .foregroundStyle(t.muted)
                .font(AppFont.ui(14.5))
                .lineSpacing(3)

            InputField(icon: "mail", label: "Почта",
                       value: .constant(email),
                       mono: true)
                .allowsHitTesting(false)
                .opacity(0.75)
                .padding(.top, 16)

            if let err = session.lastError {
                errorText(err)
            }
        }
        .padding(.top, 18)
    }

    private var resetStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Код отправлен")
                .font(AppFont.title(28, .bold))
                .tracking(0.2)
                .foregroundStyle(t.text)
            Text(LX("Письмо ушло на \(email). Код действует 15 минут — если письма нет, проверьте «Спам»."))
                .foregroundStyle(t.muted)
                .font(AppFont.ui(14.5))
                .lineSpacing(3)

            VStack(spacing: 14) {
                InputField(icon: "key", label: "Код из письма",
                           placeholder: "6 цифр",
                           value: $code,
                           mono: true)
                    .keyboardType(.numberPad)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Новый пароль".uppercased())
                        .font(AppFont.ui(11.5, .semibold))
                        .tracking(1)
                        .foregroundStyle(t.faint)
                    InputField(icon: "lock",
                               placeholder: "Новый пароль",
                               value: $password,
                               secure: hidden,
                               trailing: AnyView(
                                Button { hidden.toggle() } label: {
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
            }
            .padding(.top, 16)

            if let err = session.lastError {
                errorText(err)
            }
        }
        .padding(.top, 18)
    }

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle().fill(t.success.opacity(0.16)).frame(width: 64, height: 64)
                QXIcon(name: "check", size: 30, color: t.success, weight: .semibold)
            }
            .padding(.bottom, 8)
            Text("Пароль изменён")
                .font(AppFont.title(28, .bold))
                .tracking(0.2)
                .foregroundStyle(t.text)
            Text("Войдите с новым паролем.")
                .foregroundStyle(t.muted)
                .font(AppFont.ui(14.5))
        }
        .padding(.top, 30)
    }

    private var actionButton: some View {
        Group {
            switch step {
            case .request:
                PrimaryButton(title: inFlight ? "Отправляем…" : "Отправить код",
                              icon: "send") { sendCode() }
                    .disabled(inFlight)
            case .reset:
                PrimaryButton(title: inFlight ? "Меняем…" : "Сменить пароль",
                              icon: "arrowR") { applyReset() }
                    .disabled(!codeValid || !passwordValid || inFlight)
                    .opacity((codeValid && passwordValid) ? 1 : 0.55)
            case .done:
                PrimaryButton(title: "Ко входу", icon: "arrowR") { dismiss() }
            }
        }
    }

    private func errorText(_ err: String) -> some View {
        Text(err)
            .font(AppFont.ui(12.5))
            .foregroundStyle(t.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }

    private func sendCode() {
        guard !inFlight else { return }
        inFlight = true
        Task {
            let ok = await session.requestPasswordReset(email: email)
            await MainActor.run {
                inFlight = false
                if ok { step = .reset }
            }
        }
    }

    private func applyReset() {
        guard !inFlight else { return }
        inFlight = true
        Task {
            let ok = await session.resetPassword(email: email,
                                                 code: code.filter(\.isNumber),
                                                 newPassword: password)
            await MainActor.run {
                inFlight = false
                if ok { step = .done }
            }
        }
    }
}
