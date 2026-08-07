import Foundation

public enum OutputSanitizer {
    public static func sanitize(_ output: String) throws -> String {
        var value = output.trimmingCharacters(in: .whitespacesAndNewlines)
        value = removingThinkingBlock(from: value)
        value = removingKnownPreamble(from: value)
        value = removingWrappingQuotes(from: value)
        value = removingDashCharacters(from: value)
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !value.isEmpty else {
            throw RewriteError.emptyOutput
        }

        return value
    }

    public static func sanitizeSourceFallback(_ source: String) throws -> String {
        let value = removingDashCharacters(from: source)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw RewriteError.emptyOutput
        }
        return value
    }

    private static func removingDashCharacters(from value: String) -> String {
        let dashClass = "[‐‑‒–—―−-]"
        var result = value.replacingOccurrences(
            of: "(?m)^[ \\t]*\(dashClass)+[ \\t]+",
            with: "• ",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "[ \\t]*\(dashClass)+[ \\t]*",
            with: " ",
            options: .regularExpression
        )
        return result
    }

    private static func removingThinkingBlock(from value: String) -> String {
        guard let start = value.range(of: "<think>", options: .caseInsensitive),
              let end = value.range(
                of: "</think>",
                options: .caseInsensitive,
                range: start.upperBound..<value.endIndex
              ) else {
            return value
        }

        var result = value
        result.removeSubrange(start.lowerBound..<end.upperBound)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func removingKnownPreamble(from value: String) -> String {
        let preambles = [
            "Rewritten text:",
            "Rewritten version:",
            "Here is the rewritten text:",
            "Here’s the rewritten text:",
            "Here's the rewritten text:",
            "Translation:",
            "Translated text:",
            "Here is the translation:",
            "Here’s the translation:",
            "Here's the translation:"
        ]

        for preamble in preambles {
            if value.range(
                of: preamble,
                options: [.anchored, .caseInsensitive, .diacriticInsensitive]
            ) != nil {
                return String(value.dropFirst(preamble.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return value
    }

    private static func removingWrappingQuotes(from value: String) -> String {
        let quotePairs: [(Character, Character)] = [
            ("\"", "\""), ("“", "”"), ("‘", "’")
        ]

        guard value.count >= 2,
              let first = value.first,
              let last = value.last,
              quotePairs.contains(where: { $0.0 == first && $0.1 == last }) else {
            return value
        }

        return String(value.dropFirst().dropLast())
    }
}
