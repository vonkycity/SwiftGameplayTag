import Foundation

/// GameplayTag 文件格式。
enum TagFileFormat: String, CaseIterable {
    /// UE5 DataTable CSV 格式(`Name,Tag,DevComment`),
    /// 可直接 Import 到 UE Content Browser 当 `GameplayTagTableRow`。
    case dataTableCSV
    /// UE5 ini 配置文件。
    case ini

    var displayName: String {
        switch self {
        case .dataTableCSV: return "UE5 DataTable CSV"
        case .ini:          return "UE5 ini (Config/Tags)"
        }
    }

    var fileExtension: String {
        switch self {
        case .dataTableCSV: return "csv"
        case .ini:          return "ini"
        }
    }
}

/// CSV / ini ↔ GameplayTag 互转。
enum CSVBridge {

    // MARK: - 出口:序列化

    /// 把一棵树序列化为指定格式的文本。
    static func export(_ nodes: [GameplayTagNode], format: TagFileFormat) -> String {
        switch format {
        case .dataTableCSV: return dataTableCSV(nodes)
        case .ini:          return ini(nodes)
        }
    }

    /// UE5 DataTable CSV。
    /// 格式:
    /// ```
    /// Name,Tag,DevComment
    /// 0,Combat.Damage.Burning,燃烧
    /// 1,Status.Burning,燃烧状态
    /// ```
    static func dataTableCSV(_ nodes: [GameplayTagNode]) -> String {
        var lines: [String] = ["Name,Tag,DevComment"]
        var rowIndex = 0
        func walk(_ list: [GameplayTagNode]) {
            for n in list {
                let t = n.tag
                lines.append([
                    String(rowIndex),
                    CSVParser.escape(t.name),
                    CSVParser.escape(t.devComment)
                ].joined(separator: ","))
                rowIndex += 1
                walk(n.children)
            }
        }
        walk(nodes)
        return lines.joined(separator: "\n") + "\n"
    }

    /// UE5 ini 配置文件。放到 `Config/Tags/<name>.ini` 即可被 UE 加载。
    static func ini(_ nodes: [GameplayTagNode]) -> String {
        var lines: [String] = ["[/Script/GameplayTags.GameplayTagsList]"]
        func walk(_ list: [GameplayTagNode]) {
            for n in list {
                let t = n.tag
                lines.append(
                    "GameplayTagList=(Tag=\"\(escapeIni(t.name))\"" +
                    ",DevComment=\"\(escapeIni(t.devComment))\")"
                )
                walk(n.children)
            }
        }
        walk(nodes)
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - 入口:反序列化

    /// 自动检测格式并解析。返回的格式标识可用于「原始文件」面板展示。
    static func parse(_ text: String) -> (tags: [GameplayTag], format: TagFileFormat) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("[/Script/GameplayTags") {
            return (parseINI(text), .ini)
        }
        let rows = CSVParser.parse(text)
        guard let header = rows.first, !header.isEmpty else {
            return ([], .dataTableCSV)
        }
        return (parseDataTableCSV(rows, header: header), .dataTableCSV)
    }

    /// 解析 UE5 DataTable CSV(兼容旧版表头与 `Name` 列写法)。
    static func parseDataTableCSV(_ rows: [[String]], header: [String]) -> [GameplayTag] {
        let lower = header.map { $0.lowercased() }
        let tagIdx = lower.firstIndex { $0 == "tag" }
            ?? lower.firstIndex { $0 == "name" }
            ?? 1
        let devIdx = lower.firstIndex { $0 == "devcomment" }
            ?? lower.firstIndex { $0.contains("dev") && $0.contains("comment") }

        var out: [GameplayTag] = []
        for row in rows.dropFirst() {
            if row.allSatisfy({ $0.isEmpty }) { continue }
            let name = row.indices.contains(tagIdx) ? row[tagIdx].trimmingCharacters(in: .whitespaces) : ""
            if name.isEmpty { continue }
            let dev = (devIdx.flatMap { row.indices.contains($0) ? row[$0] : nil }) ?? ""
            out.append(GameplayTag(name: name, devComment: dev))
        }
        return out
    }

    /// 解析 UE5 ini 配置文件。
    /// 同时支持 `GameplayTagList=(...)` 和 `+GameplayTagList=(...)` 两种写法。
    static func parseINI(_ text: String) -> [GameplayTag] {
        var out: [GameplayTag] = []
        let pattern = #"[+]?GameplayTagList\s*=\s*\((.*?)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        for m in matches {
            guard m.numberOfRanges > 1 else { continue }
            let inner = nsText.substring(with: m.range(at: 1))
            let kv = parseKeyValues(inner)
            let name = kv["Tag"] ?? ""
            if name.isEmpty { continue }
            out.append(GameplayTag(
                name: name,
                devComment: kv["DevComment"] ?? ""
            ))
        }
        return out
    }

    // MARK: - ini 工具

    private static func escapeIni(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func unescapeIni(_ s: String) -> String {
        var out = ""
        var iter = s.unicodeScalars.makeIterator()
        var prev: Unicode.Scalar?
        while let cur = iter.next() {
            if prev == "\\" {
                switch cur {
                case "\\": out.append("\\")
                case "\"": out.append("\"")
                case "n":  out.append("\n")
                case "t":  out.append("\t")
                default:   out.unicodeScalars.append(cur)
                }
                prev = nil
            } else if cur == "\\" {
                prev = cur
            } else {
                out.unicodeScalars.append(cur)
                prev = nil
            }
        }
        if let p = prev { out.unicodeScalars.append(p) }
        return out
    }

    /// 解析 `Tag="X",DevComment="Y"` 这样的键值对,value 已经反转义。
    private static func parseKeyValues(_ s: String) -> [String: String] {
        var result: [String: String] = [:]
        var i = s.startIndex
        while i < s.endIndex {
            while i < s.endIndex, ", \t\n\r".contains(s[i]) { i = s.index(after: i) }
            guard i < s.endIndex else { break }
            let keyStart = i
            while i < s.endIndex, s[i] != "=" { i = s.index(after: i) }
            let key = s[keyStart..<i].trimmingCharacters(in: .whitespaces)
            guard i < s.endIndex, s[i] == "=" else { break }
            i = s.index(after: i)
            while i < s.endIndex, s[i] == " " || s[i] == "\t" { i = s.index(after: i) }
            guard i < s.endIndex, s[i] == "\"" else { break }
            i = s.index(after: i)
            var value = ""
            while i < s.endIndex {
                let c = s[i]
                if c == "\\" {
                    let next = s.index(after: i)
                    guard next < s.endIndex else { break }
                    switch s[next] {
                    case "\\": value.append("\\")
                    case "\"": value.append("\"")
                    case "n":  value.append("\n")
                    case "t":  value.append("\t")
                    default:   value.append(s[next])
                    }
                    i = s.index(after: next)
                } else if c == "\"" {
                    break
                } else {
                    value.append(c)
                    i = s.index(after: i)
                }
            }
            guard i < s.endIndex, s[i] == "\"" else { break }
            i = s.index(after: i)
            result[key] = value
        }
        return result
    }
}
