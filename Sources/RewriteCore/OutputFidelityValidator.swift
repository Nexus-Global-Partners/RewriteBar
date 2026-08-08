import Foundation

public struct OutputFidelityReport: Equatable, Sendable {
    public let missingFacts: [String]
    public let missingQuotedPassages: [String]
    public let changedModality: [String]
    public let strengthenedCommitment: Bool
    public let introducedCausality: [String]

    public var preservesCriticalFacts: Bool {
        missingFacts.isEmpty && missingQuotedPassages.isEmpty
    }

    public var preservesMeaningSignals: Bool {
        preservesCriticalFacts
            && !strengthenedCommitment
            && introducedCausality.isEmpty
    }
}

public enum OutputFidelityValidator {
    private static let factExpression = try! NSRegularExpression(
        pattern: #"(?i)(?:[€$£¥]\s*\d+(?:[.,]\d+)*)|(?:\bQ[1-4]\b)|(?:(?<![\p{L}\p{N}])\d+(?:[.,:]\d+)*(?:\s+to\s+\d+(?:[.,:]\d+)*)?(?:\s*(?:%|am|pm|ms|sec|seconds?|minutes?|hours?|days?|weeks?|months?|years?|gb|mb|kb|usd|eur))?(?![\p{L}\p{N}]))"#
    )
    private static let quoteExpression = try! NSRegularExpression(
        pattern: #"(?:“[^”\n]+”)|(?:\"[^\"\n]+\")"#
    )
    private static let modalTerms = [
        "cannot", "could not", "would not", "should not", "will not",
        "must not", "may not", "might not", "can", "could", "would",
        "should", "will", "must", "may", "might"
    ]
    private static let strongCausalityExpressions: [NSRegularExpression] = [
        try! NSRegularExpression(
            pattern: #"\b(?:cause|caused|causes|causing)\b"#,
            options: .caseInsensitive
        ),
        try! NSRegularExpression(
            pattern: #"\b(?:resulted|resulting)\s+in\b"#,
            options: .caseInsensitive
        ),
        try! NSRegularExpression(
            pattern: #"\b(?:led|leads|leading)\s+to\b"#,
            options: .caseInsensitive
        ),
        try! NSRegularExpression(
            pattern: #"\bdue\s+to\b"#,
            options: .caseInsensitive
        ),
        try! NSRegularExpression(
            pattern: #"\bbecause\b"#,
            options: .caseInsensitive
        )
    ]

    public static func evaluate(source: String, output: String) -> OutputFidelityReport {
        let normalizedOutput = normalizedForComparison(output)
        let missingFacts = uniqueMatches(of: factExpression, in: source).filter {
            !normalizedOutput.contains(normalizedForComparison($0))
        }
        let missingQuotes = uniqueMatches(of: quoteExpression, in: source).filter {
            !normalizedOutput.contains(normalizedForComparison($0))
        }

        let sourceModality = modalityProfile(in: source)
        let outputModality = modalityProfile(in: output)
        let changedModality = modalTerms.filter {
            sourceModality[$0, default: 0] != outputModality[$0, default: 0]
        }
        let sourceCausalityCount = strongCausalityExpressions.reduce(0) {
            $0 + matchCount(of: $1, in: source)
        }
        let outputCausalityCount = strongCausalityExpressions.reduce(0) {
            $0 + matchCount(of: $1, in: output)
        }
        let introducedCausality = outputCausalityCount > sourceCausalityCount
            ? ["strong causal link"]
            : []

        return OutputFidelityReport(
            missingFacts: missingFacts,
            missingQuotedPassages: missingQuotes,
            changedModality: changedModality,
            strengthenedCommitment: containsStrengthenedCommitment(
                source: source,
                output: output
            ),
            introducedCausality: introducedCausality
        )
    }

    public static func modalityProfile(in value: String) -> [String: Int] {
        modalityCounts(in: value).filter { $0.value > 0 }
    }

