import CryptoKit
import Foundation

public enum ContentClassifier {
    public static func kind(of string: String) -> ClipKind {
        if ColorValue(string) != nil { return .color }
        if url(in: string) != nil { return .link }
        return .text
    }

    public static func url(in string: String) -> URL? {
        let text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(where: \.isWhitespace) else { return nil }
        let lower = text.lowercased()

        if lower.hasPrefix("mailto:") {
            let address = lower.dropFirst("mailto:".count).split(separator: "?", maxSplits: 1).first.map(String.init) ?? ""
            let pieces = address.split(separator: "@", omittingEmptySubsequences: false)
            guard pieces.count == 2, !pieces[0].isEmpty, pieces[1].contains("."), !pieces[1].hasSuffix(".") else { return nil }
            return URL(string: text)
        }
        for scheme in ["http://", "https://", "ftp://"] where lower.hasPrefix(scheme) {
            guard let url = URL(string: text), let host = url.host(percentEncoded: false), !host.isEmpty else { return nil }
            return url
        }
        if lower.hasPrefix("www.") {
            guard let url = URL(string: "https://" + text), let host = url.host(percentEncoded: false) else { return nil }
            let labels = host.split(separator: ".", omittingEmptySubsequences: false)
            guard labels.count >= 3, labels.allSatisfy({ !$0.isEmpty }) else { return nil }
            return url
        }
        return nil
    }

    public static func looksLikeCode(_ string: String) -> Bool {
        let text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        let lines = text.split(whereSeparator: \.isNewline).map { String($0) }

        if isJSONShaped(text) || isMarkupShaped(text) { return true }

        var indented = 0
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if line.hasPrefix("\t") || line.hasPrefix("  ") { indented += 1 }
            if isShellLine(trimmed) || isCodeLine(trimmed) { return true }
        }
        if text.contains(" && ") || text.contains(" | ") || text.contains(" || ") || text.contains("=>") || text.contains("</") {
            return true
        }
        return lines.count >= 3 && indented >= 2
    }

    public static func contentHash(text: String) -> String {
        contentHash(data: Data(text.utf8))
    }

    public static func contentHash(data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func isJSONShaped(_ text: String) -> Bool {
        if text.hasPrefix("{"), text.hasSuffix("}") { return text.contains("\"") || text.contains(":") }
        if text.hasPrefix("["), text.hasSuffix("]") { return text.contains("\"") || text.contains("{") }
        return false
    }

    private static func isMarkupShaped(_ text: String) -> Bool {
        guard text.hasPrefix("<"), text.hasSuffix(">") else { return false }
        return text.hasPrefix("<?xml") || text.hasPrefix("<!") || text.contains("</") || text.hasSuffix("/>")
    }

    private static let shellPrefixes = [
        "$ ", "git ", "swift ", "npm ", "curl ", "brew ", "sudo ", "pip ", "pip3 ", "docker ",
        "cargo ", "yarn ", "pnpm ", "xcodebuild ", "cd ", "ls ", "mkdir ", "chmod ", "ssh ",
    ]

    private static func isShellLine(_ line: String) -> Bool {
        shellPrefixes.contains { line.hasPrefix($0) }
    }

    private static let keywords: Set<String> = [
        "func", "let", "var", "const", "import", "def", "class", "struct", "enum", "protocol", "extension",
        "public", "private", "static", "return", "if", "else", "for", "while", "switch", "case", "guard",
        "fn", "pub", "package", "#include", "#import", "from",
    ]

    private static func isCodeLine(_ line: String) -> Bool {
        if line.hasSuffix("{") || line.hasSuffix(";") || line == "}" || line.hasSuffix("};") { return true }
        if line.hasPrefix("//") || line.hasPrefix("/*") { return true }
        let first = line.prefix { !$0.isWhitespace && $0 != "(" && $0 != "{" }
        if keywords.contains(String(first)) {
            if ["import", "package", "#include", "#import"].contains(first),
               line.dropFirst(first.count).split(whereSeparator: \.isWhitespace).count == 1 { return true }
            if first == "from" { return line.contains(" import ") }
            return line.contains(where: { "{}()=;<>".contains($0) }) || line.hasSuffix(":")
        }
        return false
    }
}
