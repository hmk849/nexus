import SwiftUI

enum FeatureStatus: String, CaseIterable, Sendable {
    case available, limited, unsupported, unverified
    var label: String { switch self { case .available: "可用"; case .limited: "受限"; case .unsupported: "不支持"; case .unverified: "未经验证" } }
    var symbol: String {
        switch self {
        case .available: "checkmark.seal.fill"; case .limited: "exclamationmark.triangle.fill"
        case .unsupported: "xmark.octagon.fill"; case .unverified: "questionmark.diamond.fill"
        }
    }
    var color: Color { switch self { case .available: .green; case .limited: .orange; case .unsupported: .red; case .unverified: .gray } }
}

struct OSVersion: Comparable, Sendable, CustomStringConvertible {
    var major: Int, minor: Int, patch: Int
    static var current: OSVersion {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return OSVersion(major: v.majorVersion, minor: v.minorVersion, patch: v.patchVersion)
    }
    static func < (a: OSVersion, b: OSVersion) -> Bool { (a.major, a.minor, a.patch) < (b.major, b.minor, b.patch) }
    var description: String { patch == 0 ? "\(major).\(minor)" : "\(major).\(minor).\(patch)" }
}

/// 机型表来自 GitHub（adamawolf 机型 ID gist、DeviceKit）与 Apple 规格页；未收录的机型（如 iPhone 18 Pro）一律标注「未经验证」。
enum ModelTable {
    static let names: [String: String] = [
        "iPhone12,1": "iPhone 11", "iPhone12,3": "iPhone 11 Pro", "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2nd generation)",
        "iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12", "iPhone13,3": "iPhone 12 Pro", "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,4": "iPhone 13 mini", "iPhone14,5": "iPhone 13", "iPhone14,2": "iPhone 13 Pro", "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,6": "iPhone SE (3rd generation)", "iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro", "iPhone15,3": "iPhone 14 Pro Max", "iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max", "iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,5": "iPhone 16e",
        // 以下标识符来自 adamawolf 的机型 ID 列表 gist 与 EveryMac（GitHub / 公开页面核对）
        "iPhone18,1": "iPhone 17 Pro", "iPhone18,2": "iPhone 17 Pro Max", "iPhone18,3": "iPhone 17",
        "iPhone18,4": "iPhone Air", "iPhone18,5": "iPhone 17e",
    ]
    // iPhone 17 / Air 的灵动岛、Always-On 已由 Apple 规格页核实；17 系列的相机控制、操作按钮据 MacRumors（17 Pro 系列同款）。
    static let dynamicIsland: Set<String> = ["iPhone15,2", "iPhone15,3", "iPhone15,4", "iPhone15,5", "iPhone16,1", "iPhone16,2",
                                             "iPhone17,1", "iPhone17,2", "iPhone17,3", "iPhone17,4",
                                             "iPhone18,1", "iPhone18,2", "iPhone18,3", "iPhone18,4"]
    static let alwaysOn: Set<String> = ["iPhone15,2", "iPhone15,3", "iPhone16,1", "iPhone16,2", "iPhone17,1", "iPhone17,2",
                                        "iPhone18,1", "iPhone18,2", "iPhone18,3", "iPhone18,4"]
    static let cameraControl: Set<String> = ["iPhone17,1", "iPhone17,2", "iPhone17,3", "iPhone17,4",
                                             "iPhone18,1", "iPhone18,2", "iPhone18,3"]
    static let actionButton: Set<String> = ["iPhone15,4", "iPhone15,5", "iPhone16,1", "iPhone16,2",
                                            "iPhone17,1", "iPhone17,2", "iPhone17,3", "iPhone17,4", "iPhone17,5",
                                            "iPhone18,1", "iPhone18,2", "iPhone18,3"]
    static let appleIntelligence: Set<String> = ["iPhone16,1", "iPhone16,2", "iPhone17,1", "iPhone17,2", "iPhone17,3", "iPhone17,4", "iPhone17,5",
                                                 "iPhone18,1", "iPhone18,2", "iPhone18,3", "iPhone18,4"]
    /// 已收录名称但本应用没有核实到该项规格的机型（一律标「未经验证」，不猜测）
    static let specUnverified: Set<String> = ["iPhone18,5"]
    static let specUnverifiedAirExtra: Set<String> = ["iPhone18,4", "iPhone18,5"]
}

struct DeviceSnapshot: Sendable {
    let identifier: String
    let marketingName: String?
    let os: OSVersion
    let build: String
    let isPad: Bool
    let hdrCapable: Bool
    var recognized: Bool { ModelTable.names[identifier] != nil }
}

