import SwiftUI
import UIKit

enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { switch self { case .system: "跟随系统"; case .light: "浅色模式"; case .dark: "深色模式" } }
    var scheme: ColorScheme? { switch self { case .system: nil; case .light: .light; case .dark: .dark } }
}

enum AccentChoice: String, CaseIterable, Identifiable, Sendable {
    case blue, indigo, purple, pink, orange, green, teal
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .blue: .blue; case .indigo: .indigo; case .purple: .purple; case .pink: .pink
        case .orange: .orange; case .green: .green; case .teal: .teal
        }
    }
}

enum UIDensity: String, CaseIterable, Identifiable, Sendable {
    case compact, regular, comfortable
    var id: String { rawValue }
    var title: String { switch self { case .compact: "紧凑"; case .regular: "标准"; case .comfortable: "宽松" } }
    var padding: CGFloat { switch self { case .compact: 10; case .regular: 14; case .comfortable: 20 } }
    var spacing: CGFloat { switch self { case .compact: 8; case .regular: 12; case .comfortable: 18 } }
}

enum IconStyle: String, CaseIterable, Identifiable, Sendable {
    case monochrome, hierarchical, multicolor
    var id: String { rawValue }
    var title: String { switch self { case .monochrome: "单色"; case .hierarchical: "层次"; case .multicolor: "多彩" } }
    var mode: SymbolRenderingMode {
        switch self { case .monochrome: .monochrome; case .hierarchical: .hierarchical; case .multicolor: .multicolor }
    }
}

struct SettingsSnapshot: Codable, Sendable {
    var mode: String, accent: String, animationsOn: Bool, glassIntensity: Double, cornerRadius: Double
    var density: String, fontStep: Int, iconStyle: String, haptics: Bool, pageTransitions: Bool, updateRepo: String
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var mode: AppearanceMode { didSet { store.set(mode.rawValue, forKey: "mode") } }
    @Published var accent: AccentChoice { didSet { store.set(accent.rawValue, forKey: "accent") } }
    @Published var animationsOn: Bool { didSet { store.set(animationsOn, forKey: "anim") } }
    @Published var glassIntensity: Double { didSet { store.set(glassIntensity, forKey: "glass") } }
    @Published var cornerRadius: Double { didSet { store.set(cornerRadius, forKey: "radius") } }
    @Published var density: UIDensity { didSet { store.set(density.rawValue, forKey: "density") } }
    @Published var fontStep: Int { didSet { store.set(fontStep, forKey: "font") } }
    @Published var iconStyle: IconStyle { didSet { store.set(iconStyle.rawValue, forKey: "icon") } }
    @Published var haptics: Bool { didSet { store.set(haptics, forKey: "haptics") } }
    @Published var pageTransitions: Bool { didSet { store.set(pageTransitions, forKey: "pageTrans") } }
    @Published var updateRepo: String { didSet { store.set(updateRepo, forKey: "updateRepo") } }

    private var store: UserDefaults { .standard }

    init() {
        let d = UserDefaults.standard
        mode = AppearanceMode(rawValue: d.string(forKey: "mode") ?? "") ?? .system
        accent = AccentChoice(rawValue: d.string(forKey: "accent") ?? "") ?? .blue
        animationsOn = d.object(forKey: "anim") as? Bool ?? true
        glassIntensity = d.object(forKey: "glass") as? Double ?? 0.7
        cornerRadius = d.object(forKey: "radius") as? Double ?? 22
        density = UIDensity(rawValue: d.string(forKey: "density") ?? "") ?? .regular
        fontStep = d.object(forKey: "font") as? Int ?? 2
        iconStyle = IconStyle(rawValue: d.string(forKey: "icon") ?? "") ?? .hierarchical
        haptics = d.object(forKey: "haptics") as? Bool ?? true
        pageTransitions = d.object(forKey: "pageTrans") as? Bool ?? true
        updateRepo = d.string(forKey: "updateRepo") ?? "hmk849/nexus"
    }

    var radius: CGFloat { CGFloat(cornerRadius) }
    var dynamicType: DynamicTypeSize {
        let all: [DynamicTypeSize] = [.small, .medium, .large, .xLarge, .xxLarge]
        return all[min(max(fontStep, 0), all.count - 1)]
    }

    func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard haptics else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard haptics else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    var snapshot: SettingsSnapshot {
        SettingsSnapshot(mode: mode.rawValue, accent: accent.rawValue, animationsOn: animationsOn,
                         glassIntensity: glassIntensity, cornerRadius: cornerRadius, density: density.rawValue,
                         fontStep: fontStep, iconStyle: iconStyle.rawValue, haptics: haptics,
                         pageTransitions: pageTransitions, updateRepo: updateRepo)
    }
    func apply(_ s: SettingsSnapshot) {
        mode = AppearanceMode(rawValue: s.mode) ?? mode
        accent = AccentChoice(rawValue: s.accent) ?? accent
        animationsOn = s.animationsOn; glassIntensity = s.glassIntensity; cornerRadius = s.cornerRadius
        density = UIDensity(rawValue: s.density) ?? density
        fontStep = s.fontStep; iconStyle = IconStyle(rawValue: s.iconStyle) ?? iconStyle
        haptics = s.haptics; pageTransitions = s.pageTransitions; updateRepo = s.updateRepo
    }
}
