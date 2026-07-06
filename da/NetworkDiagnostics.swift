import Foundation
import SwiftUI
import Combine

/// One DNS-resolution probe for a host.
struct Probe: Identifiable {
    let id = UUID()
    let name: String
    let host: String
    var state: ProbeState = .idle
}

enum ProbeState: Equatable {
    case idle
    case running
    case ok       // DNS resolved
    case fail     // DNS failed
}

/// Result of the download speed test.
enum SpeedState: Equatable {
    case idle
    case running
    case done(mbps: Double)
    case fail
}

@MainActor
final class NetworkDiagnostics: ObservableObject {
    @Published var probes: [Probe] = [
        Probe(name: "api.badrimgu.com", host: "api.badrimgu.com"),
        Probe(name: "ya.ru", host: "ya.ru"),
    ]
    @Published var speed: SpeedState = .idle
    @Published var running: Bool = false

    func runAll() async {
        guard !running else { return }
        running = true
        defer { running = false }

        for i in probes.indices { probes[i].state = .running }
        speed = .running

        // DNS resolution checks in parallel
        await withTaskGroup(of: (Int, ProbeState).self) { group in
            for (i, probe) in probes.enumerated() {
                let host = probe.host
                group.addTask { (i, await Self.resolveDNS(host)) }
            }
            for await (i, state) in group {
                if probes.indices.contains(i) { probes[i].state = state }
            }
        }

        speed = await measureDownloadSpeed()
    }

    /// DNS resolution check via getaddrinfo — succeeds if the host resolves to
    /// at least one address. Runs off the main thread.
    nonisolated static func resolveDNS(_ host: String) async -> ProbeState {
        await withCheckedContinuation { (cont: CheckedContinuation<ProbeState, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                var hints = addrinfo(ai_flags: 0, ai_family: AF_UNSPEC,
                                     ai_socktype: SOCK_STREAM, ai_protocol: 0,
                                     ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil)
                var result: UnsafeMutablePointer<addrinfo>?
                let err = getaddrinfo(host, nil, &hints, &result)
                if let result { freeaddrinfo(result) }
                cont.resume(returning: err == 0 ? .ok : .fail)
            }
        }
    }

    /// Streams a large payload and measures throughput over a fixed time
    /// window, so it never fails on a timeout: whatever arrived in the window
    /// is the speed. Works on both slow and fast links. Tries a big Cloudflare
    /// stream first, then a Yandex mirror file as a Russia-friendly fallback.
    private func measureDownloadSpeed() async -> SpeedState {
        let sources = [
            "https://speed.cloudflare.com/__down?bytes=100000000",
            "https://mirror.yandex.ru/gnu/bash/bash-5.2.tar.gz",
        ]
        for s in sources {
            guard let url = URL(string: s) else { continue }
            let mbps = await SpeedMeter(window: 6).run(url: url)
            if mbps > 0.05 { return .done(mbps: mbps) }
        }
        return .fail
    }
}

/// Delegate-based download meter: accumulates bytes and stops after a time
/// window, reporting Mbit/s. `@unchecked Sendable` + NSLock because URLSession
/// delivers callbacks on a background queue (the project defaults types to the
/// main actor, so the delegate methods are explicitly `nonisolated`).
final class SpeedMeter: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var received = 0
    private var start = Date()
    private var done = false
    private var cont: CheckedContinuation<Double, Never>?
    private var task: URLSessionDataTask?
    private let window: TimeInterval

    init(window: TimeInterval) { self.window = window; super.init() }

    nonisolated func run(url: URL) async -> Double {
        await withCheckedContinuation { (c: CheckedContinuation<Double, Never>) in
            let cfg = URLSessionConfiguration.ephemeral
            cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
            cfg.timeoutIntervalForRequest = 15
            cfg.timeoutIntervalForResource = window + 10
            let s = URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
            var req = URLRequest(url: url)
            req.setValue("BADRIMGU-iOS/diag", forHTTPHeaderField: "User-Agent")
            lock.lock(); cont = c; start = Date(); let t = s.dataTask(with: req); task = t; lock.unlock()
            t.resume()
        }
    }

    nonisolated func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        received += data.count
        let elapsed = Date().timeIntervalSince(start)
        lock.unlock()
        if elapsed >= window { finish() }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        finish()
    }

    private nonisolated func finish() {
        lock.lock()
        if done { lock.unlock(); return }
        done = true
        let c = cont; cont = nil
        let bytes = received
        let elapsed = max(Date().timeIntervalSince(start), 0.001)
        let t = task
        lock.unlock()
        t?.cancel()
        let mbps = Double(bytes) * 8 / elapsed / 1_000_000
        c?.resume(returning: mbps)
    }
}