enum Feature: String, CaseIterable, Identifiable, Sendable {
    case systemInfo, diagnostics, mgOfflineEditor, mgSystemWrite, mgLiveRead, researchCenter, liquidGlassNative
    case dynamicIsland, alwaysOnDisplay, cameraControl, actionButton, appleIntelligence, stageManager, applePencil, hdr, batteryCycles
    var id: String { rawValue }
    var title: String {
        switch self {
        case .systemInfo: "系统信息"; case .diagnostics: "设备检测"; case .mgOfflineEditor: "MobileGestalt 文件离线编辑"
        case .mgSystemWrite: "写入系统 MobileGestalt"; case .mgLiveRead: "MobileGestalt 实时读取（私有 API）"
        case .researchCenter: "研究中心"; case .liquidGlassNative: "原生 Liquid Glass"
        case .dynamicIsland: "灵动岛"; case .alwaysOnDisplay: "Always On Display"; case .cameraControl: "相机控制"
        case .actionButton: "操作按钮"; case .appleIntelligence: "Apple Intelligence"; case .stageManager: "台前调度"
        case .applePencil: "Apple Pencil"; case .hdr: "HDR 显示"; case .batteryCycles: "电池循环次数 / 健康度"
        }
    }
    var symbol: String {
        switch self {
        case .systemInfo: "info.circle"; case .diagnostics: "waveform.path.ecg"; case .mgOfflineEditor: "doc.badge.gearshape"
        case .mgSystemWrite: "lock.shield"; case .mgLiveRead: "eye"; case .researchCenter: "books.vertical"
        case .liquidGlassNative: "drop.fill"; case .dynamicIsland: "capsule.fill"; case .alwaysOnDisplay: "sun.max"
        case .cameraControl: "camera.aperture"; case .actionButton: "button.horizontal"; case .appleIntelligence: "sparkles"
        case .stageManager: "rectangle.3.group"; case .applePencil: "pencil.tip"; case .hdr: "sun.max.fill"
        case .batteryCycles: "battery.100"
        }
    }
}

struct Verdict: Sendable { let status: FeatureStatus; let reason: String }

enum CompatEngine {
    static let researchedMax = 27

    static func evaluate(_ f: Feature, _ d: DeviceSnapshot) -> Verdict {
        let major = d.os.major
        let beyond = major > researchedMax
        func hw(_ set: Set<String>, minOS: OSVersion? = nil, phoneOnly: Bool = true, unverified: Set<String> = ModelTable.specUnverified) -> Verdict {
            if phoneOnly && d.isPad { return Verdict(status: .unsupported, reason: "该功能为 iPhone 硬件特性") }
            if !d.recognized { return Verdict(status: .unverified, reason: "机型 \(d.identifier) 不在本应用机型表中") }
            if unverified.contains(d.identifier) { return Verdict(status: .unverified, reason: "\(d.marketingName ?? d.identifier) 的这项规格本应用未能从官方页面核实") }
            guard set.contains(d.identifier) else { return Verdict(status: .unsupported, reason: "\(d.marketingName ?? d.identifier) 不具备该硬件（依据公开机型列表整理，可能滞后）") }
            if let m = minOS, d.os < m { return Verdict(status: .limited, reason: "硬件支持，但需要 iOS \(m) 或更高（当前 \(d.os)）") }
            return Verdict(status: .available, reason: "机型表匹配（依据 Apple 规格页 / 公开机型列表整理）")
        }
        switch f {
        case .systemInfo, .diagnostics:
            if major < 18 { return Verdict(status: .unsupported, reason: "最低支持 iOS 18") }
            if beyond { return Verdict(status: .unverified, reason: "iOS \(major) 超出已调研范围（26–27）") }
            return Verdict(status: .available, reason: "基于公开 API / sysctl；个别指标不可获取时会明确标注")
        case .mgOfflineEditor:
            return Verdict(status: .available, reason: "仅编辑你导入的 plist 副本，与系统版本无关")
        case .mgSystemWrite:
            return Verdict(status: .unsupported, reason: "写入系统文件需要漏洞利用或特殊权限，按项目安全策略不集成；应用不会假装写入成功")
        case .mgLiveRead:
            return Verdict(status: .unverified, reason: "依赖私有 libMobileGestalt，可能被沙盒限制，iOS \(d.os) / \(d.build) 上的返回值未经验证")
        case .researchCenter:
            return Verdict(status: .available, reason: "需要联网访问 GitHub / NVD 公共 API")
        case .liquidGlassNative:
            return major >= 26 ? Verdict(status: .available, reason: "使用 glassEffect 等原生 API")
                               : Verdict(status: .limited, reason: "iOS 26 以下使用 Material 兼容方案")
        case .dynamicIsland: return hw(ModelTable.dynamicIsland)
        case .alwaysOnDisplay: return hw(ModelTable.alwaysOn)
        case .cameraControl: return hw(ModelTable.cameraControl, minOS: OSVersion(major: 18, minor: 0, patch: 0), unverified: ModelTable.specUnverifiedAirExtra)
        case .actionButton: return hw(ModelTable.actionButton, minOS: OSVersion(major: 17, minor: 0, patch: 0), unverified: ModelTable.specUnverifiedAirExtra)
        case .appleIntelligence:
            let v = hw(ModelTable.appleIntelligence, minOS: OSVersion(major: 18, minor: 1, patch: 0))
            return v.status == .available ? Verdict(status: .available, reason: v.reason + "；是否开放还取决于地区与语言，应用无法判定") : v
        case .stageManager:
            return d.isPad ? Verdict(status: .unverified, reason: "仅部分 iPad 型号支持，机型表未收录 iPad")
                           : Verdict(status: .unsupported, reason: "iPhone 不支持台前调度")
        case .applePencil:
            return d.isPad ? Verdict(status: .unverified, reason: "取决于 iPad 型号，机型表未收录 iPad")
                           : Verdict(status: .unsupported, reason: "iPhone 不支持 Apple Pencil")
        case .hdr:
            return d.hdrCapable ? Verdict(status: .available, reason: "屏幕报告 EDR 余量 > 1（系统 API 实测）")
                                : Verdict(status: .unsupported, reason: "屏幕 EDR 余量为 1，未报告 HDR 能力")
        case .batteryCycles:
            return Verdict(status: .unsupported, reason: "iOS 公开 API 不提供电池循环次数与健康度")
        }
    }
}
