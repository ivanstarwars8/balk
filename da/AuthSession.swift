import Foundation
import SwiftUI
import Combine

@MainActor
final class AuthSession: ObservableObject {
    @Published private(set) var user: AppUser?
    @Published private(set) var subscription: Subscription?
    @Published private(set) var subscriptionURL: SubscriptionURL?
    // True ONLY when the server explicitly said there's no active subscription
    // (a clean 402/no_active_subscription). Stays false when we simply couldn't
    // reach the server (offline) — so the UI never shows "expired" on a network
    // hiccup and never hides the install/import buttons.
    @Published private(set) var subscriptionKnownEmpty: Bool = false
    @Published private(set) var devices: [Device] = []
    @Published private(set) var notices: [Notice] = []
    @Published private(set) var guides: [GuideTopic] = []
    @Published private(set) var bootstrapping: Bool = true

    @Published var loginInFlight: Bool = false
    @Published var registerInFlight: Bool = false
    @Published var emailCheckInFlight: Bool = false
    @Published var lastError: String?

    var isAuthenticated: Bool { user != nil }

    init() {
        if let data = UserDefaults.standard.data(forKey: "notices_cache"),
           let cached = try? JSONDecoder().decode([Notice].self, from: data) {
            self.notices = cached
        }
        if let data = UserDefaults.standard.data(forKey: "guides_cache"),
           let cached = try? JSONDecoder().decode([GuideTopic].self, from: data) {
            self.guides = cached
        }
        // Restore the last-known subscription link so an offline launch keeps the
        // "Импортировать в Happ" button working instead of showing "недоступна".
        if let data = UserDefaults.standard.data(forKey: "sub_url_cache"),
           let cached = try? JSONDecoder().decode(SubscriptionURL.self, from: data) {
            self.subscriptionURL = cached
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

    /// Creates a brand-new account in-app (email + password) and signs in
    /// immediately. The backend grants a short trial so the fresh user can
    /// import a working config right away. Returns false on validation/server
    /// error (message in `lastError`).
    func register(email: String, password: String) async -> Bool {
        registerInFlight = true
        lastError = nil
        defer { registerInFlight = false }
        do {
            let r: LoginResponse = try await APIClient.shared.post(
                "/auth/register",
                body: RegisterRequest(email: email, password: password),
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

    /// Backend-managed instruction content. Public endpoint; text arrives
    /// already localized. Cached so the guide survives offline launches.
    func loadGuides() async {
        do {
            let lang = Locale.preferredLanguages.first?.lowercased().hasPrefix("ru") == true ? "ru" : "en"
            let r: GuidesResponse = try await APIClient.shared.get("/guides?lang=\(lang)", auth: false)
            self.guides = r.guides
            if let data = try? JSONEncoder().encode(r.guides) {
                UserDefaults.standard.set(data, forKey: "guides_cache")
            }
        } catch {
            // Offline / server error: keep whatever the cache gave us.
        }
    }

    /// Refresh the subscription link at most once per `maxAge` (default 24h).
    /// The import deep link is stable, so there's no need to re-hit /subscription
    /// on every screen open — the cached link keeps "Импортировать в Happ" alive
    /// (including offline). Pull-to-refresh still forces a fresh fetch.
    func loadSubscriptionURLIfStale(maxAge: TimeInterval = 86_400) async {
        let last = UserDefaults.standard.double(forKey: "sub_url_fetched_at")
        let age  = Date().timeIntervalSince1970 - last
        if subscriptionURL != nil && last > 0 && age < maxAge { return }
        await loadSubscriptionURL()
    }

    func loadSubscriptionURL() async {
        do {
            let s: SubscriptionURL = try await APIClient.shared.get("/subscription")
            self.subscriptionURL = s
            self.subscriptionKnownEmpty = false
            if let data = try? JSONEncoder().encode(s) {
                UserDefaults.standard.set(data, forKey: "sub_url_cache")
            }
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "sub_url_fetched_at")
        } catch APIError.noActiveSubscription {
            // Confirmed by the server: really no active subscription.
            self.subscriptionURL = nil
            self.subscriptionKnownEmpty = true
            UserDefaults.standard.removeObject(forKey: "sub_url_cache")
        } catch {
            // Offline / transient error: keep the cached link and DON'T flag empty.
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
        // Remove the push token while still authenticated (DELETE needs Bearer).
        if let pushToken = PushCenter.shared.token {
            await APIClient.shared.unregisterPushToken(pushToken)
        }
        let _: EmptyResponse? = try? await APIClient.shared.postNoBody("/auth/logout")
        await APIClient.shared.clearTokens()
        KeychainStore.remove("chat_thread_id")
        KeychainStore.remove("chat_guest_token")
        removeCachedMe()
        self.user = nil
        self.subscription = nil
        self.subscriptionURL = nil
        self.subscriptionKnownEmpty = false
        self.devices = []
        UserDefaults.standard.removeObject(forKey: "sub_url_cache")
        UserDefaults.standard.removeObject(forKey: "sub_url_fetched_at")
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
