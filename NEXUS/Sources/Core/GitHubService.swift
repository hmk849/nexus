import Foundation

enum RepoFetchState: String, Codable, Sendable { case ok, notFound, rateLimited, offline }
enum Maintenance: Sendable {
    case active, slow, stale, archived, unreachable, unknown
    var title: String {
        switch self {
        case .active: "活跃维护"; case .slow: "更新缓慢"; case .stale: "疑似停止维护"
        case .archived: "已归档"; case .unreachable: "失效 / 无法访问"; case .unknown: "状态未知"
        }
    }
    var symbol: String {
        switch self {
        case .active: "checkmark.circle.fill"; case .slow: "clock.badge.exclamationmark"; case .stale: "moon.zzz.fill"
        case .archived: "archivebox.fill"; case .unreachable: "xmark.circle.fill"; case .unknown: "questionmark.circle"
        }
    }
    var needsAttention: Bool { self == .stale || self == .archived || self == .unreachable }
}

struct RepoMeta: Codable, Identifiable, Sendable, Hashable {
    var id: String { fullName }
    let fullName: String
    var htmlURL: String
    var owner: String
    var summary: String?
    var license: String?
    var pushedAt: Date?
    var stars: Int
    var archived: Bool
    var topics: [String]
    var latestRelease: String?
    var releaseDate: Date?
    var releaseChecked: Bool
    var state: RepoFetchState
    var fetchedAt: Date

    static func placeholder(_ fullName: String, state: RepoFetchState) -> RepoMeta {
        RepoMeta(fullName: fullName, htmlURL: "https://github.com/\(fullName)", owner: String(fullName.split(separator: "/").first ?? ""),
                 summary: nil, license: nil, pushedAt: nil, stars: 0, archived: false, topics: [], latestRelease: nil,
                 releaseDate: nil, releaseChecked: false, state: state, fetchedAt: Date())
    }

    /// 依据最近一次 push 时间判断；这是启发式，不代表项目一定可用。
    var maintenance: Maintenance {
        if state == .notFound { return .unreachable }
        if archived { return .archived }
        guard let p = pushedAt else { return .unknown }
        let days = Date().timeIntervalSince(p) / 86400
        return days < 180 ? .active : (days < 540 ? .slow : .stale)
    }
}

private struct GHRepo: Decodable, Sendable {
    let fullName: String, htmlUrl: String, stargazersCount: Int, archived: Bool
    let description: String?, pushedAt: Date?, topics: [String]?
    let license: GHLicense?, owner: GHOwner
}
private struct GHLicense: Decodable, Sendable { let spdxId: String?, name: String? }
private struct GHOwner: Decodable, Sendable { let login: String }
private struct GHRelease: Decodable, Sendable { let tagName: String, publishedAt: Date? }
private struct GHSearch: Decodable, Sendable { let items: [GHRepo] }

