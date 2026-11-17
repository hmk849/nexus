import SwiftUI

enum ResearchCategory: String, CaseIterable, Identifiable, Sendable {
    case mobileGestalt, securityResearch, frameworks, kernel, sandbox, systemFeatures, deviceCapabilities, dynamicIsland
    case alwaysOn, liquidGlass, appleIntelligence, uikitSwiftUI, springBoard, coreTelephony, ioKit, diagnostics, debugging
    case webkit, jailbreak, detectionTools, permissions
    var id: String { rawValue }
    var title: String {
        switch self {
        case .mobileGestalt: "MobileGestalt"; case .securityResearch: "Security Research"; case .frameworks: "iOS Frameworks"
        case .kernel: "Kernel Research"; case .sandbox: "Sandbox Research"; case .systemFeatures: "System Features"
        case .deviceCapabilities: "Device Capabilities"; case .dynamicIsland: "Dynamic Island"; case .alwaysOn: "Always On Display"
        case .liquidGlass: "Liquid Glass"; case .appleIntelligence: "Apple Intelligence"; case .uikitSwiftUI: "UIKit / SwiftUI"
        case .springBoard: "SpringBoard"; case .coreTelephony: "CoreTelephony"; case .ioKit: "IOKit"
        case .diagnostics: "Device Diagnostics"; case .debugging: "iOS Debugging"; case .webkit: "WebKit 安全"
        case .jailbreak: "Jailbreak 研究"; case .detectionTools: "安全检测工具"; case .permissions: "权限与安全机制"
        }
    }
    var symbol: String {
        switch self {
        case .mobileGestalt: "doc.badge.gearshape"; case .securityResearch: "lock.shield"; case .frameworks: "shippingbox"
        case .kernel: "cpu"; case .sandbox: "square.dashed"; case .systemFeatures: "switch.2"
        case .deviceCapabilities: "iphone.gen3"; case .dynamicIsland: "capsule"; case .alwaysOn: "sun.max"
        case .liquidGlass: "drop"; case .appleIntelligence: "sparkles"; case .uikitSwiftUI: "swift"
        case .springBoard: "square.grid.3x3"; case .coreTelephony: "antenna.radiowaves.left.and.right"; case .ioKit: "cable.connector"
        case .diagnostics: "stethoscope"; case .debugging: "ladybug"; case .webkit: "safari"
        case .jailbreak: "lock.open"; case .detectionTools: "magnifyingglass.circle"; case .permissions: "hand.raised"
        }
    }
    /// 「发现」页使用的 GitHub 搜索关键词
    var query: String {
        switch self {
        case .mobileGestalt: "MobileGestalt"; case .securityResearch: "ios security research"
        case .frameworks: "ios private frameworks"; case .kernel: "ios kernel research"
        case .sandbox: "ios sandbox research"; case .systemFeatures: "ios system features swift"
        case .deviceCapabilities: "ios device capabilities"; case .dynamicIsland: "dynamic island swiftui"
        case .alwaysOn: "always on display ios"; case .liquidGlass: "liquid glass swiftui"
        case .appleIntelligence: "apple intelligence swift"; case .uikitSwiftUI: "swiftui uikit"
        case .springBoard: "springboard ios"; case .coreTelephony: "coretelephony ios"; case .ioKit: "iokit ios"
        case .diagnostics: "ios device diagnostics"; case .debugging: "ios debugging tools"
        case .webkit: "webkit security"; case .jailbreak: "ios jailbreak research"
        case .detectionTools: "ios spyware detection"; case .permissions: "ios entitlements"
        }
    }
}

enum RiskLevel: String, Sendable {
    case none, low, medium, high
    var title: String { switch self { case .none: "无"; case .low: "低"; case .medium: "中"; case .high: "高" } }
    var color: Color { switch self { case .none: .green; case .low: .teal; case .medium: .orange; case .high: .red } }
}

/// 种子列表只记录「仓库名 + 分类 + 编辑者摘要」；名称、许可证、更新时间、Release 等一律运行时从 GitHub API 获取。
/// 仓库已失效 / 归档 / 停更时，应用会自动提示。
struct RepoSeed: Identifiable, Sendable {
    var id: String { fullName }
    let fullName: String
    let categories: [ResearchCategory]
    let features: String
    let limits: String
    let risk: RiskLevel
    var minOS: Int? = nil
    var maxOS: Int? = nil
    var declaredOS: String = "未标注（请查阅 README）"
    var devices: String = "未标注（请查阅 README）"

