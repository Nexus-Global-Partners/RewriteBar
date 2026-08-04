import Foundation

public struct ProtectedSource: Sendable {
    public let text: String
    private let replacements: [String: String]

    fileprivate init(text: String, replacements: [String: String]) {
        self.text = text
        self.replacements = replacements
    }

    public var containsProtectedContent: Bool {
        !replacements.isEmpty
    }

    public var placeholderTokens: [String] {
        replacements.keys.sorted()
    }

    public func restoringProtectedContent(in candidate: String) -> String? {
        guard replacements.keys.allSatisfy(candidate.contains) else {
            return nil
        }

        return replacements.reduce(candidate) { value, replacement in
            value.replacingOccurrences(of: replacement.key, with: replacement.value)
        }
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

    public static func protect(_ source: String) -> ProtectedSource {
        var replacements: [String: String] = [:]
        let protectedLines = source.components(separatedBy: "\n").map { line in
            guard isInstructionLike(line) else { return line }
            let token = "<PROTECTED_SOURCE_\(replacements.count + 1)>"
            replacements[token] = line
            return token
        }

        return ProtectedSource(
            text: protectedLines.joined(separator: "\n"),
            replacements: replacements
        )
    }

    private static func isInstructionLike(_ value: String) -> Bool {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return patterns.contains { expression in
            expression.firstMatch(in: value, range: range) != nil
        }
    }
}
