import SwiftUI

struct ResearchView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var research: ResearchStore
    @EnvironmentObject private var favorites: FavoritesStore
    @State private var section = 0
    @State private var category: ResearchCategory?
    @State private var filter = 0            // 0 全部 1 需注意 2 已收藏
    @State private var search = ""
    @State private var discoverQuery = ""
    @State private var cveFilter = 0
    @State private var os = OSVersion.current.major

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: settings.density.spacing) {
                    Picker("", selection: $section) {
                        Text("项目").tag(0); Text("发现").tag(1); Text("CVE").tag(2); Text("资料").tag(3)
                    }.pickerStyle(.segmented)
                    switch section {
                    case 0: projects
                    case 1: discover
                    case 2: cves
                    default: references
                    }
                }.padding()
            }
            .background(AppBackground())
            .navigationTitle("研究中心")
            .searchable(text: $search, prompt: "搜索")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await research.refreshAll(force: true) } } label: { Image(systemName: "arrow.clockwise") }.disabled(research.loading)
                }
            }
            .navigationDestination(for: String.self) { RepoDetailView(fullName: $0) }
            .task { if research.cveState == .idle { await research.loadCVEs() } }
        }
        .pageTransition()
    }

    // MARK: 项目

    private var shown: [RepoSeed] {
        research.seeds.filter { s in
            if let c = category, !s.categories.contains(c) { return false }
            let m = research.metas[s.fullName]
            switch filter {
            case 1: if !((m?.maintenance.needsAttention ?? false) || s.compat(osMajor: os).status == .unsupported || s.compat(osMajor: os).status == .limited) { return false }
            case 2: if !favorites.contains(s.fullName) { return false }
            default: break
            }
            let q = search.trimmingCharacters(in: .whitespaces).lowercased()
            return q.isEmpty || s.fullName.lowercased().contains(q) || s.features.lowercased().contains(q)
        }
    }

    @ViewBuilder private var projects: some View {
        if research.loading { ProgressView(value: research.progress).glassCard() }
        if let m = research.message { Text(m).font(.caption).foregroundStyle(.orange).glassCard() }
        let alerts = research.attentionNames(osMajor: os)
        if !alerts.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                LabelL("需要注意的项目", "exclamationmark.triangle.fill").font(.subheadline.weight(.semibold)).foregroundStyle(.orange)
                Text(alerts.joined(separator: "、")).font(.caption).foregroundStyle(.secondary)
                L("已失效、归档、疑似停更，或 README 声明的系统范围与当前系统不符。").font(.caption2).foregroundStyle(.tertiary)
            }.glassCard()
        }
        HStack {
            Menu {
                Button("全部分类") { category = nil }
                ForEach(ResearchCategory.allCases) { c in Button { category = c } label: { Label(c.title, systemImage: c.symbol) } }
            } label: { Label(category?.title ?? "全部分类", systemImage: "line.3.horizontal.decrease.circle") }
            Spacer()
            Picker("", selection: $filter) { Text("全部").tag(0); Text("需注意").tag(1); Text("已收藏").tag(2) }.pickerStyle(.menu)
        }.font(.subheadline)
        if shown.isEmpty { L("没有符合条件的项目。可到「发现」中按分类搜索 GitHub。").foregroundStyle(.secondary).glassCard() }
        ForEach(shown) { s in
            NavigationLink(value: s.fullName) { RepoRow(fullName: s.fullName, seed: s, osMajor: os) }.buttonStyle(.plain)
        }
    }

    // MARK: 发现

    @ViewBuilder private var discover: some View {
        VStack(alignment: .leading, spacing: 8) {
            L("实时搜索 GitHub 公共仓库。仅展示元数据与链接，NEXUS 不下载、集成或运行其中的任何代码。").font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("关键词", text: $discoverQuery).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .onSubmit { Task { await research.discover(discoverQuery) } }
                Button("搜索") { Task { await research.discover(discoverQuery) } }.buttonStyle(.borderedProminent)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(ResearchCategory.allCases) { c in
                        Button { discoverQuery = c.query; Task { await research.discover(c.query) } } label: { Label(c.title, systemImage: c.symbol).font(.caption) }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                }
            }
        }.glassCard()
        switch research.discoverState {
        case .loading: ProgressView().glassCard()
        case .failed(let e): Text(e).font(.caption).foregroundStyle(.red).glassCard()
        default: EmptyView()
        }
        ForEach(research.discovered) { m in
            NavigationLink(value: m.fullName) { RepoRow(fullName: m.fullName, seed: nil, osMajor: os) }.buttonStyle(.plain)
        }
    }

    // MARK: CVE

    private let cveFilters: [(String, [String])] = [("全部", []), ("内核", ["kernel"]), ("WebKit", ["webkit"]), ("沙盒", ["sandbox"]),
                                                    ("MobileGestalt", ["mobilegestalt"]), ("权限", ["entitlement", "privilege", "permission"])]

    private var cveShown: [CVEItem] {
        let words = cveFilters[cveFilter].1
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return research.cves.filter { c in
            let t = c.summary.lowercased()
            return (words.isEmpty || words.contains { t.contains($0) }) && (q.isEmpty || t.contains(q) || c.id.lowercased().contains(q))
        }
    }

    @ViewBuilder private var cves: some View {
        VStack(alignment: .leading, spacing: 8) {
            L("数据来自 NVD API 2.0：最近 110 天发布、描述中含 iPadOS 的 CVE（Apple 公告同时写 iOS 与 iPadOS）。仅作公开信息索引，不含利用代码。").font(.caption).foregroundStyle(.secondary)
            Picker("", selection: $cveFilter) { ForEach(cveFilters.indices, id: \.self) { Text(cveFilters[$0].0).tag($0) } }.pickerStyle(.menu)
        }.glassCard()
        switch research.cveState {
        case .loading: ProgressView().glassCard()
        case .failed(let e): VStack(alignment: .leading) { Text(e).font(.caption).foregroundStyle(.red); Button("重试") { Task { await research.loadCVEs() } } }.glassCard()
        default: if cveShown.isEmpty { L("没有匹配的 CVE").foregroundStyle(.secondary).glassCard() }
        }
        ForEach(cveShown) { c in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(c.id).font(.subheadline.weight(.semibold)); Spacer()
                    Text(c.risk.title + (c.score.map { String(format: " %.1f", $0) } ?? "")).font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3).background(c.risk.color.opacity(0.18), in: Capsule()).foregroundStyle(c.risk.color)
                    FavoriteButton(entry: FavoriteEntry(id: c.id, kind: .cve, title: c.id, subtitle: c.summary, url: c.url, lastSeen: nil))
                }
                Text(c.summary).font(.caption).foregroundStyle(.secondary).lineLimit(5)
                HStack {
                    Text("发布 \(c.published)").font(.caption2).foregroundStyle(.tertiary)
                    if !c.versions.isEmpty { Text(c.versions.prefix(3).joined(separator: ", ")).font(.caption2).foregroundStyle(.tertiary).lineLimit(1) }
                    Spacer()
                    if let u = URL(string: c.url) { Link("NVD", destination: u).font(.caption) }
                }
            }.glassCard()
        }
    }

    // MARK: 资料

    @ViewBuilder private var references: some View {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        ForEach(Catalog.references.filter { q.isEmpty || $0.title.lowercased().contains(q) || $0.note.lowercased().contains(q) }) { r in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    LabelL(r.category.title, r.category.symbol).font(.caption).foregroundStyle(.secondary); Spacer()
                    FavoriteButton(entry: FavoriteEntry(id: r.url, kind: .cve, title: r.title, subtitle: r.note, url: r.url, lastSeen: nil))
                }
                if let u = URL(string: r.url) { Link(r.title, destination: u).font(.subheadline.weight(.semibold)) }
                Text(r.note).font(.caption).foregroundStyle(.secondary)
            }.glassCard()
        }
    }
}

