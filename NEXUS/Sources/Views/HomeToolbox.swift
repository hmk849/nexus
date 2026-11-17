import SwiftUI

enum ToolRoute: Hashable, CaseIterable {
    case systemInfo, mobileGestalt, diagnostics, liquidGlass
    var title: String {
        switch self { case .systemInfo: "系统信息"; case .mobileGestalt: "MobileGestalt 工具"; case .diagnostics: "设备检测"; case .liquidGlass: "Liquid Glass 实验室" }
    }
    var symbol: String {
        switch self { case .systemInfo: "info.circle.fill"; case .mobileGestalt: "doc.badge.gearshape.fill"; case .diagnostics: "waveform.path.ecg"; case .liquidGlass: "drop.fill" }
    }
    var blurb: String {
        switch self {
        case .systemInfo: "型号、系统、CPU/GPU、内存、存储、电池、屏幕。无法获取的项会明确标注。"
        case .mobileGestalt: "导入 plist，浏览 / 搜索 / 编辑字段，备份、撤销、导出。仅编辑文件副本。"
        case .diagnostics: "CPU 基准、网络测速、电池与温度状态、传感器检测。"
        case .liquidGlass: "原生 glassEffect / GlassEffectContainer 演示，iOS 26 以下自动回退。"
        }
    }
    var features: [Feature] {
        switch self {
        case .systemInfo: [.systemInfo]
        case .mobileGestalt: [.mgOfflineEditor, .mgSystemWrite, .mgLiveRead]
        case .diagnostics: [.diagnostics, .batteryCycles]
        case .liquidGlass: [.liquidGlassNative]
        }
    }
}

struct ToolDestination: View {
    let route: ToolRoute
    var body: some View {
        switch route {
        case .systemInfo: SystemInfoView()
        case .mobileGestalt: MobileGestaltView()
        case .diagnostics: DiagnosticsView()
        case .liquidGlass: LiquidGlassLabView()
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var research: ResearchStore
    @EnvironmentObject private var favorites: FavoritesStore
    @State private var snap = DeviceInfoService.snapshot()

    var body: some View {
        let verdicts = Feature.allCases.map { CompatEngine.evaluate($0, snap) }
        let alerts = research.attentionNames(osMajor: snap.os.major)
        let favUpdates = favorites.items.filter { e in
            guard e.kind == .repo, let p = research.metas[e.id]?.pushedAt, let s = e.lastSeen else { return false }
            return p > s
        }.count
        NavigationStack {
            ScrollView {
                VStack(spacing: settings.density.spacing) {
                    VStack(alignment: .leading, spacing: 6) {
                        LabelL("当前设备", "iphone").font(.headline)
                        Text(snap.marketingName ?? snap.identifier).font(.title2.bold())
                        Text("iOS \(snap.os.description) · Build \(snap.build)").foregroundStyle(.secondary)
                        Text(snap.identifier).font(.caption).foregroundStyle(.tertiary)
                    }.glassCard()

                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle("功能兼容性概览", "checkmark.shield")
                        HStack {
                            ForEach(FeatureStatus.allCases, id: \.self) { s in
                                VStack {
                                    Text("\(verdicts.filter { $0.status == s }.count)").font(.title3.bold()).foregroundStyle(s.color)
                                    L(s.label).font(.caption2).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity)
                            }
                        }
                    }.glassCard()

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: settings.density.spacing) {
                        ForEach(ToolRoute.allCases, id: \.self) { r in
                            NavigationLink(value: r) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Image(systemName: r.symbol).font(.title2).foregroundStyle(settings.accent.color)
                                    L(r.title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
                                }.frame(maxWidth: .infinity, minHeight: 70, alignment: .leading).glassCard()
                            }.buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        SectionTitle("研究中心提醒", "bell.badge")
                        if alerts.isEmpty && favUpdates == 0 {
                            L("暂无需要注意的项目").foregroundStyle(.secondary)
                        } else {
                            if !alerts.isEmpty { Text("\(alerts.count) 个收录项目已失效 / 停更 / 与当前系统不兼容") }
                            if favUpdates > 0 { Text("\(favUpdates) 个收藏项目有新的提交") }
                        }
                    }.font(.subheadline).glassCard()
                }.padding()
            }
            .background(AppBackground())
            .navigationTitle("NEXUS")
            .navigationDestination(for: ToolRoute.self) { ToolDestination(route: $0) }
        }
        .pageTransition()
    }
}

struct ToolboxView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var snap = DeviceInfoService.snapshot()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: settings.density.spacing) {
                    ForEach(ToolRoute.allCases, id: \.self) { r in
                        NavigationLink(value: r) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack { LabelL(r.title, r.symbol).font(.headline); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
                                L(r.blurb).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                                HStack { ForEach(r.features) { StatusBadge(status: CompatEngine.evaluate($0, snap).status) } }
                            }.glassCard()
                        }.buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle("功能兼容性矩阵", "checklist")
                        ForEach(Feature.allCases) { f in
                            let v = CompatEngine.evaluate(f, snap)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack { LabelL(f.title, f.symbol).font(.subheadline.weight(.medium)); Spacer(); StatusBadge(status: v.status) }
                                Text(v.reason).font(.caption).foregroundStyle(.secondary)
                            }
                            if f != Feature.allCases.last { Divider() }
                        }
                    }.glassCard()
                }.padding()
            }
            .background(AppBackground())
            .navigationTitle("工具箱")
            .navigationDestination(for: ToolRoute.self) { ToolDestination(route: $0) }
        }
        .pageTransition()
    }
}
