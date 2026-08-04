import AppKit
import Foundation

public enum ClipboardTextNormalizer {
    public static func normalize(_ text: String) -> String {
        guard looksLikeFullHTMLDocument(text),
              let data = text.data(using: .utf8),
              let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else {
            return text
        }

        let visibleText = attributed.string
            .replacingOccurrences(of: "\u{FFFC}", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: " ")

        return cleanExtractedText(visibleText)
    }

    private static func looksLikeFullHTMLDocument(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = htmlTagExpression.matches(in: text, range: range)

        guard matches.count >= 8 else { return false }

        let markupCharacters = matches.reduce(0) { $0 + $1.range.length }
        let markupRatio = Double(markupCharacters) / Double(max(1, text.utf16.count))
        return markupRatio >= 0.10
    }

    private static func cleanExtractedText(_ text: String) -> String {
        let normalizedNewlines = text.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalizedNewlines.components(separatedBy: "\n")
        var result: [String] = []
        var previousLineWasEmpty = false

        for line in lines {
            let cleanedLine = line.trimmingCharacters(in: .whitespaces)
            let isEmpty = cleanedLine.isEmpty
            if isEmpty, previousLineWasEmpty {
                continue
            }
            result.append(cleanedLine)
            previousLineWasEmpty = isEmpty
        }

        return result.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let htmlTagExpression = try! NSRegularExpression(
        pattern: #"<\/?(?:html|head|body|style|table|tbody|thead|tfoot|tr|td|th|div|p|span|a|img|br|h[1-6]|ul|ol|li|section|article|footer|header)\b[^>]*>"#,
        options: [.caseInsensitive]
    )
}