struct RepoRow: View {
    @EnvironmentObject private var research: ResearchStore
    let fullName: String
    let seed: RepoSeed?
    let osMajor: Int
    var body: some View {
        let m = research.metas[fullName]
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(fullName).font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer()
                FavoriteButton(entry: FavoriteEntry(id: fullName, kind: .repo, title: fullName, subtitle: m?.summary ?? seed?.features ?? "", url: m?.htmlURL ?? "https://github.com/\(fullName)", lastSeen: m?.pushedAt))
            }
            Text(m?.summary ?? seed?.features ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(2)
            HStack(spacing: 6) {
                if let m {
                    Label { L(m.maintenance.title) } icon: { Image(systemName: m.maintenance.symbol) }
                        .font(.caption2).foregroundStyle(m.maintenance.needsAttention ? .orange : .secondary)
                    if m.stars > 0 { Label("\(m.stars)", systemImage: "star").font(.caption2).foregroundStyle(.secondary) }
                    if let p = m.pushedAt { Text(p, style: .date).font(.caption2).foregroundStyle(.tertiary) }
                } else { ProgressView().controlSize(.mini) }
                Spacer()
                if let s = seed { StatusBadge(status: s.compat(osMajor: osMajor).status) }
            }
        }.glassCard()
    }
}

struct RepoDetailView: View {
    @EnvironmentObject private var research: ResearchStore
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var settings: AppSettings
    let fullName: String

