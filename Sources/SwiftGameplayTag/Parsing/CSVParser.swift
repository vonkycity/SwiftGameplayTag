import Foundation

/// 教学用 CSV 解析器:支持双引号包裹、双引号转义、CRLF。
enum CSVParser {
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false

        // 用 unicodeScalars 迭代,这样 \r 和 \n 是两个独立标量,
        // 不会被 String 当成单个 grapheme cluster。
        let scalars = Array(text.unicodeScalars)
        var i = 0
        while i < scalars.count {
            let s = scalars[i]
            // 跳过 BOM
            if i == 0 && s.value == 0xFEFF { i += 1; continue }

            if inQuotes {
                if s == "\"" {
                    let next = i + 1
                    if next < scalars.count, scalars[next] == "\"" {
                        field.append("\"")
                        i = next + 1
                        continue
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.unicodeScalars.append(s)
                }
            } else {
                switch s {
                case "\"":
                    inQuotes = true
                case ",":
                    row.append(field)
                    field = ""
                case "\r":
                    break
                case "\n":
                    row.append(field)
                    rows.append(row)
                    row = []
                    field = ""
                default:
                    field.unicodeScalars.append(s)
                }
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    /// 按 RFC 4180 转义一个字段。
    static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }
}
