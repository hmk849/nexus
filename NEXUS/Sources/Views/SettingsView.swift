import SwiftUI
import UniformTypeIdentifiers

struct DeveloperInfo: Identifiable {
    var id: String { name }
    let name: String, bio: String, url: String, symbol: String
    var avatarURL: URL? = nil
}

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var favorites: FavoritesStore
    @State private var token = TokenStore.read() ?? ""
    @State private var cacheSize = 0
    @State private var updateText: String?
    @State private var shareItem: ShareItem?
    @State private var importing = false
    @State private var confirmClear = false
    @State private var message: String?

    private let developers = [
        DeveloperInfo(name: "hmk849", bio: "项目作者", url: "https://github.com/hmk849", symbol: "person.fill",
                      avatarURL: URL(string: "https://github.com/hmk849.png")),
        DeveloperInfo(name: "ChatGPT", bio: "AI 开发协作者", url: "https://chatgpt.com", symbol: "bubble.left.and.text.bubble.right.fill"),
        DeveloperInfo(name: "Claude", bio: "AI 开发协作者", url: "https://claude.ai", symbol: "sparkle"),
        DeveloperInfo(name: "Muse", bio: "AI 开发协作者", url: "https://muse.ai", symbol: "wand.and.stars"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                appearance
                Section("开发人员") {
                    ForEach(developers) { d in
                        if let u = URL(string: d.url) {
                            Link(destination: u) {
                                HStack(spacing: 12) {
                                    avatar(d)
                                    VStack(alignment: .leading) { Text(d.name).font(.headline); L(d.bio).font(.caption).foregroundStyle(.secondary) }
                                    Spacer()
                                    Image(systemName: "arrow.up.right").foregroundStyle(.tertiary)
                                }
                            }.tint(.primary)
                        }
                    }
                }
                Section("GitHub") {
                    SecureField("个人访问令牌（可选）", text: $token).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .onSubmit { TokenStore.write(token) }
                    L("令牌仅保存在本机钥匙串，用于提高 GitHub API 请求额度；无需任何权限范围。").font(.caption).foregroundStyle(.secondary)
                    TextField("更新检查仓库 owner/repo", text: $settings.updateRepo).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("检查应用更新") { Task { await checkUpdate() } }
                    if let t = updateText { Text(t).font(.caption).foregroundStyle(.secondary) }
                }
                Section("数据") {
                    HStack { L("缓存大小"); Spacer(); Text(formatBytes(Int64(cacheSize))).foregroundStyle(.secondary) }
                    Button("清除缓存", role: .destructive) { confirmClear = true }
                    Button("导出设置与收藏") { exportData() }
                    Button("导入设置与收藏") { importing = true }
                    if let m = message { Text(m).font(.caption).foregroundStyle(.secondary) }
                }
                Section("关于") {
                    HStack { L("版本"); Spacer(); Text(versionString).foregroundStyle(.secondary) }
                    HStack { L("支持系统"); Spacer(); Text("iOS 26–27（18+ 兼容回退）").foregroundStyle(.secondary) }
                    NavigationLink("开源许可证") { TextPage(title: "开源许可证", text: Self.licenses) }
                    NavigationLink("第三方组件声明") { TextPage(title: "第三方组件声明", text: Self.thirdParty) }
                    NavigationLink("隐私政策") { TextPage(title: "隐私政策", text: Self.privacy) }
                    NavigationLink("使用帮助") { TextPage(title: "使用帮助", text: Self.help) }
                    if let u = URL(string: "https://github.com/hmk849") { Link("反馈与建议（作者 GitHub）", destination: u) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("设置")
            .task { cacheSize = await GitHubService.shared.cacheBytes() }
            .onChange(of: token) { _, v in if v.isEmpty { TokenStore.write(nil) } }
            .sheet(item: $shareItem) { ActivityView(url: $0.url) }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { r in if case .success(let u) = r { importData(u) } }
            .confirmationDialog("清除研究中心缓存与网络缓存？", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("清除", role: .destructive) {
                    Task { await GitHubService.shared.clearCache(); URLCache.shared.removeAllCachedResponses(); cacheSize = 0 }
                }
            }
        }
        .pageTransition()
    }

    private var appearance: some View {
        Group {
            Section("外观") {
                Picker("模式", selection: $settings.mode) { ForEach(AppearanceMode.allCases) { L($0.title).tag($0) } }.pickerStyle(.segmented)
                VStack(alignment: .leading) {
                    L("强调色").font(.subheadline)
                    HStack {
                        ForEach(AccentChoice.allCases) { a in
                            Circle().fill(a.color).frame(width: 30, height: 30)
                                .overlay { if settings.accent == a { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white) } }
                                .onTapGesture { settings.accent = a; settings.tap() }
                            if a != AccentChoice.allCases.last { Spacer() }
                        }
                    }
                }
                Toggle("动画", isOn: $settings.animationsOn)
                Toggle("页面过渡动画", isOn: $settings.pageTransitions)
                Toggle("触觉反馈", isOn: $settings.haptics)
                VStack(alignment: .leading) {
                    HStack { L("玻璃效果强度"); Spacer(); Text(String(format: "%.0f%%", settings.glassIntensity * 100)).foregroundStyle(.secondary) }
                    Slider(value: $settings.glassIntensity, in: 0...1)
                }
                VStack(alignment: .leading) {
                    HStack { L("卡片圆角"); Spacer(); Text("\(Int(settings.cornerRadius)) pt").foregroundStyle(.secondary) }
                    Slider(value: $settings.cornerRadius, in: 8...36, step: 2)
                }
                Picker("UI 密度", selection: $settings.density) { ForEach(UIDensity.allCases) { L($0.title).tag($0) } }
                Picker("字体大小", selection: $settings.fontStep) {
                    ForEach(0..<5, id: \.self) { Text(["很小", "小", "标准", "大", "很大"][$0]).tag($0) }
                }
                Picker("图标样式", selection: $settings.iconStyle) { ForEach(IconStyle.allCases) { L($0.title).tag($0) } }
            }
            Section("预览") {
                HStack(spacing: 14) {
                    Image(systemName: "square.stack.3d.up.fill").font(.title)
                    VStack(alignment: .leading) { L("玻璃卡片预览").font(.headline); L("修改设置后立即生效").font(.caption).foregroundStyle(.secondary) }
                }.glassCard().listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
        }
    }

    private func avatar(_ d: DeveloperInfo) -> some View {
        Group {
            if let u = d.avatarURL {
                AsyncImage(url: u) { img in img.resizable().scaledToFill() } placeholder: { Image(systemName: d.symbol).foregroundStyle(.secondary) }
            } else { Image(systemName: d.symbol).font(.title3).foregroundStyle(settings.accent.color) }
        }
        .frame(width: 44, height: 44).background(.quaternary, in: Circle()).clipShape(Circle())
    }

    private var versionString: String {
        let i = Bundle.main.infoDictionary
        return "\(i?["CFBundleShortVersionString"] as? String ?? "?") (\(i?["CFBundleVersion"] as? String ?? "?"))"
    }

    private func checkUpdate() async {
        updateText = "检查中…"
        let repo = settings.updateRepo.trimmingCharacters(in: .whitespaces)
        guard repo.split(separator: "/").count == 2 else { updateText = "仓库格式应为 owner/repo"; return }
        if let tag = await GitHubService.shared.latestReleaseTag(repo) { updateText = "最新 Release：\(tag)（当前 \(versionString)）" }
        else { updateText = "未找到 \(repo) 的 Release（仓库不存在、无发布或请求被限流）" }
    }

    private struct Backup: Codable { var settings: SettingsSnapshot; var favorites: [FavoriteEntry] }

    private func exportData() {
        do {
            let data = try JSONEncoder.cacheEncoder.encode(Backup(settings: settings.snapshot, favorites: favorites.items))
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("nexus-backup.json")
            try data.write(to: url, options: .atomic); shareItem = ShareItem(url: url)
        } catch { message = "导出失败：\(error.localizedDescription)" }
    }
    private func importData(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let b = try JSONDecoder.cacheDecoder.decode(Backup.self, from: Data(contentsOf: url))
            settings.apply(b.settings); favorites.replaceAll(b.favorites); message = "导入成功"
        } catch { message = "导入失败：\(error.localizedDescription)" }
    }

    static let licenses = """
    NEXUS 工程本身尚未附带许可证文本，发布前请由作者补充。

    研究中心展示的第三方项目归各自作者所有，许可证以其 GitHub 仓库为准（应用会实时显示仓库声明的许可证）。NEXUS 只展示元数据和链接，不包含、不分发这些项目的代码。
    """
    static let thirdParty = """
    本应用未链接任何第三方 Swift 包或 SDK，仅使用 Apple 系统框架：SwiftUI、UIKit、Metal、Network、CoreMotion、CoreTelephony、AVFoundation、LocalAuthentication、Security。

    联网数据来源：
    • GitHub REST API（项目元数据、搜索）
    • NIST NVD API 2.0（CVE 数据）
    • Cloudflare 公共测速端点 speed.cloudflare.com（网络测速）
    • github.com/<用户>.png（开发人员头像）

    构建工具：XcodeGen（仅用于生成 .xcodeproj，不进入应用）。
    """
    static let privacy = """
    NEXUS 没有账号体系，不含统计、广告或崩溃上报 SDK，不收集也不上传你的设备信息。

    • 设备信息、MobileGestalt 文件、修改记录与备份仅保存在本机。
    • 联网请求仅发往 GitHub、NVD 与 Cloudflare 测速端点；请求中不包含设备标识符。
    • 可选的 GitHub 令牌保存在本机钥匙串，只用于请求 GitHub API。
    • 加速度计读数只在「设备检测」页面实时显示。
    """
    static let help = """
    • 首页：设备概览、功能兼容性统计、研究中心提醒。
    • 工具箱：系统信息、MobileGestalt 工具、设备检测、Liquid Glass 实验室，以及每项功能的兼容性矩阵。
    • MobileGestalt：导入 plist 副本 → 浏览 / 搜索 / 编辑 → 导出。导入时自动备份原始文件；可撤销、可恢复。应用不会写入系统文件。
    • 研究中心：项目（实时检测维护状态）、发现（GitHub 搜索）、CVE（NVD 最新数据）、资料（官方文档与研究文章）。
    • 状态标记：可用 / 受限 / 不支持 / 未经验证。「未经验证」表示应用没有可靠依据，不代表可用。
    """
}

struct TextPage: View {
    let title: String, text: String
    var body: some View {
        ScrollView { Text(LocalizedStringKey(text)).padding() .frame(maxWidth: .infinity, alignment: .leading) }
            .background(AppBackground()).navigationTitle(LocalizedStringKey(title)).navigationBarTitleDisplayMode(.inline)
    }
}
