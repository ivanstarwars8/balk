import Foundation
import SwiftUI
import Combine

@MainActor
final class AuthSession: ObservableObject {
    @Published private(set) var user: AppUser?
    @Published private(set) var subscription: Subscription?
    @Published private(set) var subscriptionURL: SubscriptionURL?
    @Published private(set) var devices: [Device] = []
    @Published private(set) var bootstrapping: Bool = true

    @Published var loginInFlight: Bool = false
    @Published var emailCheckInFlight: Bool = false
    @Published var lastError: String?

    var isAuthenticated: Bool { user != nil }

    init() {
        Task { await bootstrap() }
    }

    func bootstrap() async {
        bootstrapping = true
        defer { bootstrapping = false }
        guard await APIClient.shared.hasRefreshToken() else { return }
        do {
            let me: MeResponse = try await APIClient.shared.get("/me")
            applyMe(me)
        } catch {
            await APIClient.shared.clearTokens()
        }
    }

    /// Returns `true` if email exists. UI uses this to decide whether
    /// to navigate to the password screen or show an "account not found" hint.
    func checkEmail(_ email: String) async -> Bool {
        emailCheckInFlight = true
        lastError = nil
        defer { emailCheckInFlight = false }
        do {
            let r: EmailCheckResponse = try await APIClient.shared.post(
                "/auth/check",
                body: EmailCheckRequest(email: email),
                auth: false
            )
            return r.exists
        } catch {
            lastError = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func login(email: String, password: String) async -> Bool {
        loginInFlight = true
        lastError = nil
        defer { loginInFlight = false }
        do {
            let r: LoginResponse = try await APIClient.shared.post(
                "/auth/login",
                body: LoginRequest(email: email, password: password),
                auth: false
            )
            guard let tokens = r.resolvedTokens else {
                lastError = "Сервер не вернул токены"
                return false
            }
            await APIClient.shared.setTokens(tokens)
            if let u = r.user {
                self.user = u
                self.subscription = r.subscription
                self.subscriptionURL = r.subscription_url
            } else {
                await refreshMe()
            }
            return true
        } catch {
            lastError = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func refreshMe() async {
        do {
            let me: MeResponse = try await APIClient.shared.get("/me")
            applyMe(me)
        } catch {
            lastError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadSubscriptionURL() async {
        do {
            let s: SubscriptionURL = try await APIClient.shared.get("/subscription")
            self.subscriptionURL = s
        } catch APIError.noActiveSubscription {
            self.subscriptionURL = nil
        } catch {
            lastError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadDevices() async {
        do {
            let r: [Device] = try await APIClient.shared.get("/me/devices")
            self.devices = r
        } catch {
            lastError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func revokeDevice(_ id: String) async {
        do {
            let _: EmptyResponse = try await APIClient.shared.postNoBody("/me/devices/\(id)/revoke")
            await loadDevices()
        } catch {
            lastError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Pulls the ready-to-open Happ import deep link from the backend
    /// (encrypted happ://crypt5/… built server-side). The client never
    /// encodes the subscription URL itself — single source of truth.
    func happImportLink() async -> String? {
        do {
            let r: ImportLinkResponse = try await APIClient.shared.get("/import_link")
            return r.link
        } catch {
            lastError = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }

    func lkSession(go: String) async -> URL? {
        do {
            let r: LKSessionResponse = try await APIClient.shared.post(
                "/me/lk_session",
                body: LKSessionRequest(go: go)
            )
            return URL(string: r.url)
        } catch {
            lastError = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }

    func logout() async {
        let _: EmptyResponse? = try? await APIClient.shared.postNoBody("/auth/logout")
        await APIClient.shared.clearTokens()
        KeychainStore.remove("chat_thread_id")
        KeychainStore.remove("chat_guest_token")
        self.user = nil
        self.subscription = nil
        self.subscriptionURL = nil
        self.devices = []
    }

    private func applyMe(_ me: MeResponse) {
        self.user = AppUser(
            id: me.id, email: me.email,
            created_at: me.created_at,
            must_change_password: me.must_change_password
        )
        self.subscription = me.subscription
    }
}
