import Foundation
import SwiftUI
import Combine

@MainActor
final class AuthSession: ObservableObject {
    @Published private(set) var user: AppUser?
    @Published private(set) var subscription: Subscription?
    @Published private(set) var subscriptionURL: SubscriptionURL?
    @Published private(set) var devices: [Device] = []
    @Published private(set) var notices: [Notice] = []
    @Published private(set) var bootstrapping: Bool = true

    @Published var loginInFlight: Bool = false
    @Published var emailCheckInFlight: Bool = false
    @Published var lastError: String?

    var isAuthenticated: Bool { user != nil }

    init() {
        if let data = UserDefaults.standard.data(forKey: "notices_cache"),
           let cached = try? JSONDecoder().decode([Notice].self, from: data) {
            self.notices = cached
        }
        Task { await bootstrap() }
    }

    func bootstrap() async {
        bootstrapping = true
        defer { bootstrapping = false }
        guard await APIClient.shared.hasRefreshToken() else { return }
        // Show the cached identity instantly and stay signed in when the app
        // launches offline — the network refresh continues behind the UI
        // (bootstrapping=false drops the splash right away).
        if let cached = loadCachedMe() {
            applyMe(cached)
            bootstrapping = false
        }
        do {
            let me: MeResponse = try await APIClient.shared.get("/me")
            applyMe(me)
            saveCachedMe(me)
        } catch APIError.unauthenticated {
            // The refresh token is really dead — only then drop the session.
            await APIClient.shared.clearTokens()
            removeCachedMe()
            self.user = nil
            self.subscription = nil
        } catch {
            // Network/server hiccup: keep the cached session. First-ever launch
            // with no cache falls through to the login screen as before.
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
                lastError = String(localized: "Сервер не вернул токены")
                return false
            }
            await APIClient.shared.setTokens(tokens)
            if let u = r.user {
                self.user = u
                self.subscription = r.subscription
                self.subscriptionURL = r.subscription_url
                saveCachedMe(MeResponse(
                    id: u.id ?? "", email: u.email ?? "",
                    created_at: u.created_at,
                    must_change_password: u.must_change_password,
                    subscription: r.subscription
                ))
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
            saveCachedMe(me)
        } catch {
            lastError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Backend-managed notice board. Public endpoint; text comes back already
    /// localized. Cached so the board survives offline launches.
    func loadNotices() async {
        do {
            let lang = Locale.preferredLanguages.first?.lowercased().hasPrefix("ru") == true ? "ru" : "en"
            let r: NoticesResponse = try await APIClient.shared.get("/notices?lang=\(lang)", auth: false)
            self.notices = r.notices
            if let data = try? JSONEncoder().encode(r.notices) {
                UserDefaults.standard.set(data, forKey: "notices_cache")
            }
        } catch {
            // Offline / server error: keep whatever the cache gave us.
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
        removeCachedMe()
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

    // MARK: - /me cache (offline launches keep the session alive)

    private func saveCachedMe(_ me: MeResponse) {
        if let data = try? JSONEncoder().encode(me),
           let json = String(data: data, encoding: .utf8) {
            KeychainStore.set(json, key: "me_cache")
        }
    }

    private func loadCachedMe() -> MeResponse? {
        guard let json = KeychainStore.get("me_cache"),
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(MeResponse.self, from: data)
    }

    private func removeCachedMe() {
        KeychainStore.remove("me_cache")
    }
}
