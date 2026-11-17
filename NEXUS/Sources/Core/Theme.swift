import SwiftUI
import UIKit

func L(_ s: String) -> Text { Text(LocalizedStringKey(s)) }

struct LabelL: View {
    let title: String, symbol: String
    init(_ title: String, _ symbol: String) { self.title = title; self.symbol = symbol }
    var body: some View { Label { L(title) } icon: { Image(systemName: symbol) } }
}

@available(iOS 26.0, *)
func makeGlass(tint: Color?, interactive: Bool) -> Glass {
    var g = Glass.regular
    if let tint { g = g.tint(tint) }
    if interactive { g = g.interactive() }
    return g
}

extension View {
    /// iOS 26+ 使用原生 Liquid Glass；否则回退到系统 Material。
    @ViewBuilder
    func nexusGlass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false, native: Bool = true) -> some View {
        if native, #available(iOS 26.0, *) {
            self.glassEffect(makeGlass(tint: tint, interactive: interactive), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
    func glassCard(padding: CGFloat? = nil) -> some View { modifier(GlassCardModifier(padding: padding)) }
    func pageTransition() -> some View { modifier(PageTransitionModifier()) }
}

struct GlassCardModifier: ViewModifier {
    @EnvironmentObject private var settings: AppSettings
    var padding: CGFloat?
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: settings.radius, style: .continuous)
        let base = content.padding(padding ?? settings.density.padding).frame(maxWidth: .infinity, alignment: .leading)
        if #available(iOS 26.0, *) {
            base.glassEffect(makeGlass(tint: settings.accent.color.opacity(0.22 * settings.glassIntensity), interactive: false), in: shape)
        } else {
            base
                .background { shape.fill(.ultraThinMaterial).opacity(0.35 + 0.65 * settings.glassIntensity) }
                .overlay { shape.strokeBorder(Color.white.opacity(0.18)) }
        }
    }
}

struct PageTransitionModifier: ViewModifier {
    @EnvironmentObject private var settings: AppSettings
    @State private var shown = false
    func body(content: Content) -> some View {
        let hidden = settings.pageTransitions && !shown
        content
            .opacity(hidden ? 0 : 1)
            .offset(y: hidden ? 14 : 0)
            .onAppear { withAnimation(.smooth(duration: 0.35)) { shown = true } }
            .onDisappear { shown = false }
    }
}

struct AppBackground: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
            Circle().fill(settings.accent.color.opacity(scheme == .dark ? 0.38 : 0.26))
                .frame(width: 380).blur(radius: 90).offset(x: -140, y: -280)
            Circle().fill(Color.purple.opacity(scheme == .dark ? 0.30 : 0.18))
                .frame(width: 320).blur(radius: 90).offset(x: 150, y: 300)
        }
        .ignoresSafeArea()
    }
}

struct StatusBadge: View {
    let status: FeatureStatus
    var body: some View {
        Label { L(status.label) } icon: { Image(systemName: status.symbol) }
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(status.color.opacity(0.15), in: Capsule())
            .foregroundStyle(status.color)
    }
}

struct SectionTitle: View {
    let title: String, symbol: String
    init(_ title: String, _ symbol: String) { self.title = title; self.symbol = symbol }
    var body: some View {
        LabelL(title, symbol).font(.headline).padding(.bottom, 2)
    }
}

struct InfoRow: View {
    let item: InfoItem
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                L(item.title).foregroundStyle(.secondary)
                Spacer(minLength: 12)
                if let v = item.value { Text(v).multilineTextAlignment(.trailing).textSelection(.enabled) }
                else { L("不可获取").foregroundStyle(.tertiary) }
            }
            if let n = item.note { L(n).font(.caption2).foregroundStyle(.tertiary) }
        }
        .font(.subheadline)
    }
}

struct ShareItem: Identifiable { let id = UUID(); let url: URL }

struct ActivityView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
