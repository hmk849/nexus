import Foundation
import Network
import CoreTelephony

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published var satisfied = false
    @Published var interfaces: [String] = []
    @Published var expensive = false
    @Published var constrained = false
    @Published var ipv4 = false
    @Published var ipv6 = false
    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            var ifs: [String] = []
            if path.usesInterfaceType(.wifi) { ifs.append("Wi-Fi") }
            if path.usesInterfaceType(.cellular) { ifs.append("蜂窝") }
            if path.usesInterfaceType(.wiredEthernet) { ifs.append("有线") }
            if path.usesInterfaceType(.other) { ifs.append("其他") }
            let sat = path.status == .satisfied
            let exp = path.isExpensive, con = path.isConstrained
            let v4 = path.supportsIPv4, v6 = path.supportsIPv6
            Task { @MainActor in
                self?.satisfied = sat; self?.interfaces = ifs; self?.expensive = exp
                self?.constrained = con; self?.ipv4 = v4; self?.ipv6 = v6
            }
        }
        monitor.start(queue: DispatchQueue(label: "nexus.network"))
    }

    static func radioTechnologies() -> [String] {
        let info = CTTelephonyNetworkInfo()
        return (info.serviceCurrentRadioAccessTechnology ?? [:]).values.map { t in
            switch t {
            case CTRadioAccessTechnologyNR: "5G NR"
            case CTRadioAccessTechnologyNRNSA: "5G NSA"
            case CTRadioAccessTechnologyLTE: "LTE"
            case CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA: "3G"
            default: t.replacingOccurrences(of: "CTRadioAccessTechnology", with: "")
            }
        }
    }
}

enum SpeedTest {
    struct Result: Sendable { let latencyMs: Double; let mbps: Double; let bytes: Int }

    /// 使用 Cloudflare 公共测速端点（speed.cloudflare.com）。
    static func run() async throws -> Result {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 25
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        let s = URLSession(configuration: cfg)
        let ping = URL(string: "https://speed.cloudflare.com/__down?bytes=0")!
        _ = try await s.data(from: ping)                     // 预热连接
        let t0 = ContinuousClock.now
        _ = try await s.data(from: ping)
        let lat = Benchmark.seconds(t0.duration(to: .now)) * 1000
        let t1 = ContinuousClock.now
        let (data, _) = try await s.data(from: URL(string: "https://speed.cloudflare.com/__down?bytes=10000000")!)
        let sec = max(Benchmark.seconds(t1.duration(to: .now)), 0.001)
        return Result(latencyMs: lat, mbps: Double(data.count) * 8 / sec / 1e6, bytes: data.count)
    }
}
