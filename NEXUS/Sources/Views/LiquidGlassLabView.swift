import SwiftUI

/// Liquid Glass 实验室：iOS 26+ 使用原生 glassEffect 系列 API；更低系统回退到 Material。
struct LiquidGlassLabView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var forceFallback = false
    @State private var sliderValue = 0.5
    @State private var query = ""
    @State private var showPopup = false
    @State private var tabSel = 0
    @State private var dragOffset = CGSize.zero
    @State private var panelOffset = CGSize.zero

    private var native: Bool { !forceFallback }
    private var isNativeOS: Bool { OSVersion.current.major >= 26 }

    var body: some View {
        ZStack {
            LabBackdrop()
            ScrollView {
                VStack(spacing: 16) {
                    statusCard
                    demo("玻璃卡片") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Glass Card").font(.headline)
                            L("regular 玻璃 + 强调色着色").font(.subheadline).foregroundStyle(.secondary)
                        }.padding().frame(maxWidth: .infinity, alignment: .leading)
                         .nexusGlass(in: RoundedRectangle(cornerRadius: settings.radius, style: .continuous), tint: settings.accent.color.opacity(0.25), native: native)
                    }
                    demo("玻璃导航栏") {
                        HStack {
                            Image(systemName: "chevron.left"); Spacer(); Text("标题").font(.headline); Spacer(); Image(systemName: "ellipsis")
                        }.padding(.horizontal, 18).padding(.vertical, 12)
                         .nexusGlass(in: Capsule(), native: native)
                        L("系统导航栏在 iOS 26 默认就是玻璃；此处为自绘示意。").font(.caption).foregroundStyle(.secondary)
                    }
                    demo("玻璃按钮") { GlassButtons(native: native) }
                    demo("动态玻璃（融合 / 变形）") {
                        if #available(iOS 26.0, *), native { MorphDemo() }
                        else { L("需要 iOS 26+ 与原生模式：GlassEffectContainer + glassEffectID。").font(.caption).foregroundStyle(.secondary) }
                    }
                    demo("交互式玻璃（拖动我）") {
                        Image(systemName: "hand.draw").font(.title2).frame(width: 72, height: 72)
                            .nexusGlass(in: Circle(), interactive: true, native: native)
                            .offset(dragOffset)
                            .gesture(DragGesture().onChanged { dragOffset = $0.translation }
                                .onEnded { _ in withAnimation(.bouncy) { dragOffset = .zero } })
                            .frame(maxWidth: .infinity)
                    }
                    demo("玻璃标签栏") { GlassTabBar(selection: $tabSel, native: native) }
                    demo("玻璃搜索框") {
                        HStack { Image(systemName: "magnifyingglass"); TextField("搜索", text: $query) }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .nexusGlass(in: Capsule(), interactive: true, native: native)
                    }
                    demo("玻璃弹窗") {
                        Button { withAnimation(.smooth) { showPopup = true } } label: { LabelL("弹出玻璃弹窗", "rectangle.portrait.and.arrow.right") }
                            .buttonStyle(.bordered)
                    }
                    demo("悬浮控制面板（可拖动）") {
                        VStack(spacing: 10) {
                            HStack { Image(systemName: "sun.min"); Slider(value: $sliderValue); Image(systemName: "sun.max") }
                            HStack(spacing: 20) { ForEach(["wifi", "bluetooth", "airplane", "moon"], id: \.self) { n in
                                Image(systemName: n == "bluetooth" ? "dot.radiowaves.left.and.right" : n).frame(width: 44, height: 44)
                                    .nexusGlass(in: Circle(), interactive: true, native: native)
                            } }
                        }.padding()
                         .nexusGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous), native: native)
                         .offset(panelOffset)
                         .gesture(DragGesture().onChanged { panelOffset = $0.translation }.onEnded { _ in withAnimation(.bouncy) { panelOffset = .zero } })
                    }
                }.padding()
            }
            if showPopup {
                Color.black.opacity(0.25).ignoresSafeArea().onTapGesture { withAnimation(.smooth) { showPopup = false } }
                VStack(spacing: 12) {
                    Image(systemName: "drop.fill").font(.largeTitle).foregroundStyle(settings.accent.color)
                    Text("玻璃弹窗").font(.headline)
                    L("点击背景或按钮关闭。").font(.subheadline).foregroundStyle(.secondary)
                    Button("好的") { withAnimation(.smooth) { showPopup = false } }.buttonStyle(.borderedProminent)
                }.padding(28)
                 .nexusGlass(in: RoundedRectangle(cornerRadius: 32, style: .continuous), native: native)
                 .transition(.scale.combined(with: .opacity))
            }
        }
        .navigationTitle("Liquid Glass 实验室")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                LabelL("渲染路径", "paintbrush.pointed").font(.headline); Spacer()
                StatusBadge(status: isNativeOS && native ? .available : .limited)
            }
            L(isNativeOS ? (native ? "当前使用原生 Liquid Glass API。" : "已强制使用 Material 兼容方案（对比用）。") : "系统低于 iOS 26，自动使用 Material 兼容方案；它不是真正的 Liquid Glass。")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("强制兼容方案（对比）", isOn: $forceFallback).font(.subheadline)
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading)
        .nexusGlass(in: RoundedRectangle(cornerRadius: settings.radius, style: .continuous), native: native)
    }

    private func demo<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            L(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.9)).shadow(radius: 2)
            content()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LabBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo, .purple, .pink.opacity(0.8), .orange.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.cyan.opacity(0.7)).frame(width: 220).offset(x: -110, y: -120).blur(radius: 30)
            Circle().fill(.yellow.opacity(0.6)).frame(width: 180).offset(x: 130, y: 260).blur(radius: 30)
        }.ignoresSafeArea()
    }
}

