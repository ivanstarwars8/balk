import Foundation
import SwiftUI
import Combine

@MainActor
final class ChatSession: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var bootstrapping: Bool = false
    @Published private(set) var sending: Bool = false
    @Published var error: String?

    private var threadId: Int?
    private var guestToken: String?
    private var lastId: Int = 0
    private var pollTask: Task<Void, Never>?

    private let threadKey = "chat_thread_id"
    private let tokenKey = "chat_guest_token"

    var isReady: Bool { threadId != nil && guestToken != nil }

    init() { restoreFromKeychain() }

    private func restoreFromKeychain() {
        if let s = KeychainStore.get(threadKey), let id = Int(s) { threadId = id }
        guestToken = KeychainStore.get(tokenKey)
    }

    /// Open or resume a thread. `email` taken from AuthSession.
    func start(email: String?) async {
        if isReady {
            startPolling()
            return
        }
        bootstrapping = true
        defer { bootstrapping = false }
        do {
            let r = try await ChatClient.shared.open(email: email)
            threadId = r.thread_id
            guestToken = r.guest_token
            KeychainStore.set("\(r.thread_id)", key: threadKey)
            KeychainStore.set(r.guest_token, key: tokenKey)
            startPolling()
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func clearLocal() {
        stop()
        threadId = nil
        guestToken = nil
        messages = []
        lastId = 0
        KeychainStore.remove(threadKey)
        KeychainStore.remove(tokenKey)
    }

    func send(_ text: String) async {
        guard let tid = threadId, let tok = guestToken else { return }
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        sending = true
        defer { sending = false }
        do {
            _ = try await ChatClient.shared.send(threadId: tid, token: tok, body: body)
            await pollOnce()
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollOnce()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    func pollOnce() async {
        guard let tid = threadId, let tok = guestToken else { return }
        do {
            let r = try await ChatClient.shared.poll(threadId: tid, token: tok, sinceId: lastId)
            if !r.messages.isEmpty {
                let merged = (messages + r.messages)
                    .reduce(into: [Int: ChatMessage]()) { $0[$1.id] = $1 }
                    .values
                    .sorted { $0.id < $1.id }
                self.messages = Array(merged)
                self.lastId = max(lastId, r.messages.map(\.id).max() ?? lastId)
            }
        } catch {
            // Silent for polling errors; surface only on manual action
        }
    }
}