    func compat(osMajor: Int) -> Verdict {
        if let lo = minOS, osMajor < lo { return Verdict(status: .unsupported, reason: "README 声明最低 iOS \(lo)，当前 iOS \(osMajor)") }
        if let hi = maxOS, osMajor > hi { return Verdict(status: .limited, reason: "README 声明最高 iOS \(hi)，当前 iOS \(osMajor) 可能不兼容") }
        if minOS != nil || maxOS != nil { return Verdict(status: .available, reason: "在 README 声明范围内（未经本应用验证）") }
        return Verdict(status: .unverified, reason: "项目未声明支持范围或本应用未收录")
    }
}

struct ReferenceItem: Identifiable, Sendable {
    var id: String { url }
    let title: String, url: String, note: String
    let category: ResearchCategory
}

enum Catalog {
    static let seeds: [RepoSeed] = [
        RepoSeed(fullName: "frs0n/GestaltEdit", categories: [.mobileGestalt],
                 features: "SwiftUI 原生 MobileGestalt 编辑器：能力预设、字段编辑、备份 / 导入 / 恢复（据 README）。",
                 limits: "README 称仅限 iOS / iPadOS 27 beta 1–4，使用私有 API 并写入系统缓存；需要 Developer Mode 与自签工具。NEXUS 仅作研究链接，不集成其写入逻辑。",
                 risk: .high, minOS: 27, maxOS: 27, declaredOS: "iOS / iPadOS 27 beta 1–4（README）"),
        RepoSeed(fullName: "rooootdev/mond", categories: [.mobileGestalt],
                 features: "在 iOS 27.0 beta 1–4 上编辑 MobileGestalt（据 README）。",
                 limits: "README 称 iOS ≤ 26.x 不受支持，且有变砖风险提示；仅作研究链接。",
                 risk: .high, minOS: 27, maxOS: 27, declaredOS: "iOS 27.0 beta 1–4（README）"),
        RepoSeed(fullName: "huamidev/GestaltX", categories: [.mobileGestalt],
                 features: "面向 iOS 27.x 的 MobileGestalt 编辑器，含区域码、设备预设、备份（据第三方页面摘要）。",
                 limits: "据公开帖子，作者账号曾被封禁并使用临时仓库，仓库可能已失效；以应用的实时检测结果为准。",
                 risk: .high, minOS: 27, declaredOS: "iOS 27.x（第三方摘要，未核实）"),
        RepoSeed(fullName: "leminlimez/Nugget", categories: [.mobileGestalt],
                 features: "通过 sparserestore 漏洞向系统路径写入文件，提供 MobileGestalt 预设（据 README）。",
                 limits: "依赖已被系统修复的漏洞，新系统是否可用未经验证；有变砖风险。仅作研究链接。",
                 risk: .high, minOS: 17, declaredOS: "iOS 17.0+（README，新系统未经验证）"),
        RepoSeed(fullName: "mvt-project/mvt", categories: [.securityResearch, .detectionTools],
                 features: "Mobile Verification Toolkit：检查 iOS / Android 设备备份中的间谍软件痕迹（防御性取证工具）。",
                 limits: "在电脑上运行，需要设备备份；不在 iPhone 上运行。", risk: .low),
        RepoSeed(fullName: "apple-oss-distributions/xnu", categories: [.kernel],
                 features: "Apple 开源的 XNU 内核源码镜像，用于阅读与研究。", limits: "仅源码；与具体 iOS 版本的对应关系需查阅发布标签。", risk: .none),
        RepoSeed(fullName: "apple-oss-distributions/IOKitUser", categories: [.ioKit],
                 features: "IOKit 用户态库源码镜像。", limits: "仅源码；iOS 上 App 沙盒内可用的 IOKit 接口非常有限。", risk: .none),
        RepoSeed(fullName: "doronz88/pymobiledevice3", categories: [.debugging, .diagnostics],
                 features: "纯 Python 的 iOS 设备交互库：设备信息、日志、诊断、调试等。", limits: "在电脑上通过 USB / 网络运行；部分功能依赖设备系统版本。", risk: .low),
        RepoSeed(fullName: "libimobiledevice/libimobiledevice", categories: [.debugging, .diagnostics],
                 features: "跨平台 C 库，实现与 iOS 设备的通信协议。", limits: "在电脑端使用；新系统的协议变化可能导致部分功能失效。", risk: .low),
        RepoSeed(fullName: "devicekit/DeviceKit", categories: [.deviceCapabilities],
                 features: "Swift 库，用于识别设备型号并查询部分设备特性。", limits: "新机型需等待库更新；以仓库 Release 为准。", risk: .none),
        RepoSeed(fullName: "vsouza/awesome-ios", categories: [.frameworks],
                 features: "精选 iOS 库与框架清单。", limits: "清单类项目，不含可运行功能。", risk: .none),
        RepoSeed(fullName: "pointfreeco/swift-composable-architecture", categories: [.uikitSwiftUI],
                 features: "面向 SwiftUI / UIKit 的状态管理与架构库。", limits: "需要对应的 Swift / Xcode 版本。", risk: .none),
        RepoSeed(fullName: "nst/iOS-Runtime-Headers", categories: [.springBoard, .coreTelephony],
                 features: "从 iOS 运行时导出的私有框架头文件（含 SpringBoard、CoreTelephony 等）。", limits: "导出版本较旧，可能已很久未更新；仅供研究参考。", risk: .low),
        RepoSeed(fullName: "rguillen-dev/LiquidGlass", categories: [.liquidGlass],
                 features: "Liquid Glass 相关示例（用户指定的参考项目，详情见仓库）。", limits: "具体支持版本请查阅 README。", risk: .none, minOS: 26, declaredOS: "iOS 26+（Liquid Glass 的系统要求）"),
        RepoSeed(fullName: "sk1gl4a/LiquidGlass-SwiftUI-Showcase", categories: [.liquidGlass, .uikitSwiftUI],
                 features: "SwiftUI Liquid Glass 展示项目（用户指定的参考项目，详情见仓库）。", limits: "具体支持版本请查阅 README。", risk: .none, minOS: 26, declaredOS: "iOS 26+（Liquid Glass 的系统要求）"),
        RepoSeed(fullName: "metneo/LiquidGlass", categories: [.liquidGlass],
                 features: "Liquid Glass 相关示例（用户指定的参考项目，详情见仓库）。", limits: "具体支持版本请查阅 README。", risk: .none, minOS: 26, declaredOS: "iOS 26+（Liquid Glass 的系统要求）"),
    ]

