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
    /// 只收录有公开资料可核对的键名；其余功能不提供一键修改，避免伪造键值。
    static let all: [GestaltPreset] = [
        GestaltPreset(id: "aod", title: "Always On Display", symbol: "sun.max",
                      edits: [.init(path: [.key("CacheExtra"), .key("j8/Omm6s1lsmTDFsXjsBfA")], value: .integer(1))],
                      status: .unverified,
                      note: "键 j8/Omm6s1lsmTDFsXjsBfA（DeviceSupportsAlwaysOnTime，来源：hsu.cy 研究文章）。值 1 为常见做法，未经本应用验证。"),
        GestaltPreset(id: "ai", title: "Apple Intelligence（Generative Model 能力位）", symbol: "sparkles",
                      edits: [.init(path: [.key("CacheExtra"), .key("A62OafQ85EJAiiqKn4agtg")], value: .integer(1))],
                      status: .unverified,
                      note: "键来源于社区文档，未经验证；该功能还取决于 eligibility 与地区，仅修改文件副本并不能开启。"),
        GestaltPreset(id: "di", title: "灵动岛", symbol: "capsule.fill", edits: [], status: .unverified,
                      note: "涉及 ArtworkTraits（oPeik/9e8lQWMszEjbPzng）内的设备子类型，机型相关，本应用未核实具体值。请用字段浏览器手动编辑。"),
        GestaltPreset(id: "pencil", title: "Apple Pencil", symbol: "pencil.tip", edits: [], status: .unverified, note: "键名未核实，不提供一键修改。"),
        GestaltPreset(id: "camctl", title: "相机控制", symbol: "camera.aperture", edits: [], status: .unverified, note: "键名未核实，不提供一键修改。"),
        GestaltPreset(id: "action", title: "操作按钮", symbol: "button.horizontal", edits: [], status: .unverified, note: "键名未核实，不提供一键修改。"),
        GestaltPreset(id: "hdr", title: "HDR", symbol: "sun.max.fill", edits: [], status: .unverified, note: "键名未核实，不提供一键修改。"),
        GestaltPreset(id: "glass", title: "Liquid Glass", symbol: "drop.fill", edits: [], status: .unverified, note: "键名未核实，不提供一键修改。"),
        GestaltPreset(id: "stage", title: "台前调度", symbol: "rectangle.3.group", edits: [], status: .unverified, note: "键名未核实，不提供一键修改。"),
    ]

    /// 已核实的哈希键 → 可读名称（来源：The Apple Wiki / hsu.cy）。
    static let knownKeys: [String: String] = [
        "oPeik/9e8lQWMszEjbPzng": "ArtworkTraits", "h9jDsbgj7xIVeIQ8S3/X3Q": "ProductType",
        "j8/Omm6s1lsmTDFsXjsBfA": "DeviceSupportsAlwaysOnTime", "JUWcn+5Ss0nvr5w/jk4WEg": "device-name",
        "LTI8wHvEYKy8zR1IXBW1uQ": "ArtworkTraitDisplayGamut",
    ]
}

/// 通过 dlsym 调用私有 MGCopyAnswer，仅用于读取。系统可能拒绝返回，此时显示「不可获取」。
enum LiveGestalt {
    typealias MGCopyAnswerFn = @convention(c) (CFString) -> Unmanaged<AnyObject>?
    static let sampleKeys = ["ProductType", "ProductVersion", "BuildVersion", "HWModelStr", "ArtworkDeviceSubType"]

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
