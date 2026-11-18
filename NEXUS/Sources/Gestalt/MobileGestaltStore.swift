import Foundation
import SwiftUI

struct ChangeRecord: Codable, Identifiable, Sendable {
    var id = UUID()
    let date: Date
    let action: String
    let path: String
    let old: String?
    let new: String?
}

struct BackupFile: Identifiable, Sendable {
    var id: URL { url }
    let url: URL
    let date: Date
    let size: Int
    var name: String { url.lastPathComponent }
}

enum MGError: LocalizedError {
    case notDictionary, empty
    var errorDescription: String? {
        switch self { case .notDictionary: "文件不是顶层为字典的 plist"; case .empty: "尚未载入任何 plist" }
    }
}

struct GestaltPreset: Identifiable, Sendable {
    struct Edit: Sendable { let path: [PathStep]; let value: PlistValue }
    let id: String, title: String, symbol: String
    let edits: [Edit]
    let status: FeatureStatus
    let note: String
    var isApplicable: Bool { !edits.isEmpty }
}

enum PresetCatalog {
    private static func extra(_ name: String) -> [PathStep] { [.key("CacheExtra"), .key(MGKeyCatalog.hash(name))] }
    private static let flagNote = "键名由 GitHub 项目 PoomSmart/MGKeys 的映射表核实；这是布尔能力位，预设写入整数 1（常见做法，未经验证）。仅修改你导入的 plist 副本。"

    /// 键名均已与 MGKeys 映射表逐项核对。值是否正确、系统是否接受，NEXUS 无法验证，因此全部标「未经验证」。
    static let all: [GestaltPreset] = [
        GestaltPreset(id: "di", title: "灵动岛（能力位）", symbol: "capsule.fill",
                      edits: [.init(path: extra("DeviceSupportsDynamicIsland"), value: .integer(1))], status: .unverified,
                      note: "DeviceSupportsDynamicIsland（iOS 17.4+）。\(flagNote) 机型相关的 ArtworkTraits 子类型值本应用未核实，需另行手动编辑。"),
        GestaltPreset(id: "aod", title: "Always On Display", symbol: "sun.max",
                      edits: [.init(path: extra("DeviceSupportsAlwaysOnDisplay"), value: .integer(1))], status: .unverified,
                      note: "DeviceSupportsAlwaysOnDisplay（iOS 18.0+）。\(flagNote) 相关键 DeviceSupportsAlwaysOnTime（iOS 13+）、DeviceSupportsAlwaysOnDisplayFlipbook 可在字段浏览器按名称搜索。"),
        GestaltPreset(id: "aodvib", title: "AOD 动态模糊（Vibrancy）", symbol: "circle.dotted",
                      edits: [.init(path: extra("DeviceSupportsAODVibrancy"), value: .integer(1))], status: .unverified,
                      note: "DeviceSupportsAODVibrancy（iOS 18.0+）。\(flagNote)"),
        GestaltPreset(id: "pencil", title: "Apple Pencil", symbol: "pencil.tip",
                      edits: [.init(path: extra("DeviceSupportsApplePencil"), value: .integer(1))], status: .unverified,
                      note: "DeviceSupportsApplePencil（iOS 9.3+）。\(flagNote)"),
        GestaltPreset(id: "camctl", title: "相机控制", symbol: "camera.aperture",
                      edits: [.init(path: extra("CameraButtonCapability"), value: .integer(1))], status: .unverified,
                      note: "CameraButtonCapability（iOS 18.0+）。\(flagNote)"),
        GestaltPreset(id: "action", title: "操作按钮", symbol: "button.horizontal", edits: [], status: .unverified,
                      note: "对应键 RingerButtonCapability（iOS 17.0+，键名已核实）。它是枚举而非布尔，可接受的取值我在 GitHub 页面上没找到文档，所以不提供一键修改；请在字段浏览器按名称搜索后手动编辑。"),
        GestaltPreset(id: "ai", title: "Apple Intelligence（生成式模型能力位）", symbol: "sparkles",
                      edits: [.init(path: extra("DeviceSupportsGenerativeModelSystems"), value: .integer(1))], status: .unverified,
                      note: "DeviceSupportsGenerativeModelSystems（iOS 18.0+）。\(flagNote) 是否开放还取决于 eligibility 与地区，仅改文件副本并不能开启功能。"),
        GestaltPreset(id: "hdr", title: "HDR", symbol: "sun.max.fill", edits: [], status: .unverified,
                      note: "候选键（均已核实键名）：DeviceSupportsHDRPhotoDisplay（iOS 14.5+）、DeviceSupportsExternalHDR（iOS 12.1+）。“HDR”具体指哪一项无法确定，不提供一键修改。"),
        GestaltPreset(id: "glass", title: "Liquid Glass 低性能模式", symbol: "drop.fill",
                      edits: [.init(path: extra("IsSolariumLowPerformanceDevice"), value: .integer(1))], status: .unverified,
                      note: "IsSolariumLowPerformanceDevice（iOS 26.0+）。这是把设备标记为「低性能」以降级玻璃效果的开关，不是启用 Liquid Glass。\(flagNote)"),
        GestaltPreset(id: "stage", title: "台前调度 / 增强多任务", symbol: "rectangle.3.group",
                      edits: [.init(path: extra("DeviceSupportsEnhancedMultitasking"), value: .integer(1))], status: .unverified,
                      note: "DeviceSupportsEnhancedMultitasking（iOS 16.0+）；另有 DeviceSupportsSingleDisplayEnhancedMultitasking。\(flagNote) 完整效果可能还需要其他字段。"),
        GestaltPreset(id: "tap", title: "抬起 / 轻点唤醒", symbol: "hand.tap",
                      edits: [.init(path: extra("DeviceSupportsTapToWake"), value: .integer(1))], status: .unverified, note: "DeviceSupportsTapToWake。\(flagNote)"),
        GestaltPreset(id: "chime", title: "开关机提示音", symbol: "speaker.wave.2",
                      edits: [.init(path: extra("DeviceSupportsBootChime"), value: .integer(1))], status: .unverified, note: "DeviceSupportsBootChime。\(flagNote)"),
        GestaltPreset(id: "charge", title: "80% 充电上限选项", symbol: "battery.75percent",
                      edits: [.init(path: extra("DeviceSupports80ChargeLimit"), value: .integer(1))], status: .unverified, note: "DeviceSupports80ChargeLimit（iOS 17.0+）。\(flagNote)"),
        GestaltPreset(id: "sos", title: "碰撞 SOS", symbol: "exclamationmark.triangle",
                      edits: [.init(path: extra("DeviceSupportsCollisionSOS"), value: .integer(1))], status: .unverified, note: "DeviceSupportsCollisionSOS（iOS 16.0+）。\(flagNote)"),
    ]

