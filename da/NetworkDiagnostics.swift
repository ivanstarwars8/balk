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

    /// Downloads a fixed-size payload and computes throughput in Mbit/s.
    private func measureDownloadSpeed() async -> SpeedState {
        // Cloudflare's speed endpoint returns arbitrary bytes fast, worldwide.
        let bytes = 8_000_000
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=\(bytes)") else {
            return .fail
        }
        var req = URLRequest(url: url)
        req.setValue("BADRIMGU-iOS/diag", forHTTPHeaderField: "User-Agent")
        let start = Date()
        do {
            let (data, resp) = try await session.data(for: req)
            let seconds = Date().timeIntervalSince(start)
            guard let http = resp as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  seconds > 0, !data.isEmpty else { return .fail }
            let mbps = (Double(data.count) * 8) / seconds / 1_000_000
            return .done(mbps: mbps)
        } catch {
            return .fail
        }
    }
}
