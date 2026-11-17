import SwiftUI
import UniformTypeIdentifiers

struct MobileGestaltView: View {
    @EnvironmentObject private var store: MobileGestaltStore
    @EnvironmentObject private var settings: AppSettings
    @State private var tab = 0
    @State private var importing = false
    @State private var shareItem: ShareItem?
    @State private var confirm: Confirm?
    @State private var liveKey = "ProductType"
    @State private var liveResult: String?
    @State private var snap = DeviceInfoService.snapshot()

    enum Confirm: Identifiable {
        case restoreOriginal, restore(BackupFile), deleteBackup(BackupFile), replace
        var id: String {
            switch self { case .restoreOriginal: "ro"; case .restore(let b): "r\(b.id)"; case .deleteBackup(let b): "d\(b.id)"; case .replace: "rep" }
        }
        var title: String {
            switch self {
            case .restoreOriginal: "恢复为导入时的原始数据？"; case .restore: "用此备份覆盖当前编辑内容？"
            case .deleteBackup: "删除这个备份？无法撤销。"; case .replace: "导入新文件将替换当前正在编辑的内容，继续？"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: settings.density.spacing) {
                statusCard
                if store.root == nil { emptyCard } else { workspace }
                liveCard
            }.padding()
        }
        .background(AppBackground())
        .navigationTitle("MobileGestalt")
        .toolbar {
            if store.root != nil {
                ToolbarItem(placement: .topBarTrailing) { Button { store.undo() } label: { Image(systemName: "arrow.uturn.backward") }.disabled(!store.canUndo) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { if let u = store.exportFile() { shareItem = ShareItem(url: u) } } label: { Image(systemName: "square.and.arrow.up") }
                }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.propertyList, .data]) { r in
            if case .success(let u) = r { store.importFile(u); tab = 0 }
        }
        .sheet(item: $shareItem) { ActivityView(url: $0.url) }
        .confirmationDialog(confirm.map { LocalizedStringKey($0.title) } ?? "", isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }),
                            titleVisibility: .visible, presenting: confirm) { c in
            Button("确认", role: .destructive) { run(c) }
        }
        .navigationDestination(for: PathBox.self) { GestaltNodeView(path: $0.path) }
        .pageTransition()
    }

    private func run(_ c: Confirm) {
        switch c {
        case .restoreOriginal: store.restoreOriginal()
        case .restore(let b): store.restore(b)
        case .deleteBackup(let b): store.deleteBackup(b)
        case .replace: importing = true
        }
        settings.notify(.warning)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("能力边界", "shield.lefthalf.filled")
            ForEach([Feature.mgOfflineEditor, .mgSystemWrite, .mgLiveRead]) { f in
                let v = CompatEngine.evaluate(f, snap)
                VStack(alignment: .leading, spacing: 2) {
                    HStack { L(f.title).font(.subheadline.weight(.medium)); Spacer(); StatusBadge(status: v.status) }
                    Text(v.reason).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let e = store.lastError { Text(e).font(.caption).foregroundStyle(.red) }
        }.glassCard()
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("载入 plist", "doc.badge.plus")
            L("导入你自己设备上取得的 com.apple.MobileGestalt.plist 副本，或新建空白文件用于试验。普通 App 无法读取系统中的该文件，NEXUS 不会尝试绕过沙盒。").font(.subheadline).foregroundStyle(.secondary)
            HStack {
                Button { importing = true } label: { LabelL("导入 plist", "square.and.arrow.down") }.buttonStyle(.borderedProminent)
                Button { store.newBlank() } label: { LabelL("新建空白", "doc") }.buttonStyle(.bordered)
            }
        }.glassCard()
    }

    @ViewBuilder private var workspace: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(store.fileName).font(.headline)
                    if !store.isGestaltShaped { L("缺少 CacheExtra 字典，可能不是 MobileGestalt 文件").font(.caption).foregroundStyle(.orange) }
                }
                Spacer()
                Button { confirm = .replace } label: { Image(systemName: "square.and.arrow.down") }.buttonStyle(.bordered)
            }
            Picker("", selection: $tab) {
                Text("字段").tag(0); Text("预设").tag(1); Text("记录").tag(2); Text("备份").tag(3)
            }.pickerStyle(.segmented)
        }.glassCard()

        switch tab {
        case 0: fieldsCard
        case 1: presetsCard
        case 2: logCard
        default: backupsCard
        }
    }

    private var fieldsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink(value: PathBox(path: [])) { row("根字典", "curlybraces", "顶层字段") }
            if case .dict? = store.value(at: [.key("CacheExtra")]) {
                Divider()
                NavigationLink(value: PathBox(path: [.key("CacheExtra")])) { row("CacheExtra", "slider.horizontal.3", "能力与设备字段（多为哈希键）") }
            }
        }.buttonStyle(.plain).glassCard()
    }

    private func row(_ title: String, _ symbol: String, _ sub: String) -> some View {
        HStack {
            Image(systemName: symbol).frame(width: 28)
            VStack(alignment: .leading) { Text(title).font(.subheadline.weight(.medium)); L(sub).font(.caption).foregroundStyle(.secondary) }
            Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
    }

    private var presetsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            L("预设只修改上面载入的 plist 副本，并可撤销；NEXUS 不会把结果写入系统。键名无公开资料可核对的功能不提供一键修改。").font(.caption).foregroundStyle(.secondary)
            ForEach(PresetCatalog.all) { p in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        LabelL(p.title, p.symbol).font(.subheadline.weight(.medium)); Spacer()
                        StatusBadge(status: p.status)
                        if p.isApplicable { Button("应用") { store.apply(p); settings.tap() }.buttonStyle(.bordered).controlSize(.small) }
                    }
                    L(p.note).font(.caption).foregroundStyle(.secondary)
                }
                Divider()
            }
        }.glassCard()
    }

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionTitle("修改记录", "clock.arrow.circlepath"); Spacer()
                Button("恢复原始数据") { confirm = .restoreOriginal }.font(.caption)
            }
            if store.log.isEmpty { L("暂无记录").foregroundStyle(.secondary) }
            ForEach(store.log.prefix(100)) { r in
                VStack(alignment: .leading, spacing: 1) {
                    HStack { Text(r.action).font(.subheadline.weight(.medium)); Spacer(); Text(r.date, style: .time).font(.caption2).foregroundStyle(.tertiary) }
                    if !r.path.isEmpty { Text(r.path).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(2) }
                    if r.old != nil || r.new != nil { Text("\(r.old ?? "∅") → \(r.new ?? "∅")").font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                }
            }
            if !store.log.isEmpty { Button("清空记录", role: .destructive) { store.clearLog() }.font(.caption) }
        }.glassCard()
    }

    private var backupsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { SectionTitle("备份", "externaldrive.badge.timemachine"); Spacer(); Button("立即备份") { store.backupNow() }.buttonStyle(.bordered).controlSize(.small) }
            L("导入文件时会自动保存原始副本。").font(.caption).foregroundStyle(.secondary)
            if store.backups.isEmpty { L("暂无备份").foregroundStyle(.secondary) }
            ForEach(store.backups) { b in
                HStack {
                    VStack(alignment: .leading) {
                        Text(b.name).font(.caption).lineLimit(1)
                        Text("\(b.date.formatted(date: .abbreviated, time: .shortened)) · \(formatBytes(Int64(b.size)))").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("恢复") { confirm = .restore(b) }.buttonStyle(.bordered).controlSize(.small)
                    Button { confirm = .deleteBackup(b) } label: { Image(systemName: "trash") }.buttonStyle(.bordered).controlSize(.small).tint(.red)
                }
            }
        }.glassCard()
    }

    private var liveCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("实时读取当前设备（私有 API）", "eye")
            L("通过 dlsym 调用 MGCopyAnswer，仅读取。系统可能拒绝返回，此时显示「不可获取」。").font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("键名，如 ProductType", text: $liveKey).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                Button("读取") { let v = LiveGestalt.answer(liveKey.trimmingCharacters(in: .whitespaces)); liveResult = v?.summary ?? "不可获取" }.buttonStyle(.bordered)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack { ForEach(LiveGestalt.sampleKeys, id: \.self) { k in Button(k) { liveKey = k }.font(.caption).buttonStyle(.bordered).controlSize(.mini) } }
            }
            if let r = liveResult { Text(r).font(.subheadline.monospaced()).textSelection(.enabled) }
        }.glassCard()
    }
}

