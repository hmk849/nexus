import SwiftUI

@main
struct NexusApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var favorites = FavoritesStore()
    @StateObject private var research = ResearchStore()
    @StateObject private var gestalt = MobileGestaltStore()
    @StateObject private var network = NetworkMonitor()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(favorites)
                .environmentObject(research)
                .environmentObject(gestalt)
                .environmentObject(network)
                .tint(settings.accent.color)
                .preferredColorScheme(settings.mode.scheme)
                .dynamicTypeSize(settings.dynamicType)
                .symbolRenderingMode(settings.iconStyle.mode)
                .transaction { t in
                    if !settings.animationsOn { t.disablesAnimations = true }
                }
        }
    }
}

enum NexusTab: Hashable { case home, toolbox, research, favorites, settings }

struct RootView: View {
    @State private var tab: NexusTab = .home

    var body: some View {
        TabView(selection: $tab) {
            Tab("首页", systemImage: "house.fill", value: NexusTab.home) { HomeView() }
            Tab("工具箱", systemImage: "wrench.and.screwdriver.fill", value: NexusTab.toolbox) { ToolboxView() }
            Tab("研究中心", systemImage: "books.vertical.fill", value: NexusTab.research) { ResearchView() }
            Tab("收藏", systemImage: "star.fill", value: NexusTab.favorites) { FavoritesView() }
            Tab("设置", systemImage: "gearshape.fill", value: NexusTab.settings) { SettingsView() }
        }
    }
}