actor GitHubService {
    static let shared = GitHubService()
    private var cache: [String: RepoMeta] = [:]
    private var loaded = false
    private(set) var isRateLimited = false
    private let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("nexus-repo-cache.json")
    private let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; d.dateDecodingStrategy = .iso8601; return d
    }()

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        if let data = try? Data(contentsOf: cacheURL),
           let m = try? JSONDecoder.cacheDecoder.decode([String: RepoMeta].self, from: data) { cache = m }
    }
    private func save() {
        if let data = try? JSONEncoder.cacheEncoder.encode(cache) { try? data.write(to: cacheURL, options: .atomic) }
    }
    func cached() -> [String: RepoMeta] { loadIfNeeded(); return cache }

    private func request(_ path: String, query: [URLQueryItem] = []) -> URLRequest {
        var c = URLComponents(string: "https://api.github.com\(path)")!
        if !query.isEmpty { c.queryItems = query }
        var r = URLRequest(url: c.url!)
        r.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        r.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        r.setValue("NEXUS-iOS-Toolbox", forHTTPHeaderField: "User-Agent")
        if let t = TokenStore.read() { r.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        r.timeoutInterval = 20
        return r
    }

    private static func meta(from r: GHRepo) -> RepoMeta {
        RepoMeta(fullName: r.fullName, htmlURL: r.htmlUrl, owner: r.owner.login, summary: r.description,
                 license: r.license?.spdxId ?? r.license?.name, pushedAt: r.pushedAt, stars: r.stargazersCount,
                 archived: r.archived, topics: r.topics ?? [], latestRelease: nil, releaseDate: nil, releaseChecked: false,
                 state: .ok, fetchedAt: Date())
    }

    func fetch(_ fullName: String, force: Bool, maxAge: TimeInterval = 6 * 3600) async -> RepoMeta {
        loadIfNeeded()
        if !force, let c = cache[fullName], c.state == .ok, Date().timeIntervalSince(c.fetchedAt) < maxAge { return c }
        do {
            let (data, resp) = try await URLSession.shared.data(for: request("/repos/\(fullName)"))
            switch (resp as? HTTPURLResponse)?.statusCode ?? 0 {
            case 200:
                var m = Self.meta(from: try decoder.decode(GHRepo.self, from: data))
                if let old = cache[fullName] { m.latestRelease = old.latestRelease; m.releaseDate = old.releaseDate; m.releaseChecked = old.releaseChecked }
                cache[fullName] = m; save(); isRateLimited = false
                return m
            case 404:
                let m = RepoMeta.placeholder(fullName, state: .notFound)
                cache[fullName] = m; save(); return m
            case 403, 429:
                isRateLimited = true
                return cache[fullName] ?? RepoMeta.placeholder(fullName, state: .rateLimited)
            default:
                return cache[fullName] ?? RepoMeta.placeholder(fullName, state: .offline)
            }
        } catch {
            return cache[fullName] ?? RepoMeta.placeholder(fullName, state: .offline)
        }
    }

    func fetchRelease(_ fullName: String) async -> RepoMeta {
        loadIfNeeded()
        var m = cache[fullName] ?? RepoMeta.placeholder(fullName, state: .offline)
        do {
            let (data, resp) = try await URLSession.shared.data(for: request("/repos/\(fullName)/releases/latest"))
            switch (resp as? HTTPURLResponse)?.statusCode ?? 0 {
            case 200:
                let r = try decoder.decode(GHRelease.self, from: data)
                m.latestRelease = r.tagName; m.releaseDate = r.publishedAt; m.releaseChecked = true
            case 404: m.latestRelease = nil; m.releaseDate = nil; m.releaseChecked = true
            case 403, 429: isRateLimited = true
            default: break
            }
        } catch {}
        cache[fullName] = m; save()
        return m
    }

    func search(_ q: String) async throws -> [RepoMeta] {
        let (data, resp) = try await URLSession.shared.data(for: request("/search/repositories", query: [
            URLQueryItem(name: "q", value: q), URLQueryItem(name: "sort", value: "updated"),
            URLQueryItem(name: "order", value: "desc"), URLQueryItem(name: "per_page", value: "20")]))
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 403 || code == 429 { isRateLimited = true; throw URLError(.dataNotAllowed) }
        guard code == 200 else { throw URLError(.badServerResponse) }
        return try decoder.decode(GHSearch.self, from: data).items.map(Self.meta(from:))
    }

    func latestReleaseTag(_ fullName: String) async -> String? {
        guard let (data, resp) = try? await URLSession.shared.data(for: request("/repos/\(fullName)/releases/latest")),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return (try? decoder.decode(GHRelease.self, from: data))?.tagName
    }

    func clearCache() { cache = [:]; loaded = true; try? FileManager.default.removeItem(at: cacheURL) }
    func cacheBytes() -> Int { (try? Data(contentsOf: cacheURL).count) ?? 0 }
}

extension JSONDecoder {
    static var cacheDecoder: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }
}
extension JSONEncoder {
    static var cacheEncoder: JSONEncoder { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }
}
