import Foundation

actor ChatClient {
    static let shared = ChatClient()

    private let baseURL = URL(string: "https://badrimgu.com/lk/api")!
    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 15
        c.timeoutIntervalForResource = 25
        c.waitsForConnectivity = true
        return URLSession(configuration: c)
    }()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func open(email: String?) async throws -> SupportOpenResponse {
        let req: SupportOpenRequest = email.map {
            SupportOpenRequest(mode: "email", identifier: $0)
        } ?? SupportOpenRequest(mode: "anonymous", identifier: nil)
        do {
            return try await post(path: "public_support_open.php", body: req)
        } catch APIError.http(404, _) {
            // Email not found in account base — fallback to anonymous
            return try await post(
                path: "public_support_open.php",
                body: SupportOpenRequest(mode: "anonymous", identifier: nil)
            )
        }
    }

    func send(threadId: Int, token: String, body: String) async throws -> ChatSendResponse {
        try await post(
            path: "public_chat_send.php",
            body: ChatSendRequest(thread_id: threadId, guest_token: token, body: body)
        )
    }

    func poll(threadId: Int, token: String, sinceId: Int) async throws -> ChatPollResponse {
        var comp = URLComponents(url: baseURL.appendingPathComponent("public_chat_poll.php"),
                                 resolvingAgainstBaseURL: false)!
        comp.queryItems = [
            URLQueryItem(name: "thread_id", value: "\(threadId)"),
            URLQueryItem(name: "guest_token", value: token),
            URLQueryItem(name: "since_id", value: "\(sinceId)")
        ]
        var req = URLRequest(url: comp.url!)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(req)
    }

    // MARK: - Internals

    private func post<B: Encodable, T: Decodable>(path: String, body: B) async throws -> T {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try encoder.encode(body)
        return try await perform(req)
    }

    private func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw APIError.noNetwork(error.localizedDescription)
        }
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.noNetwork("invalid response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = try? decoder.decode(APIErrorBody.self, from: data)
            throw APIError.http(http.statusCode, body?.error ?? body?.message ?? "")
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let preview = String(data: data, encoding: .utf8)?.prefix(300) ?? ""
            throw APIError.decoding("\(error.localizedDescription) · ответ: \(preview)")
        }
    }
}