    var body: some View {
        let m = research.metas[fullName]
        let s = research.seed(fullName)
        let os = OSVersion.current.major
        ScrollView {
            VStack(spacing: settings.density.spacing) {
                VStack(alignment: .leading, spacing: 8) {
                    row("项目名称", fullName)
                    row("作者", m?.owner)
                    row("简介", m?.summary ?? "（无）")
                    row("许可证", m?.license ?? (m?.state == .ok ? "未声明" : nil))
                    row("最新更新", m?.pushedAt?.formatted(date: .abbreviated, time: .omitted))
                    row("最新 Release", m?.releaseChecked == true ? (m?.latestRelease.map { "\($0)（\(m?.releaseDate?.formatted(date: .abbreviated, time: .omitted) ?? "")）" } ?? "无 Release") : "加载中…")
                    row("维护状态", m.map { NSLocalizedString($0.maintenance.title, comment: "") })
                    if m?.state == .rateLimited || m?.state == .offline { Text("无法从 GitHub 获取实时数据（限流或离线）。").font(.caption).foregroundStyle(.orange) }
                    if m?.state == .notFound { Text("GitHub 返回 404：仓库已删除、改名或设为私有。").font(.caption).foregroundStyle(.red) }
                }.glassCard()

                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle("兼容性与风险", "checkmark.shield")
                    row("支持的 iOS 版本", s?.declaredOS ?? "未标注（请查阅 README）")
                    row("支持的设备型号", s?.devices ?? "未标注（请查阅 README）")
                    if let s { let v = s.compat(osMajor: os)
                        HStack { L("与本机兼容"); Spacer(); StatusBadge(status: v.status) }.font(.subheadline)
                        Text(v.reason).font(.caption).foregroundStyle(.secondary)
                        HStack { L("安全风险等级"); Spacer(); Text(s.risk.title).foregroundStyle(s.risk.color).fontWeight(.semibold) }.font(.subheadline)
                    }
                }.glassCard()

                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle("实际功能与限制", "list.bullet.rectangle")
                    Text(s?.features ?? (m?.topics.isEmpty == false ? "主题标签：" + m!.topics.joined(separator: ", ") : "未收录摘要，请阅读仓库 README。"))
                        .font(.subheadline)
                    Text(s?.limits ?? "未经验证：该项目来自实时搜索，NEXUS 未审阅其代码。使用前请自行评估风险。").font(.caption).foregroundStyle(.secondary)
                    L("编辑者摘要依据 README / 公开页面整理，可能滞后；NEXUS 不下载或运行这些项目的代码。").font(.caption2).foregroundStyle(.tertiary)
                }.glassCard()

                if let u = URL(string: m?.htmlURL ?? "https://github.com/\(fullName)") {
                    Link(destination: u) { LabelL("在 GitHub 打开", "arrow.up.right.square").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                }
            }.padding()
        }
        .background(AppBackground())
        .navigationTitle(fullName.split(separator: "/").last.map(String.init) ?? fullName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                FavoriteButton(entry: FavoriteEntry(id: fullName, kind: .repo, title: fullName, subtitle: m?.summary ?? s?.features ?? "", url: m?.htmlURL ?? "https://github.com/\(fullName)", lastSeen: m?.pushedAt))
            }
        }
        .task { await research.ensureRelease(fullName) }
    }

    private func row(_ title: String, _ value: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            L(title).foregroundStyle(.secondary); Spacer(minLength: 12)
            if let value { Text(value).multilineTextAlignment(.trailing) } else { L("不可获取").foregroundStyle(.tertiary) }
        }.font(.subheadline)
    }
}

struct FavoritesView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var research: ResearchStore
    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: settings.density.spacing) {
                    if favorites.items.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "star").font(.largeTitle).foregroundStyle(.secondary)
                            L("还没有收藏。在研究中心点星标即可收藏项目、CVE 或资料。").foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity).glassCard(padding: 30)
                    }
                    ForEach(favorites.items) { e in
                        let meta = research.metas[e.id]
                        let updated = e.kind == .repo && (meta?.pushedAt != nil) && (e.lastSeen != nil) && meta!.pushedAt! > e.lastSeen!
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(e.title).font(.subheadline.weight(.semibold)).lineLimit(1); Spacer()
                                if updated { Label("有更新", systemImage: "bell.badge.fill").font(.caption2.weight(.semibold)).foregroundStyle(.orange) }
                                FavoriteButton(entry: e)
                            }
                            Text(e.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                            if let m = meta, e.kind == .repo {
                                Label { L(m.maintenance.title) } icon: { Image(systemName: m.maintenance.symbol) }.font(.caption2)
                                    .foregroundStyle(m.maintenance.needsAttention ? .orange : .secondary)
                            }
                            HStack {
                                if e.kind == .repo { NavigationLink("详情", value: e.id).font(.caption) }
                                if let u = URL(string: e.url) { Link("打开链接", destination: u).font(.caption) }
                                Spacer()
                                if updated { Button("标记已读") { favorites.markSeen(e.id, date: meta?.pushedAt) }.font(.caption) }
                            }
                        }.glassCard()
                    }
                }.padding()
            }
            .background(AppBackground())
            .navigationTitle("收藏")
            .navigationDestination(for: String.self) { RepoDetailView(fullName: $0) }
            .task { await research.refreshExtras(favorites.repoIDs) }
        }
        .pageTransition()
    }
}
