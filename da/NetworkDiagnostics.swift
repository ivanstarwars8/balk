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

@MainActor
final class NetworkDiagnostics: ObservableObject {
    @Published var probes: [Probe] = [
        Probe(name: "api.badrimgu.com", host: "api.badrimgu.com"),
        Probe(name: "ya.ru", host: "ya.ru"),
    ]
    @Published var running: Bool = false

    func runAll() async {
        guard !running else { return }
        running = true
        defer { running = false }

        for i in probes.indices { probes[i].state = .running }

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
}
