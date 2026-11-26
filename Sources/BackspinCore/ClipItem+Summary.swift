import Foundation

extension ClipItem {
    public var summary: String {
        guard let text else { return "" }
        if kind == .file {
            return fileURLs.first?.lastPathComponent ?? ""
        }
        for line in text.split(whereSeparator: \.isNewline) {
            let collapsed = line.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            if !collapsed.isEmpty { return String(collapsed.prefix(200)) }
        }
        return ""
    }

    public var fileURLs: [URL] {
        guard kind == .file, let text else { return [] }
        return text.split(whereSeparator: \.isNewline).compactMap { line in
            let path = line.trimmingCharacters(in: .whitespaces)
            guard !path.isEmpty else { return nil }
            if path.hasPrefix("file://"), let url = URL(string: path) { return url }
            return URL(fileURLWithPath: path)
        }
    }
}