    /// 兼容旧调用：哈希键 → 可读名称
    static func readableName(_ key: String) -> String? { MGKeyCatalog.name(forHash: key) }
}

/// 通过 dlsym 调用私有 MGCopyAnswer，仅用于读取。系统可能拒绝返回，此时显示「不可获取」。
enum LiveGestalt {
    typealias MGCopyAnswerFn = @convention(c) (CFString) -> Unmanaged<AnyObject>?
    static let sampleKeys = ["ProductType", "ProductVersion", "BuildVersion", "HWModelStr", "marketing-name", "marketing-soc-name", "DeviceMemorySize"]

    static func answer(_ key: String) -> PlistValue? {
        guard let h = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY),
              let sym = dlsym(h, "MGCopyAnswer") else { return nil }
        let fn = unsafeBitCast(sym, to: MGCopyAnswerFn.self)
        guard let r = fn(key as CFString) else { return nil }
        return PlistValue(any: r.takeRetainedValue() as Any)
    }
}

@MainActor
final class MobileGestaltStore: ObservableObject {
    @Published private(set) var root: PlistValue?
    @Published private(set) var fileName = ""
    @Published private(set) var log: [ChangeRecord] = []
    @Published private(set) var backups: [BackupFile] = []
    @Published var lastError: String?
    private var originalData: Data?
    private var format: PropertyListSerialization.PropertyListFormat = .xml
    private var undoStack: [PlistValue] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var isGestaltShaped: Bool {
        if case .dict(let d)? = root, case .dict? = d["CacheExtra"] { return true }
        return false
    }