// MARK: 节点浏览

struct GestaltNodeView: View {
    @EnvironmentObject private var store: MobileGestaltStore
    @EnvironmentObject private var settings: AppSettings
    let path: [PathStep]
    @State private var search = ""
    @State private var scope = 0
    @State private var editing: PathBox?
    @State private var adding = false
    @State private var pendingDelete: PathBox?

    private struct Entry: Identifiable { let step: PathStep; let value: PlistValue; var id: String { step.label } }

    private var entries: [Entry] {
        switch store.value(at: path) {
        case .dict(let d)?:
            return d.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.compactMap { k in d[k].map { Entry(step: .key(k), value: $0) } }
        case .array(let a)?: return a.enumerated().map { Entry(step: .index($0.offset), value: $0.element) }
        default: return []
        }
    }
    private var filtered: [Entry] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return entries }
        return entries.filter { e in
            let name = (PresetCatalog.knownKeys[e.step.label] ?? "").lowercased()
            let keyHit = e.step.label.lowercased().contains(q) || name.contains(q)
            let valHit = e.value.summary.lowercased().contains(q)
            switch scope { case 1: return keyHit; case 2: return valHit; default: return keyHit || valHit }
        }
    }

    var body: some View {
        List {
            Section {
                Picker("范围", selection: $scope) { Text("全部").tag(0); Text("键").tag(1); Text("值").tag(2) }.pickerStyle(.segmented)
            }
            Section("\(filtered.count) / \(entries.count)") {
                ForEach(filtered) { e in
                    let full = path + [e.step]
                    if e.value.isContainer {
                        NavigationLink(value: PathBox(path: full)) { rowLabel(e) }
                    } else {
                        Button { editing = PathBox(path: full) } label: { rowLabel(e) }.buttonStyle(.plain)
                            .swipeActions { Button("删除", role: .destructive) { pendingDelete = PathBox(path: full) } }
                    }
                }
            }
        }
        .navigationTitle(path.last?.label ?? "根字典")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "搜索键或值")
        .toolbar {
            if store.value(at: path)?.isContainer == true {
                ToolbarItem(placement: .topBarTrailing) { Button { adding = true } label: { Image(systemName: "plus") } }
            }
        }
        .sheet(item: $editing) { ValueEditorSheet(path: $0.path) }
        .sheet(isPresented: $adding) { AddFieldSheet(parent: path) }
        .confirmationDialog("删除这个字段？可用撤销找回。", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
            Button("删除", role: .destructive) { if let p = pendingDelete { store.remove(p.path); settings.notify(.warning) } }
        }
    }

    private func rowLabel(_ e: Entry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: e.value.kind.symbol).frame(width: 24).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.step.label).font(.subheadline.monospaced()).lineLimit(1)
                if let n = PresetCatalog.knownKeys[e.step.label] { Text(n).font(.caption).foregroundStyle(settings.accent.color) }
                Text("\(e.value.kind.title) · \(e.value.summary)").font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }
}

