import Foundation

public struct ProtectedSource: Sendable {
    public let text: String
    private let replacements: [String: String]
    private let fallbackLineIndices: [String: Int]

    fileprivate init(
        text: String,
        replacements: [String: String],
        fallbackLineIndices: [String: Int]
    ) {
        self.text = text
        self.replacements = replacements
        self.fallbackLineIndices = fallbackLineIndices
    }

    public var containsProtectedContent: Bool {
        !replacements.isEmpty
    }

    public var placeholderTokens: [String] {
        replacements.keys.sorted()
    }

    public func restoringProtectedContent(in candidate: String) -> String? {
        var result = candidate
        var missingTokens: [String] = []

        for replacement in replacements {
            if result.contains(replacement.key) {
                result = result.replacingOccurrences(
                    of: replacement.key,
                    with: replacement.value
                )
            } else if !result.contains(replacement.value) {
                missingTokens.append(replacement.key)
            }
        }

        guard !missingTokens.isEmpty else { return result }

        var lines = result.components(separatedBy: "\n")
        for token in missingTokens.sorted(by: {
            fallbackLineIndices[$0, default: 0]
                < fallbackLineIndices[$1, default: 0]
        }) {
            guard let sourceLine = replacements[token] else { continue }
            let sourceIndex = fallbackLineIndices[token, default: lines.count]
            lines.insert(sourceLine, at: min(sourceIndex, lines.count))
        }
        return lines.joined(separator: "\n")
    }
}

public enum SourceInstructionProtector {
    private static let patterns: [NSRegularExpression] = [
        try! NSRegularExpression(
            pattern: #"\bignore\s+(?:all\s+)?(?:previous|prior|above)\s+(?:instructions|directions|rules)\b"#,
            options: .caseInsensitive
        ),
        try! NSRegularExpression(
            pattern: #"\b(?:system|developer)\s+(?:prompt|message|instructions)\b"#,
            options: .caseInsensitive
        ),
        try! NSRegularExpression(
            pattern: #"\bdo\s+not\s+follow\b.*\b(?:instructions|rules)\b"#,
            options: .caseInsensitive
        ),
        try! NSRegularExpression(
            pattern: #"\b(?:reveal|print|repeat|show)\b.*\b(?:system|developer)\s+(?:prompt|message|instructions)\b"#,
            options: .caseInsensitive
        )
    ]

    public static func protect(
        _ source: String,
        enabled: Bool = true
    ) -> ProtectedSource {
        guard enabled else {
            return ProtectedSource(
                text: source,
                replacements: [:],
                fallbackLineIndices: [:]
            )
        }

        var replacements: [String: String] = [:]
        var fallbackLineIndices: [String: Int] = [:]
        let protectedLines = source.components(separatedBy: "\n").enumerated().map {
            lineIndex, line in
            guard isInstructionLike(line) else { return line }
            let token = "ZXQSOURCE\(replacements.count + 1)QXZ"
            replacements[token] = line
            fallbackLineIndices[token] = lineIndex
            return token
        }

        return ProtectedSource(
            text: protectedLines.joined(separator: "\n"),
            replacements: replacements,
            fallbackLineIndices: fallbackLineIndices
        )
    }

    private static func isInstructionLike(_ value: String) -> Bool {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return patterns.contains { expression in
            expression.firstMatch(in: value, range: range) != nil
        }
    }
}
