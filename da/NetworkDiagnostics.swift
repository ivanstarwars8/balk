import Foundation
import SwiftUI
import Combine

/// One reachability/latency probe to a host.
struct Probe: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    var state: ProbeState = .idle
}

enum ProbeState: Equatable {
    case idle
    case running
    case ok(ms: Int)
    case fail

    var latencyMs: Int? { if case .ok(let ms) = self { return ms } else { return nil } }
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
        Probe(name: "BADRIMGU API", url: URL(string: "https://api.badrimgu.com/v1/health")!),
        Probe(name: "Yandex", url: URL(string: "https://ya.ru")!),
        Probe(name: "Google", url: URL(string: "https://www.google.com")!),
        Probe(name: "Cloudflare", url: URL(string: "https://1.1.1.1")!),
    ]
    @Published var speed: SpeedState = .idle
    @Published var running: Bool = false

    private let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 8
        c.timeoutIntervalForResource = 15
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.allowsCellularAccess = true
        return URLSession(configuration: c)
    }()

    func runAll() async {
        guard !running else { return }
        running = true
        defer { running = false }

        // Reset
        for i in probes.indices { probes[i].state = .running }
        speed = .running

        // Latency probes in parallel
        await withTaskGroup(of: (Int, ProbeState).self) { group in
            for (i, probe) in probes.enumerated() {
                group.addTask { [weak self] in
                    let state = await self?.measureLatency(probe.url) ?? .fail
                    return (i, state)
                }
            }
            for await (i, state) in group {
                if probes.indices.contains(i) { probes[i].state = state }
            }
        }

        // Speed test after latency (avoids skewing latency numbers)
        speed = await measureDownloadSpeed()
    }

    /// Latency = time to first response for a lightweight request.
    private func measureLatency(_ url: URL) async -> ProbeState {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("BADRIMGU-iOS/diag", forHTTPHeaderField: "User-Agent")
        let start = Date()
        do {
            let (_, resp) = try await session.data(for: req)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            if let http = resp as? HTTPURLResponse, (200..<500).contains(http.statusCode) {
                return .ok(ms: ms)
            }
            // Any answer (even TLS/redirect) means the host is reachable.
            return .ok(ms: ms)
        } catch {
            return .fail
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
