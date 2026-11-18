import UIKit
import Metal
import os
import AVFoundation
import CoreMotion
import LocalAuthentication

struct InfoItem: Identifiable, Sendable {
    var id: String { title }
    let title: String
    let value: String?
    var note: String? = nil
}
struct InfoSection: Identifiable, Sendable {
    var id: String { title }
    let title: String
    let symbol: String
    var items: [InfoItem]
}

func sysctlString(_ name: String) -> String? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
    var buf = [UInt8](repeating: 0, count: size)
    guard sysctlbyname(name, &buf, &size, nil, 0) == 0 else { return nil }
    return String(decoding: buf.prefix { $0 != 0 }, as: UTF8.self)
}

func sysctlInt(_ name: String) -> Int64? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0 else { return nil }
    if size == 8 { var v: Int64 = 0; return sysctlbyname(name, &v, &size, nil, 0) == 0 ? v : nil }
    if size == 4 { var v: Int32 = 0; return sysctlbyname(name, &v, &size, nil, 0) == 0 ? Int64(v) : nil }
    return nil
}

func formatBytes(_ v: Int64, style: ByteCountFormatter.CountStyle = .file) -> String {
    ByteCountFormatter.string(fromByteCount: v, countStyle: style)
}

@MainActor
enum DeviceInfoService {
    static func machineIdentifier() -> String {
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return sim }
        return sysctlString("hw.machine") ?? "unknown"
    }

    static func currentScreen() -> UIScreen? {
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen }.first
    }

    static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }.first { $0.isKeyWindow }
    }

    static func snapshot() -> DeviceSnapshot {
        let id = machineIdentifier()
        let edr = currentScreen()?.potentialEDRHeadroom ?? 1
        return DeviceSnapshot(identifier: id, marketingName: ModelTable.names[id], os: .current,
                              build: sysctlString("kern.osversion") ?? "未知",
                              isPad: UIDevice.current.userInterfaceIdiom == .pad, hdrCapable: edr > 1.0)
    }

    // MARK: 系统信息

    static func sections() -> [InfoSection] {
        let dev = UIDevice.current
        let snap = snapshot()
        var out: [InfoSection] = []

        out.append(InfoSection(title: "设备", symbol: "iphone", items: [
            InfoItem(title: "型号", value: snap.marketingName ?? "未收录（\(snap.identifier)）"),
            InfoItem(title: "机型标识符", value: snap.identifier),
            InfoItem(title: "市场名称（MobileGestalt）", value: LiveGestalt.answer("marketing-name")?.summary,
                     note: "私有 API（键 marketing-name），未经验证；读取失败时显示不可获取"),
            InfoItem(title: "设备名称", value: dev.name, note: "iOS 16+ 未获得授权时系统只返回通用名称"),
            InfoItem(title: "系统", value: "\(dev.systemName) \(dev.systemVersion)"),
            InfoItem(title: "Build Number", value: snap.build),
            InfoItem(title: "Darwin 版本", value: sysctlString("kern.osrelease")),
            InfoItem(title: "供应商标识符 (IDFV)", value: dev.identifierForVendor?.uuidString),
            InfoItem(title: "序列号 / UDID / IMEI", value: nil, note: "公开 API 不提供，应用不会伪造"),
        ]))

        var cpu: [InfoItem] = [
            InfoItem(title: "架构标识 hw.machine", value: sysctlString("hw.machine")),
            InfoItem(title: "逻辑核心数", value: sysctlInt("hw.ncpu").map(String.init)),
            InfoItem(title: "活动核心数", value: "\(ProcessInfo.processInfo.activeProcessorCount)"),
            InfoItem(title: "CPU family (hex)", value: sysctlInt("hw.cpufamily").map { String($0, radix: 16) }),
            InfoItem(title: "L1 数据缓存", value: sysctlInt("hw.l1dcachesize").map { formatBytes($0, style: .binary) }),
            InfoItem(title: "L2 缓存", value: sysctlInt("hw.l2cachesize").map { formatBytes($0, style: .binary) }),
            InfoItem(title: "CPU 主频", value: sysctlInt("hw.cpufrequency").map { "\($0 / 1_000_000) MHz" }, note: "iOS 不开放主频"),
        ]
        let soc = LiveGestalt.answer("marketing-soc-name")?.summary
        cpu.append(InfoItem(title: "芯片市场名称", value: soc,
                            note: soc == nil ? "公开 API 不提供；私有 MobileGestalt 读取也未返回（键 marketing-soc-name）" : "来自私有 MobileGestalt 键 marketing-soc-name，未经验证"))
        out.append(InfoSection(title: "CPU", symbol: "cpu", items: cpu))

        var gpu: [InfoItem] = []
        if let m = MTLCreateSystemDefaultDevice() {
            let families: [(MTLGPUFamily, String)] = [(.apple9, "Apple9"), (.apple8, "Apple8"), (.apple7, "Apple7"), (.apple6, "Apple6")]
            let top = families.first { m.supportsFamily($0.0) }?.1
            gpu = [
                InfoItem(title: "名称 (Metal)", value: m.name),
                InfoItem(title: "最高 GPU Family（已探测至 Apple9）", value: top),
                InfoItem(title: "统一内存", value: m.hasUnifiedMemory ? "是" : "否"),
                InfoItem(title: "推荐工作集上限", value: formatBytes(Int64(m.recommendedMaxWorkingSetSize), style: .memory)),
            ]
        } else {
            gpu = [InfoItem(title: "Metal 设备", value: nil)]
        }
        out.append(InfoSection(title: "GPU", symbol: "square.stack.3d.up", items: gpu))

        out.append(InfoSection(title: "内存", symbol: "memorychip", items: [
            InfoItem(title: "物理内存", value: formatBytes(Int64(ProcessInfo.processInfo.physicalMemory), style: .memory)),
            InfoItem(title: "本应用当前可用内存", value: formatBytes(Int64(os_proc_available_memory()), style: .memory),
                     note: "os_proc_available_memory，仅反映本应用的上限"),
        ]))

        out.append(InfoSection(title: "存储", symbol: "internaldrive", items: storageItems()))
        out.append(InfoSection(title: "电池", symbol: "battery.100", items: batteryItems()))
        out.append(InfoSection(title: "屏幕", symbol: "display", items: screenItems()))
        return out
    }

    static func storageItems() -> [InfoItem] {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let v = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
        let total = v?.volumeTotalCapacity.map(Int64.init)
        let free = v?.volumeAvailableCapacityForImportantUsage
        return [
            InfoItem(title: "总容量", value: total.map { formatBytes($0) }),
            InfoItem(title: "可用（重要用途）", value: free.map { formatBytes($0) }),
            InfoItem(title: "已用", value: (total != nil && free != nil) ? formatBytes(total! - free!) : nil),
        ]
    }

    static func batteryItems() -> [InfoItem] {
        let dev = UIDevice.current
        dev.isBatteryMonitoringEnabled = true
        let level = dev.batteryLevel
        let state: String
        switch dev.batteryState {
        case .charging: state = "充电中"; case .full: state = "已充满"; case .unplugged: state = "未充电"
        default: state = "未知"
        }
        return [
            InfoItem(title: "电量", value: level >= 0 ? "\(Int(level * 100))%" : nil, note: level < 0 ? "模拟器或系统未提供" : nil),
            InfoItem(title: "状态", value: state),
            InfoItem(title: "低电量模式", value: ProcessInfo.processInfo.isLowPowerModeEnabled ? "开启" : "关闭"),
            InfoItem(title: "电池健康度", value: nil, note: "公开 API 不提供"),
            InfoItem(title: "循环次数", value: nil, note: "公开 API 不提供"),
        ]
    }

    static func screenItems() -> [InfoItem] {
        guard let s = currentScreen() else { return [InfoItem(title: "屏幕", value: nil)] }
        let top = keyWindow()?.safeAreaInsets.top
        return [
            InfoItem(title: "逻辑分辨率", value: "\(Int(s.bounds.width)) × \(Int(s.bounds.height)) pt"),
            InfoItem(title: "原生分辨率", value: "\(Int(s.nativeBounds.width)) × \(Int(s.nativeBounds.height)) px"),
            InfoItem(title: "缩放 / 原生缩放", value: String(format: "%.2fx / %.2fx", s.scale, s.nativeScale)),
            InfoItem(title: "最高刷新率", value: "\(s.maximumFramesPerSecond) Hz"),
            InfoItem(title: "亮度", value: String(format: "%.0f%%", s.brightness * 100)),
            InfoItem(title: "色域", value: s.traitCollection.displayGamut == .P3 ? "Display P3" : "sRGB"),
            InfoItem(title: "EDR 余量（当前 / 潜在）", value: String(format: "%.2f / %.2f", s.currentEDRHeadroom, s.potentialEDRHeadroom)),
            InfoItem(title: "顶部安全区", value: top.map { String(format: "%.0f pt", $0) }, note: "仅供参考，不作灵动岛判定依据"),
        ]
    }

    static func exportText(_ sections: [InfoSection]) -> String {
        sections.map { sec in
            "【\(sec.title)】\n" + sec.items.map { "\($0.title): \($0.value ?? "不可获取")" }.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }

    // MARK: 检测

    static func thermalText() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: "正常"; case .fair: "轻度升温"; case .serious: "严重升温"; case .critical: "危急"
        @unknown default: "未知"
        }
    }

    static func uptimeText() -> String {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.day, .hour, .minute]; f.unitsStyle = .abbreviated
        return f.string(from: ProcessInfo.processInfo.systemUptime) ?? "—"
    }

    static func sensorAvailability() -> [(String, Bool)] {
        let cams = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera, .builtInTrueDepthCamera],
            mediaType: .video, position: .unspecified).devices.count
        let ctx = LAContext()
        var err: NSError?
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
        let bio: String
        switch ctx.biometryType { case .faceID: bio = "Face ID"; case .touchID: bio = "Touch ID"; case .opticID: bio = "Optic ID"; default: bio = "无生物识别" }
        UIDevice.current.isProximityMonitoringEnabled = true
        let prox = UIDevice.current.isProximityMonitoringEnabled
        UIDevice.current.isProximityMonitoringEnabled = false
        return [
            ("加速度计", CMMotionManager().isAccelerometerAvailable), ("陀螺仪", CMMotionManager().isGyroAvailable),
            ("磁力计", CMMotionManager().isMagnetometerAvailable), ("气压计（相对高度）", CMAltimeter.isRelativeAltitudeAvailable()),
            ("距离传感器", prox), ("摄像头 × \(cams)", cams > 0), ("生物识别：\(bio)", ctx.biometryType != .none),
        ]
    }
}