private struct GlassButtons: View {
    let native: Bool
    var body: some View {
        HStack(spacing: 12) {
            if #available(iOS 26.0, *), native {
                Button("Glass") {}.buttonStyle(.glass)
                Button("Prominent") {}.buttonStyle(.glassProminent)
            } else {
                Button("Bordered") {}.buttonStyle(.bordered)
                Button("Prominent") {}.buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct GlassTabBar: View {
    @Binding var selection: Int
    let native: Bool
    @Namespace private var ns
    private let icons = ["house.fill", "magnifyingglass", "heart.fill", "person.fill"]
    var body: some View {
        if #available(iOS 26.0, *), native {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) { ForEach(icons.indices, id: \.self) { i in tabItem(i) } }
            }
        } else {
            HStack(spacing: 8) { ForEach(icons.indices, id: \.self) { i in tabItem(i) } }
        }
    }
    @ViewBuilder private func tabItem(_ i: Int) -> some View {
        let sel = selection == i
        let base = Image(systemName: icons[i]).font(.title3).frame(width: 58, height: 44).contentShape(Capsule())
            .onTapGesture { withAnimation(.bouncy) { selection = i } }
        if #available(iOS 26.0, *), native {
            base.glassEffect(sel ? .regular.tint(.accentColor).interactive() : .regular.interactive(), in: .capsule)
                .glassEffectID(i, in: ns)
        } else {
            base.background(sel ? AnyShapeStyle(Color.accentColor.opacity(0.35)) : AnyShapeStyle(.ultraThinMaterial), in: Capsule())
        }
    }
}

@available(iOS 26.0, *)
private struct MorphDemo: View {
    @State private var expanded = false
    @Namespace private var ns
    var body: some View {
        GlassEffectContainer(spacing: 24) {
            HStack(spacing: 20) {
                Button { withAnimation(.bouncy) { expanded.toggle() } } label: {
                    Image(systemName: expanded ? "xmark" : "plus").frame(width: 48, height: 48)
                }
                .buttonStyle(.glass).glassEffectID("toggle", in: ns)
                if expanded {
                    ForEach(["camera", "photo", "doc"], id: \.self) { s in
                        Image(systemName: s).frame(width: 48, height: 48)
                            .glassEffect(.regular.interactive(), in: .circle)
                            .glassEffectID(s, in: ns)
                            .glassEffectTransition(.matchedGeometry)
                    }
                }
            }
        }
    }
}
