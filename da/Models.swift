import Foundation

struct Tokens: Codable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int
}

struct AppUser: Codable, Equatable {
    let id: String?
    let email: String?
    let created_at: String?
    let must_change_password: Bool?
}

struct Subscription: Codable, Equatable {
    let status: String?
    let expires_at: String?
    let traffic_used_bytes: Int64?
    let traffic_limit_bytes: Int64?
    let plan: String?
    let devices_used: Int?
    let devices_limit: Int?
}

struct SubscriptionURL: Codable, Equatable {
    let url: String
    let format: String
    let user_agent: String?
    let ttl_seconds: Int
    let expires_at: String
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

/// Login can return either flat tokens or nested in "tokens". We accept both.
struct LoginResponse: Codable {
    let access_token: String?
    let refresh_token: String?
    let expires_in: Int?
    let tokens: Tokens?
    let user: AppUser?
    let subscription: Subscription?
    let subscription_url: SubscriptionURL?

    var resolvedTokens: Tokens? {
        if let t = tokens { return t }
        guard let a = access_token, let r = refresh_token else { return nil }
        return Tokens(access_token: a, refresh_token: r, expires_in: expires_in ?? 900)
    }
}

struct MeResponse: Codable {
    let id: String
    let email: String
    let created_at: String?
    let must_change_password: Bool?
    let subscription: Subscription?
}

struct EmailCheckRequest: Codable { let email: String }
struct EmailCheckResponse: Codable { let exists: Bool }
struct RefreshRequest: Codable { let refresh_token: String }
struct RefreshResponse: Codable {
    let access_token: String?
    let refresh_token: String?
    let expires_in: Int?
    let tokens: Tokens?

    var resolvedTokens: Tokens? {
        if let t = tokens { return t }
        guard let a = access_token, let r = refresh_token else { return nil }
        return Tokens(access_token: a, refresh_token: r, expires_in: expires_in ?? 900)
    }
}

struct Device: Codable, Identifiable, Equatable {
    let id: String
    let model: String?
    let os: String?
    let platform: String?
    let first_seen: String?
    let last_seen: String?
}

struct LKSessionRequest: Codable { let go: String }
struct LKSessionResponse: Codable { let url: String }

struct APIErrorBody: Codable {
    let error: String?
    let message: String?
    let code: String?
    let until: String?
    let checkout_url: String?
}

struct EmptyResponse: Codable {}
struct EmptyBody: Encodable {}

// MARK: - Support chat (badrimgu.com/lk/api)

struct SupportOpenRequest: Codable {
    let mode: String
    let identifier: String?
}

struct SupportOpenResponse: Codable {
    let ok: Bool
    let thread_id: Int
    let guest_token: String
    let display: String?
    let mode: String?
}

struct ChatSendRequest: Codable {
    let thread_id: Int
    let guest_token: String
    let body: String
}

struct ChatAttachment: Codable, Equatable {
    let url: String?
    let kind: String?
}

struct ChatMessage: Codable, Identifiable, Equatable {
    let id: Int
    let sender_type: String
    let body: String
    let created_at: String
    let attachments: [ChatAttachment]?

    var isMe: Bool { sender_type == "user" }
    var isSystem: Bool { sender_type == "system" }

    /// Extracts HH:mm from "2026-06-22 16:04:02.421894+00" or "2026-06-22T16:04:02Z"
    var displayTime: String {
        let stripped = created_at.replacingOccurrences(of: "T", with: " ")
        let parts = stripped.split(separator: " ")
        guard parts.count > 1 else { return "" }
        return String(parts[1].prefix(5))
    }
}

struct ChatSendResponse: Codable {
    let ok: Bool
    let message_id: Int?
    let attachments: [ChatAttachment]?
}

struct ChatPollResponse: Codable {
    let ok: Bool
    let thread_id: Int?
    let status: String?
    let messages: [ChatMessage]
    let unread: Int?
}
