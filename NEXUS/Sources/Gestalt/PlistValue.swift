import Foundation

enum PathStep: Hashable, Sendable {
    case key(String), index(Int)
    var label: String { switch self { case .key(let k): k; case .index(let i): "[\(i)]" } }
}
struct PathBox: Hashable, Sendable { let path: [PathStep] }
func pathString(_ p: [PathStep]) -> String { p.isEmpty ? "/" : p.map(\.label).joined(separator: "/") }

enum PlistKind: String, CaseIterable, Identifiable, Sendable {
    case string, integer, real, bool, data, date, dict, array
    var id: String { rawValue }
    var title: String {
        switch self {
        case .string: "String"; case .integer: "Integer"; case .real: "Real"; case .bool: "Boolean"
        case .data: "Data"; case .date: "Date"; case .dict: "Dictionary"; case .array: "Array"
        }
    }
    var symbol: String {
        switch self {
        case .string: "textformat"; case .integer: "number"; case .real: "function"; case .bool: "switch.2"
        case .data: "externaldrive"; case .date: "calendar"; case .dict: "curlybraces"; case .array: "list.bullet"
        }
    }
}

indirect enum PlistValue: Equatable, Sendable {
    case string(String), integer(Int64), real(Double), bool(Bool), date(Date), data(Data)
    case array([PlistValue]), dict([String: PlistValue])

    var kind: PlistKind {
        switch self {
        case .string: .string; case .integer: .integer; case .real: .real; case .bool: .bool
        case .data: .data; case .date: .date; case .dict: .dict; case .array: .array
        }
    }
    var isContainer: Bool { kind == .dict || kind == .array }

    var summary: String {
        switch self {
        case .string(let s): s
        case .integer(let i): String(i)
        case .real(let d): String(d)
        case .bool(let b): b ? "true" : "false"
        case .date(let d): d.formatted(date: .abbreviated, time: .shortened)
        case .data(let d): "\(d.count) 字节"
        case .array(let a): "\(a.count) 项"
        case .dict(let d): "\(d.count) 项"
        }
    }

    init?(any: Any) {
        if let n = any as? NSNumber {
            if CFGetTypeID(n as CFTypeRef) == CFBooleanGetTypeID() { self = .bool(n.boolValue) }
            else if CFNumberIsFloatType(n) { self = .real(n.doubleValue) }
            else { self = .integer(n.int64Value) }
        } else if let s = any as? String { self = .string(s) }
        else if let d = any as? Data { self = .data(d) }
        else if let d = any as? Date { self = .date(d) }
        else if let a = any as? [Any] {
            var out: [PlistValue] = []
            for e in a { guard let v = PlistValue(any: e) else { return nil }; out.append(v) }
            self = .array(out)
        } else if let d = any as? [String: Any] {
            var out: [String: PlistValue] = [:]
            for (k, e) in d { guard let v = PlistValue(any: e) else { return nil }; out[k] = v }
            self = .dict(out)
        } else { return nil }
    }

    var anyValue: Any {
        switch self {
        case .string(let s): return s
        case .integer(let i): return NSNumber(value: i)
        case .real(let d): return NSNumber(value: d)
        case .bool(let b): return NSNumber(value: b)
        case .date(let d): return d
        case .data(let d): return d
        case .array(let a): return a.map(\.anyValue)
        case .dict(let d): return d.mapValues(\.anyValue)
        }
    }

    func get(_ path: ArraySlice<PathStep>) -> PlistValue? {
        guard let step = path.first else { return self }
        switch (self, step) {
        case (.dict(let d), .key(let k)): return d[k]?.get(path.dropFirst())
        case (.array(let a), .index(let i)): return a.indices.contains(i) ? a[i].get(path.dropFirst()) : nil
        default: return nil
        }
    }

    /// 设置或删除（newValue == nil）指定路径的值；数组下标等于 count 时表示追加。
    mutating func set(_ path: ArraySlice<PathStep>, _ newValue: PlistValue?) -> Bool {
        guard let step = path.first else { return false }
        let rest = path.dropFirst()
        switch (self, step) {
        case (.dict(var d), .key(let k)):
            if rest.isEmpty {
                if let nv = newValue { d[k] = nv } else { d.removeValue(forKey: k) }
            } else {
                guard var child = d[k], child.set(rest, newValue) else { return false }
                d[k] = child
            }
            self = .dict(d); return true
        case (.array(var a), .index(let i)):
            if rest.isEmpty {
                if let nv = newValue {
                    if i == a.count { a.append(nv) } else if a.indices.contains(i) { a[i] = nv } else { return false }
                } else {
                    guard a.indices.contains(i) else { return false }
                    a.remove(at: i)
                }
            } else {
                guard a.indices.contains(i) else { return false }
                var child = a[i]
                guard child.set(rest, newValue) else { return false }
                a[i] = child
            }
            self = .array(a); return true
        default: return false
        }
    }

    /// 由文本构造指定类型的值（用于编辑器）。
    static func parse(kind: PlistKind, text: String, bool: Bool, date: Date) -> PlistValue? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .string: return .string(text)
        case .integer: return Int64(t).map { .integer($0) }
        case .real: return Double(t).map { .real($0) }
        case .bool: return .bool(bool)
        case .date: return .date(date)
        case .data: return Data(hexString: t).map { .data($0) }
        case .dict: return .dict([:])
        case .array: return .array([])
        }
    }
}

extension Data {
    init?(hexString: String) {
        let s = hexString.filter { !$0.isWhitespace && $0 != "<" && $0 != ">" }
        guard s.count % 2 == 0 else { return nil }
        var out = Data(capacity: s.count / 2)
        var idx = s.startIndex
        while idx < s.endIndex {
            let next = s.index(idx, offsetBy: 2)
            guard let b = UInt8(s[idx..<next], radix: 16) else { return nil }
            out.append(b); idx = next
        }
        self = out
    }
    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}
