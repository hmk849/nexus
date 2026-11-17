import Foundation
import SwiftUI

enum LoadState: Equatable { case idle, loading, loaded, failed(String) }

struct CVEItem: Identifiable, Sendable, Hashable {
    let id: String
    let published: String
    let summary: String
    let score: Double?
    let severity: String?
    var versions: [String]
    var url: String { "https://nvd.nist.gov/vuln/detail/\(id)" }
    var risk: RiskLevel {
        switch severity?.uppercased() { case "CRITICAL", "HIGH": .high; case "MEDIUM": .medium; case "LOW": .low; default: .none }
    }
}

private struct NVDResponse: Decodable { let vulnerabilities: [NVDItem] }
private struct NVDItem: Decodable { let cve: NVDCVE }
private struct NVDCVE: Decodable {
    let id: String, published: String
    let descriptions: [NVDDesc]
    let metrics: NVDMetrics?
}
private struct NVDDesc: Decodable { let lang: String, value: String }
private struct NVDMetrics: Decodable { let cvssMetricV40: [NVDMetric]?, cvssMetricV31: [NVDMetric]?, cvssMetricV30: [NVDMetric]? }
private struct NVDMetric: Decodable { let cvssData: NVDScore }
private struct NVDScore: Decodable { let baseScore: Double, baseSeverity: String? }

enum NVDService {
    /// NVD API 2.0：按「iPadOS」关键词检索最近 110 天发布的 CVE（Apple 的公告同时写 iOS 与 iPadOS，可排除思科 IOS 噪声）。
    static func recent() async throws -> [CVEItem] {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        let end = Date(), start = end.addingTimeInterval(-110 * 86400)
        var c = URLComponents(string: "https://services.nvd.nist.gov/rest/json/cves/2.0")!
        c.queryItems = [URLQueryItem(name: "keywordSearch", value: "iPadOS"),
                        URLQueryItem(name: "pubStartDate", value: f.string(from: start)),
                        URLQueryItem(name: "pubEndDate", value: f.string(from: end)),
                        URLQueryItem(name: "resultsPerPage", value: "200")]
        var req = URLRequest(url: c.url!)
        req.timeoutInterval = 30
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let r = try JSONDecoder().decode(NVDResponse.self, from: data)
        let regex = try? NSRegularExpression(pattern: "(iOS|iPadOS) [0-9]+(\\.[0-9]+)*")
        return r.vulnerabilities.map { v in
            let text = v.cve.descriptions.first { $0.lang == "en" }?.value ?? v.cve.descriptions.first?.value ?? ""
            let m = v.cve.metrics
            let metric = m?.cvssMetricV40?.first ?? m?.cvssMetricV31?.first ?? m?.cvssMetricV30?.first
            let ns = text as NSString
            let vers = regex?.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) } ?? []
            return CVEItem(id: v.cve.id, published: String(v.cve.published.prefix(10)), summary: text,
                           score: metric?.cvssData.baseScore, severity: metric?.cvssData.baseSeverity,
                           versions: Array(NSOrderedSet(array: vers)) as? [String] ?? vers)
        }.sorted { $0.published > $1.published }
    }
}

@MainActor
final class ResearchStore: ObservableObject {
    @Published var metas: [String: RepoMeta] = [:]
    @Published var loading = false
    @Published var progress = 0.0
    @Published var message: String?
    @Published var discovered: [RepoMeta] = []
    @Published var discoverState: LoadState = .idle
    @Published var cves: [CVEItem] = []
    @Published var cveState: LoadState = .idle
    let seeds = Catalog.seeds

    init() {
        Task {
            metas = await GitHubService.shared.cached()
            await refreshAll(force: false)
        }
    }

    func seed(_ fullName: String) -> RepoSeed? { seeds.first { $0.fullName == fullName } }

    func refreshAll(force: Bool) async {
        guard !loading else { return }
        loading = true; progress = 0
        defer { loading = false }
        var done = 0
        for s in seeds {
            metas[s.fullName] = await GitHubService.shared.fetch(s.fullName, force: force)
            done += 1; progress = Double(done) / Double(seeds.count)
        }
        message = await GitHubService.shared.isRateLimited
            ? "GitHub API 速率受限，部分数据来自缓存。可在 设置 → GitHub 中填写个人访问令牌以提高额度。" : nil
    }

    func refreshExtras(_ ids: [String]) async {
        for id in ids where seed(id) == nil { metas[id] = await GitHubService.shared.fetch(id, force: false) }
    }

    func ensureRelease(_ fullName: String) async {
        metas[fullName] = await GitHubService.shared.fetchRelease(fullName)
    }

    func discover(_ query: String) async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        discoverState = .loading
        do {
            let r = try await GitHubService.shared.search(q)
            discovered = r
            for m in r { metas[m.fullName] = metas[m.fullName] ?? m }
            discoverState = .loaded
        } catch {
            discoverState = .failed(await GitHubService.shared.isRateLimited ? "GitHub 搜索速率受限（未登录每分钟 10 次），请稍后再试或配置令牌" : "搜索失败：\(error.localizedDescription)")
        }
    }

    func loadCVEs() async {
        cveState = .loading
        do { cves = try await NVDService.recent(); cveState = .loaded }
        catch { cveState = .failed("NVD 请求失败（可能被限流）：\(error.localizedDescription)") }
    }

    func attentionNames(osMajor: Int) -> [String] {
        seeds.compactMap { s in
            let m = metas[s.fullName]
            let incompatible = s.compat(osMajor: osMajor).status == .unsupported || s.compat(osMajor: osMajor).status == .limited
            return (m?.maintenance.needsAttention ?? false) || incompatible ? s.fullName : nil
        }
    }
}