extension PathBox: Identifiable { var id: String { pathString(path) } }

struct ValueEditorSheet: View {
    @EnvironmentObject private var store: MobileGestaltStore
    @Environment(\.dismiss) private var dismiss
    let path: [PathStep]
    @State private var text = ""
    @State private var flag = false
    @State private var date = Date()
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                let v = store.value(at: path)
                Section("路径") { Text(pathString(path)).font(.caption.monospaced()) }
                Section(v?.kind.title ?? "") {
                    switch v?.kind {
                    case .bool?: Toggle("值", isOn: $flag)
                    case .date?: DatePicker("值", selection: $date)
                    case .data?: TextEditor(text: $text).font(.footnote.monospaced()).frame(minHeight: 140).textInputAutocapitalization(.never).autocorrectionDisabled()
                    case .integer?, .real?: TextField("值", text: $text).keyboardType(.numbersAndPunctuation)
                    default: TextField("值", text: $text, axis: .vertical)
                    }
                    if v?.kind == .data { L("以十六进制输入，空白会被忽略。").font(.caption).foregroundStyle(.secondary) }
                }
                if let error { Text(error).foregroundStyle(.red).font(.caption) }
            }
            .navigationTitle("编辑字段")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() } }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        switch store.value(at: path) {
        case .string(let s)?: text = s
        case .integer(let i)?: text = String(i)
        case .real(let d)?: text = String(d)
        case .bool(let b)?: flag = b
        case .date(let d)?: date = d
        case .data(let d)?: text = d.hexString
        default: break
        }
    }
    private func save() {
        guard let kind = store.value(at: path)?.kind,
              let nv = PlistValue.parse(kind: kind, text: text, bool: flag, date: date) else { error = "输入格式无效"; return }
        store.setValue(path, to: nv); dismiss()
    }
}

struct AddFieldSheet: View {
    @EnvironmentObject private var store: MobileGestaltStore
    @Environment(\.dismiss) private var dismiss
    let parent: [PathStep]
    @State private var key = ""
    @State private var kind: PlistKind = .string
    @State private var text = ""
    @State private var flag = false
    @State private var date = Date()
    @State private var error: String?

    private var isDict: Bool { if case .dict? = store.value(at: parent) { return true } else { return false } }

    var body: some View {
        NavigationStack {
            Form {
                if isDict { Section("键名") { TextField("键", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled() } }
                Section("类型") {
                    Picker("类型", selection: $kind) { ForEach(PlistKind.allCases) { Text($0.title).tag($0) } }
                    switch kind {
                    case .bool: Toggle("值", isOn: $flag)
                    case .date: DatePicker("值", selection: $date)
                    case .dict, .array: EmptyView()
                    default: TextField(kind == .data ? "十六进制" : "值", text: $text).textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                }
                if let error { Text(error).foregroundStyle(.red).font(.caption) }
            }
            .navigationTitle("添加字段")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("添加") { add() } }
            }
        }
    }

    private func add() {
        guard let v = PlistValue.parse(kind: kind, text: text, bool: flag, date: date) else { error = "输入格式无效"; return }
        if isDict {
            let k = key.trimmingCharacters(in: .whitespaces)
            guard !k.isEmpty else { error = "键名不能为空"; return }
            if case .dict(let d)? = store.value(at: parent), d[k] != nil { error = "键已存在"; return }
            store.add(to: parent, key: k, value: v)
        } else { store.append(to: parent, value: v) }
        dismiss()
    }
}