    private static func uniqueMatches(
        of expression: NSRegularExpression,
        in value: String
    ) -> [String] {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        var seen: Set<String> = []
        return expression.matches(in: value, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: value) else {
                return nil
            }
            let result = String(value[matchRange])
            guard seen.insert(normalizedForComparison(result)).inserted else {
                return nil
            }
            return result
        }
    }

    private static func matchCount(
        of expression: NSRegularExpression,
        in value: String
    ) -> Int {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.numberOfMatches(in: value, range: range)
    }

    private static func modalityCounts(in value: String) -> [String: Int] {
        let normalized = expandingContractions(in: value)
        var counts: [String: Int] = [:]
        var remaining = normalized
        for term in modalTerms {
            let pattern = #"(?<![\p{L}\p{N}])"#
                + NSRegularExpression.escapedPattern(for: term)
                + #"(?![\p{L}\p{N}])"#
            guard let expression = try? NSRegularExpression(pattern: pattern) else {
                continue
            }
            let range = NSRange(remaining.startIndex..<remaining.endIndex, in: remaining)
            let matches = expression.matches(in: remaining, range: range)
            counts[term] = matches.count
            for match in matches.reversed() {
                guard let matchRange = Range(match.range, in: remaining) else {
                    continue
                }
                remaining.replaceSubrange(
                    matchRange,
                    with: String(repeating: " ", count: remaining[matchRange].count)
                )
            }
        }
        return counts
    }

    private static func containsStrengthenedCommitment(
        source: String,
        output: String
    ) -> Bool {
        let normalizedSource = expandingContractions(in: source)
        let normalizedOutput = expandingContractions(in: output)
        guard let sourceExpression = try? NSRegularExpression(
            pattern: #"\b(?:can|could|may|might|should)\s+([\p{L}]+)\b"#,
            options: .caseInsensitive
        ) else {
            return false
        }
        let sourceRange = NSRange(
            normalizedSource.startIndex..<normalizedSource.endIndex,
            in: normalizedSource
        )

        return sourceExpression.matches(
            in: normalizedSource,
            range: sourceRange
        ).contains { match in
            guard let verbRange = Range(match.range(at: 1), in: normalizedSource) else {
                return false
            }
            let verb = normalizedSource[verbRange]
            let pattern = #"\b(?:will|must)\s+"#
                + NSRegularExpression.escapedPattern(for: String(verb))
                + #"\b"#
            guard let expression = try? NSRegularExpression(
                pattern: pattern,
                options: .caseInsensitive
            ) else {
                return false
            }
            let outputRange = NSRange(
                normalizedOutput.startIndex..<normalizedOutput.endIndex,
                in: normalizedOutput
            )
            return expression.firstMatch(
                in: normalizedOutput,
                range: outputRange
            ) != nil
        }
    }

    private static func expandingContractions(in value: String) -> String {
        var normalized = value.lowercased()
        let missingApostrophes = [
            "cant": "cannot", "couldnt": "could not",
            "wouldnt": "would not", "shouldnt": "should not",
            "wont": "will not", "mustnt": "must not",
            "itll": "it will"
        ]
        for (contraction, expanded) in missingApostrophes {
            normalized = normalized.replacingOccurrences(
                of: #"\b"# + contraction + #"\b"#,
                with: expanded,
                options: .regularExpression
            )
        }
        let contractions = [
            "can't": "cannot",
            "can’t": "cannot",
            "couldn't": "could not",
            "couldn’t": "could not",
            "wouldn't": "would not",
            "wouldn’t": "would not",
            "shouldn't": "should not",
            "shouldn’t": "should not",
            "won't": "will not",
            "won’t": "will not",
            "mustn't": "must not",
            "mustn’t": "must not",
            "mightn't": "might not",
            "mightn’t": "might not",
            "i'll": "i will",
            "i’ll": "i will",
            "you'll": "you will",
            "you’ll": "you will",
            "we'll": "we will",
            "we’ll": "we will",
            "they'll": "they will",
            "they’ll": "they will",
            "it'll": "it will",
            "it’ll": "it will",
            "i'd": "i would",
            "i’d": "i would",
            "you'd": "you would",
            "you’d": "you would",
            "we'd": "we would",
            "we’d": "we would",
            "they'd": "they would",
            "they’d": "they would"
        ]
        for (contraction, expanded) in contractions {
            normalized = normalized.replacingOccurrences(of: contraction, with: expanded)
        }
        return normalized
    }

    private static func normalizedForComparison(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(
                of: "[‐‑‒–—―−-]",
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
