import Foundation

public enum OutputStyleGuard {
    private static let officeFillerReplacements = [
        ("touch base", "check in"),
        ("circle back", "return to this"),
        ("reach out", "contact"),
        ("moving forward", "from now on"),
        ("going forward", "from now on"),
        ("align on", "agree on"),
        ("leverage", "use"),
        ("bandwidth", "time"),
        ("folks", "people")
    ]

    private static let genericPrefixes = [
        "What stands out is that ",
        "The key point is that ",
        "The most important point is that ",
        "Here is the updated announcement:",
        "Here’s the updated announcement:",
        "Here's the updated announcement:",
        "Here is the revised announcement:",
        "Here’s the revised announcement:",
        "Here's the revised announcement:"
    ]

    public static func removingIntroducedFraming(
        from output: String,
        source: String
    ) -> String {
        for prefix in genericPrefixes {
            guard output.range(
                of: prefix,
                options: [.anchored, .caseInsensitive]
            ) != nil else {
                continue
            }
            guard source.range(
                of: prefix,
                options: [.anchored, .caseInsensitive]
            ) == nil else {
                return output
            }

            let remainder = output.dropFirst(prefix.count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let first = remainder.first else { return output }
            return first.uppercased() + remainder.dropFirst()
        }
        return output
    }

    public static func replacingOfficeFiller(
        in output: String,
        source: String
    ) -> String {
        officeFillerReplacements.reduce(output) { result, replacement in
            let (phrase, directWording) = replacement
            guard !sourceContainsQuotedOccurrence(of: phrase, source: source) else {
                return result
            }
            return result.replacingOccurrences(
                of: phrase,
                with: directWording,
                options: .caseInsensitive
            )
        }
    }

    private static func sourceContainsQuotedOccurrence(
        of phrase: String,
        source: String
    ) -> Bool {
        let escapedPhrase = NSRegularExpression.escapedPattern(for: phrase)
        let pattern = "[\\\"“][^\\\"”\\n]*\\b\(escapedPhrase)\\b[^\\\"”\\n]*[\\\"”]"
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: .caseInsensitive
        ) else {
            return false
        }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return expression.firstMatch(in: source, range: range) != nil
    }
}
