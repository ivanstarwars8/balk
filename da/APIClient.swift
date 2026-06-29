import Foundation

enum APIError: Error, LocalizedError {
    case http(Int, String)
    case noActiveSubscription(String?)
    case unauthenticated
    case noNetwork(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .http(let code, let msg):
            return msg.isEmpty ? "Ошибка сервера (\(code))" : msg
        case .noActiveSubscription: return "Подписка истекла или отсутствует"
        case .unauthenticated: return "Войдите в аккаунт заново"
        case .noNetwork(let m): return "Нет сети: \(m)"
        case .decoding(let m): return "Не удалось прочитать ответ: \(m)"
        }
    }
}

actor APIClient {
    static let shared = APIClient()

    private let baseURL = URL(string: "https://api.badrimgu.com/v1")!
    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 20
        c.timeoutIntervalForResource = 30
        c.waitsForConnectivity = true
        return URLSession(configuration: c)
    }()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private var accessToken: String?
    private var refreshToken: String?
    private var refreshTask: Task<Void, Error>?

    init() {
        self.accessToken = KeychainStore.get("access_token")
        self.refreshToken = KeychainStore.get("refresh_token")
    }

    func hasRefreshToken() -> Bool { refreshToken != nil }

    func setTokens(_ t: Tokens) {
        accessToken = t.access_token
        refreshToken = t.refresh_token
        KeychainStore.set(t.access_token, key: "access_token")
        KeychainStore.set(t.refresh_token, key: "refresh_token")
    }

    func clearTokens() {
        accessToken = nil
        refreshToken = nil
        KeychainStore.remove("access_token")
        KeychainStore.remove("refresh_token")
    }

    // MARK: - Public verbs

    func get<T: Decodable>(_ path: String, auth: Bool = true) async throws -> T {
        try await send(method: "GET", path: path, bodyData: nil, auth: auth)
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B, auth: Bool = true) async throws -> T {
        let data = try encoder.encode(body)
        return try await send(method: "POST", path: path, bodyData: data, auth: auth)
    }

    func postNoBody<T: Decodable>(_ path: String, auth: Bool = true) async throws -> T {
        try await send(method: "POST", path: path, bodyData: nil, auth: auth)
    }

    // MARK: - Core

    private func send<T: Decodable>(method: String, path: String,
                                    bodyData: Data?, auth: Bool) async throws -> T {
        var (data, http) = try await perform(method: method, path: path,
                                             bodyData: bodyData, auth: auth)
        if http.statusCode == 401 && auth && refreshToken != nil {
            try await refreshIfNeeded()
            (data, http) = try await perform(method: method, path: path,
                                             bodyData: bodyData, auth: auth)
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = try? decoder.decode(APIErrorBody.self, from: data)
            let code = body?.error ?? body?.code
            // Special-case 402 with checkout_url so the UI can route to payment.
            if http.statusCode == 402 || code == "no_active_subscription" {
                throw APIError.noActiveSubscription(body?.checkout_url)
            }
            let msg = humanizeError(code: code, status: http.statusCode,
                                    fallback: body?.message)
            throw APIError.http(http.statusCode, msg)
        }
        // 204 or empty body with EmptyResponse target → succeed without decoding
        if T.self == EmptyResponse.self,
           let empty = EmptyResponse() as? T { return empty }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? ""
            let cleaned = raw.replacingOccurrences(
                of: #"eyJ[A-Za-z0-9_\-]+\.eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+"#,
                with: "<JWT>", options: .regularExpression
            )
            let preview = cleaned.prefix(600)
            throw APIError.decoding("\(error.localizedDescription) · ответ: \(preview)")
        }
    }

    private func humanizeError(code: String?, status: Int, fallback: String?) -> String {
        if let code {
            switch code {
            case "invalid_credentials":     return "Неверная почта или пароль"
            case "account_locked":          return "Аккаунт временно заблокирован (5 ошибок подряд). Подождите 30 минут."
            case "no_active_subscription":  return "Подписка истекла или отсутствует"
            case "device_not_found":        return "Устройство не найдено"
            case "invalid_go":              return "Некорректный параметр"
            case "rate_limited":            return "Слишком много запросов, попробуйте позже"
            case "invalid_token", "token_revoked", "token_expired":
                                            return "Сессия истекла"
            default: break
            }
        }
        if let fb = fallback, !fb.isEmpty { return fb }
        if let c = code, !c.isEmpty { return "Ошибка: \(c)" }
        return "Ошибка сервера (\(status))"
    }

    private func perform(method: String, path: String,
                         bodyData: Data?, auth: Bool) async throws -> (Data, HTTPURLResponse) {
        let url = baseURL.appendingPathComponent(
            path.hasPrefix("/") ? String(path.dropFirst()) : path
        )
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if auth, let at = accessToken {
            req.setValue("Bearer \(at)", forHTTPHeaderField: "Authorization")
        }
        if let bodyData {
            req.httpBody = bodyData
        }
        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                throw APIError.noNetwork("invalid response")
            }
            return (data, http)
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.noNetwork(error.localizedDescription)
        }
    }

    private func refreshIfNeeded() async throws {
        if let task = refreshTask {
            try await task.value
            return
        }
        let task = Task { try await self.doRefresh() }
        refreshTask = task
        defer { refreshTask = nil }
        try await task.value
    }

    private func doRefresh() async throws {
        guard let rt = refreshToken else { throw APIError.unauthenticated }
        let body = try encoder.encode(RefreshRequest(refresh_token: rt))
        let (data, http) = try await perform(method: "POST", path: "/auth/refresh",
                                             bodyData: body, auth: false)
        guard http.statusCode == 200 else {
            clearTokens()
            throw APIError.unauthenticated
        }
        let r = try decoder.decode(RefreshResponse.self, from: data)
        guard let tokens = r.resolvedTokens else {
            clearTokens()
            throw APIError.unauthenticated
        }
        setTokens(tokens)
    }
}
