import os
import SwiftUI

struct SystemInfoView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var net: NetworkMonitor
    @State private var sections = DeviceInfoService.sections()

    var body: some View {
        ScrollView {
            VStack(spacing: settings.density.spacing) {
                ForEach(sections) { sec in
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(sec.title, sec.symbol)
                        ForEach(sec.items) { InfoRow(item: $0) }
                    }.glassCard()
                }
                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle("网络", "network")
                    InfoRow(item: InfoItem(title: "连接状态", value: net.satisfied ? "已连接" : "未连接"))
                    InfoRow(item: InfoItem(title: "接口", value: net.interfaces.isEmpty ? nil : net.interfaces.joined(separator: " / ")))
                    InfoRow(item: InfoItem(title: "蜂窝制式", value: NetworkMonitor.radioTechnologies().first, note: "无蜂窝服务时为空"))
                    InfoRow(item: InfoItem(title: "IPv4 / IPv6", value: "\(net.ipv4 ? "✓" : "✗") / \(net.ipv6 ? "✓" : "✗")"))
                    InfoRow(item: InfoItem(title: "低数据模式 / 计费网络", value: "\(net.constrained ? "是" : "否") / \(net.expensive ? "是" : "否")"))
                    InfoRow(item: InfoItem(title: "运营商名称", value: nil, note: "iOS 16 起相关 API 已弃用，不再返回"))
                }.glassCard()
            }.padding()
        }
        .background(AppBackground())
        .navigationTitle("系统信息")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button { sections = DeviceInfoService.sections() } label: { Image(systemName: "arrow.clockwise") } }
            ToolbarItem(placement: .topBarTrailing) { ShareLink(item: DeviceInfoService.exportText(sections)) }
        }
    }
}

struct DiagnosticsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var net: NetworkMonitor
    @StateObject private var sensors = SensorMonitor()
    @State private var battery = DeviceInfoService.batteryItems()
    @State private var storage = DeviceInfoService.storageItems()
    @State private var memFree = os_proc_available_memory_wrapper()
    @State private var bench: (single: Double, multi: Double)?
    @State private var benchRunning = false
    @State private var speed: SpeedTest.Result?
    @State private var speedRunning = false
    @State private var speedError: String?
    @State private var availability = DeviceInfoService.sensorAvailability()

    var body: some View {
        ScrollView {
            VStack(spacing: settings.density.spacing) {
                card("CPU 性能", "cpu") {
                    InfoRow(item: InfoItem(title: "核心数", value: "\(ProcessInfo.processInfo.activeProcessorCount)"))
                    if let b = bench {
                        InfoRow(item: InfoItem(title: "单核", value: String(format: "%.0f Mops/s", b.single)))
                        InfoRow(item: InfoItem(title: "多核", value: String(format: "%.0f Mops/s", b.multi)))
                    }
                    Button { runBench() } label: { benchRunning ? AnyView(ProgressView()) : AnyView(L("运行基准测试")) }
                        .buttonStyle(.bordered).disabled(benchRunning)
                    L("自带整数运算基准，仅适合同机型对比，不是权威跑分。").font(.caption2).foregroundStyle(.tertiary)
                }
                card("电池与温度", "thermometer.medium") {
                    ForEach(battery) { InfoRow(item: $0) }
                    InfoRow(item: InfoItem(title: "热状态", value: DeviceInfoService.thermalText()))
                    InfoRow(item: InfoItem(title: "具体温度数值", value: nil, note: "iOS 不向 App 开放传感器温度"))
                    InfoRow(item: InfoItem(title: "开机时长", value: DeviceInfoService.uptimeText()))
                }
                card("存储", "internaldrive") {
                    ForEach(storage) { InfoRow(item: $0) }
                    InfoRow(item: InfoItem(title: "本应用可用内存", value: formatBytes(memFree, style: .memory)))
                }
                card("网络", "wifi") {
                    InfoRow(item: InfoItem(title: "状态", value: net.satisfied ? (net.interfaces.joined(separator: " / ")) : "未连接"))
                    if let s = speed {
                        InfoRow(item: InfoItem(title: "延迟（HTTPS 往返）", value: String(format: "%.0f ms", s.latencyMs)))
                        InfoRow(item: InfoItem(title: "下载速度", value: String(format: "%.1f Mbps", s.mbps), note: "下载 \(formatBytes(Int64(s.bytes))) 测得"))
                    }
                    if let e = speedError { Text(e).font(.caption).foregroundStyle(.red) }
                    Button { runSpeed() } label: { speedRunning ? AnyView(ProgressView()) : AnyView(L("测速（约消耗 10 MB 流量）")) }
                        .buttonStyle(.bordered).disabled(speedRunning || !net.satisfied)
                }
                card("屏幕", "display") { ForEach(DeviceInfoService.screenItems()) { InfoRow(item: $0) } }
                card("传感器", "sensor") {
                    ForEach(availability, id: \.0) { a in
                        HStack { Text(a.0); Spacer(); StatusBadge(status: a.1 ? .available : .unsupported) }.font(.subheadline)
                    }
                    if let a = sensors.accel {
                        InfoRow(item: InfoItem(title: "加速度 (g)", value: String(format: "x %.2f  y %.2f  z %.2f", a.x, a.y, a.z)))
                    }
                }
            }.padding()
        }
        .background(AppBackground())
        .navigationTitle("设备检测")
        .task {
            sensors.start()
            while !Task.isCancelled {
                battery = DeviceInfoService.batteryItems(); storage = DeviceInfoService.storageItems()
                memFree = os_proc_available_memory_wrapper()
                try? await Task.sleep(for: .seconds(3))
            }
        }
        .onDisappear { sensors.stop() }
    }

    private func card<Content: View>(_ title: String, _ symbol: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) { SectionTitle(title, symbol); content() }.glassCard()
    }
    private func runBench() {
        benchRunning = true
        Task { bench = await Benchmark.run(); benchRunning = false }
    }
    private func runSpeed() {
        speedRunning = true; speedError = nil
        Task {
            do { speed = try await SpeedTest.run() } catch { speedError = "测速失败：\(error.localizedDescription)" }
            speedRunning = false
        }
    }
}

func os_proc_available_memory_wrapper() -> Int64 { Int64(os_proc_available_memory()) }