    static let references: [ReferenceItem] = [
        ReferenceItem(title: "Apple 安全公告索引", url: "https://support.apple.com/en-us/100100", note: "Apple 官方发布的各系统版本安全内容（CVE 清单）。", category: .securityResearch),
        ReferenceItem(title: "Apple Security Research", url: "https://security.apple.com", note: "Apple 安全研究站点。", category: .securityResearch),
        ReferenceItem(title: "Apple Platform Security", url: "https://support.apple.com/guide/security/welcome/web", note: "沙盒、代码签名、权限（entitlements）等安全机制官方文档。", category: .permissions),
        ReferenceItem(title: "NVD 漏洞库", url: "https://nvd.nist.gov/vuln/search", note: "美国 NIST 国家漏洞数据库，CVE 页签的数据来源。", category: .securityResearch),
        ReferenceItem(title: "CISA 已知被利用漏洞目录", url: "https://www.cisa.gov/known-exploited-vulnerabilities-catalog", note: "已确认被在野利用的漏洞清单，可按 Apple 过滤。", category: .securityResearch),
        ReferenceItem(title: "WebKit 安全政策", url: "https://webkit.org/security-policy/", note: "WebKit 官方安全政策与报告渠道。", category: .webkit),
        ReferenceItem(title: "Apple 开源代码", url: "https://opensource.apple.com", note: "XNU、dyld 等开源组件的官方发布。", category: .kernel),
        ReferenceItem(title: "The Apple Wiki：MobileGestalt 键列表", url: "https://theapplewiki.com/wiki/List_of_MobileGestalt_keys", note: "社区维护的 MobileGestalt 键名与哈希键对照。", category: .mobileGestalt),
        ReferenceItem(title: "iOS 区域限制与 MobileGestalt / Eligibility（hsu.cy）", url: "https://hsu.cy/2024/09/ios-feature-regional-lockout", note: "介绍 MobileGestalt 缓存文件结构与哈希键的研究文章（2024）。", category: .mobileGestalt),
        ReferenceItem(title: "Google Project Zero 博客", url: "https://googleprojectzero.blogspot.com", note: "包含 iOS 内核、沙盒等方向的公开漏洞研究。", category: .sandbox),
        ReferenceItem(title: "Citizen Lab", url: "https://citizenlab.ca", note: "间谍软件与定向攻击的公开调查报告。", category: .detectionTools),
    ]
}