@MainActor
final class SensorMonitor: ObservableObject {
    @Published var accel: (x: Double, y: Double, z: Double)?
    private let mgr = CMMotionManager()
    func start() {
        guard mgr.isAccelerometerAvailable, !mgr.isAccelerometerActive else { return }
        mgr.accelerometerUpdateInterval = 0.2
        mgr.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let a = data?.acceleration else { return }
            MainActor.assumeIsolated { self?.accel = (a.x, a.y, a.z) }
        }
    }
    func stop() { mgr.stopAccelerometerUpdates() }
}

enum Benchmark {
    static func work(_ n: Int) -> UInt64 {
        var x: UInt64 = 0x9E3779B97F4A7C15
        for i in 0..<n { x ^= x << 13; x ^= x >> 7; x ^= x << 17; x = x &+ UInt64(i) }
        return x
    }
    static func seconds(_ d: Duration) -> Double { Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18 }

    /// 返回 (单核 Mops/s, 多核 Mops/s)。仅用于同机型横向对比，不是权威跑分。
    static func run() async -> (single: Double, multi: Double) {
        let n = 40_000_000
        let t0 = ContinuousClock.now
        _ = await Task.detached { work(n) }.value
        let single = Double(n) / seconds(t0.duration(to: .now)) / 1e6
        let cores = max(ProcessInfo.processInfo.activeProcessorCount, 1)
        let t1 = ContinuousClock.now
        await withTaskGroup(of: UInt64.self) { g in
            for _ in 0..<cores { g.addTask { work(n) } }
            for await _ in g {}
        }
        let multi = Double(n * cores) / seconds(t1.duration(to: .now)) / 1e6
        return (single, multi)
    }
}