    private static var supportDir: URL {
        let u = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("NEXUS", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
    private static var backupDir: URL {
        let u = supportDir.appendingPathComponent("Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
    private static var logURL: URL { supportDir.appendingPathComponent("mg-changelog.json") }

    init() {
        if let d = try? Data(contentsOf: Self.logURL), let v = try? JSONDecoder.cacheDecoder.decode([ChangeRecord].self, from: d) { log = v }
        refreshBackups()
    }

    // MARK: 载入 / 新建

    func load(data: Data, name: String) throws {
        var fmt = PropertyListSerialization.PropertyListFormat.xml
        let obj = try PropertyListSerialization.propertyList(from: data, options: [], format: &fmt)
        guard let v = PlistValue(any: obj), case .dict = v else { throw MGError.notDictionary }
        _ = try writeBackup(data, name: name, tag: "original")      // 修改前自动备份原始文件
        root = v; originalData = data; format = fmt; fileName = name; undoStack = []
        record("导入", name, old: nil, new: "\(data.count) 字节")
    }

    func newBlank() {
        root = .dict(["CacheExtra": .dict([:])])
        originalData = try? PropertyListSerialization.data(fromPropertyList: root!.anyValue, format: .xml, options: 0)
        format = .xml; fileName = "blank.plist"; undoStack = []
        record("新建空白", fileName, old: nil, new: nil)
    }

    func importFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do { try load(data: try Data(contentsOf: url), name: url.lastPathComponent); lastError = nil }
        catch { lastError = "导入失败：\(error.localizedDescription)" }
    }

    // MARK: 编辑

    func value(at path: [PathStep]) -> PlistValue? { root?.get(path[...]) }

    private func mutate(_ action: String, _ path: [PathStep], old: PlistValue?, new: PlistValue?, _ body: (inout PlistValue) -> Bool) {
        guard var r = root else { lastError = MGError.empty.localizedDescription; return }
        let prev = r
        guard body(&r) else { lastError = "路径无效，修改未生效"; return }
        undoStack.append(prev); root = r; lastError = nil
        record(action, pathString(path), old: old?.summary, new: new?.summary)
    }

    func setValue(_ path: [PathStep], to v: PlistValue) {
        mutate("修改", path, old: value(at: path), new: v) { $0.set(path[...], v) }
    }
    func remove(_ path: [PathStep]) {
        mutate("删除", path, old: value(at: path), new: nil) { $0.set(path[...], nil) }
    }
    func add(to parent: [PathStep], key: String, value v: PlistValue) {
        let p = parent + [.key(key)]
        mutate("添加", p, old: nil, new: v) { $0.set(p[...], v) }
    }
    func append(to parent: [PathStep], value v: PlistValue) {
        guard case .array(let a)? = value(at: parent) else { return }
        let p = parent + [.index(a.count)]
        mutate("追加", p, old: nil, new: v) { $0.set(p[...], v) }
    }
    func apply(_ preset: GestaltPreset) {
        guard preset.isApplicable else { return }
        mutate("预设：\(preset.title)", [], old: nil, new: nil) { r in
            for e in preset.edits { guard r.set(e.path[...], e.value) else { return false } }
            return true
        }
    }
    func undo() {
        guard let prev = undoStack.popLast() else { return }
        root = prev; record("撤销", "", old: nil, new: nil)
    }
    func restoreOriginal() {
        guard let d = originalData else { return }
        var fmt = PropertyListSerialization.PropertyListFormat.xml
        guard let obj = try? PropertyListSerialization.propertyList(from: d, options: [], format: &fmt), let v = PlistValue(any: obj) else { return }
        if let r = root { undoStack.append(r) }
        root = v; format = fmt; record("恢复为导入时的原始数据", fileName, old: nil, new: nil)
    }

    // MARK: 备份 / 导出

    @discardableResult
    private func writeBackup(_ data: Data, name: String, tag: String) throws -> URL {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd-HHmmss"
        let base = (name as NSString).deletingPathExtension
        let url = Self.backupDir.appendingPathComponent("\(f.string(from: Date()))-\(tag)-\(base).plist")
        try data.write(to: url, options: .atomic)
        refreshBackups()
        return url
    }

    private func serialized() throws -> Data {
        guard let r = root else { throw MGError.empty }
        let fmt: PropertyListSerialization.PropertyListFormat = format == .openStep ? .xml : format
        return try PropertyListSerialization.data(fromPropertyList: r.anyValue, format: fmt, options: 0)
    }

    func backupNow() {
        do { try writeBackup(try serialized(), name: fileName.isEmpty ? "current" : fileName, tag: "manual"); lastError = nil }
        catch { lastError = "备份失败：\(error.localizedDescription)" }
    }

    func restore(_ b: BackupFile) {
        do {
            let data = try Data(contentsOf: b.url)
            var fmt = PropertyListSerialization.PropertyListFormat.xml
            let obj = try PropertyListSerialization.propertyList(from: data, options: [], format: &fmt)
            guard let v = PlistValue(any: obj), case .dict = v else { throw MGError.notDictionary }
            if let r = root { undoStack.append(r) }
            root = v; format = fmt; if fileName.isEmpty { fileName = b.name }
            record("从备份恢复", b.name, old: nil, new: nil)
        } catch { lastError = "恢复失败：\(error.localizedDescription)" }
    }

    func deleteBackup(_ b: BackupFile) { try? FileManager.default.removeItem(at: b.url); refreshBackups() }

    func refreshBackups() {
        let files = (try? FileManager.default.contentsOfDirectory(at: Self.backupDir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])) ?? []
        backups = files.compactMap { u in
            let v = try? u.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            return BackupFile(url: u, date: v?.contentModificationDate ?? .distantPast, size: v?.fileSize ?? 0)
        }.sorted { $0.date > $1.date }
    }

    func exportFile() -> URL? {
        do {
            let base = (fileName as NSString).deletingPathExtension
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(base.isEmpty ? "export" : base)-edited.plist")
            try serialized().write(to: url, options: .atomic)
            return url
        } catch { lastError = "导出失败：\(error.localizedDescription)"; return nil }
    }

    func clearLog() { log = []; persistLog() }

    private func record(_ action: String, _ path: String, old: String?, new: String?) {
        log.insert(ChangeRecord(date: Date(), action: action, path: path, old: old, new: new), at: 0)
        if log.count > 500 { log.removeLast(log.count - 500) }
        persistLog()
    }
    private func persistLog() {
        if let d = try? JSONEncoder.cacheEncoder.encode(log) { try? d.write(to: Self.logURL, options: .atomic) }
    }
}
