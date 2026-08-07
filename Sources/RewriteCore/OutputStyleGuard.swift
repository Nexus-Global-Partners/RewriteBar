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
            let escapedPhrase = NSRegularExpression.escapedPattern(for: phrase)
            let pattern = #"(?<![\p{L}\p{N}])"#
                + escapedPhrase
                + #"(?![\p{L}\p{N}])"#
            guard let expression = try? NSRegularExpression(
                pattern: pattern,
                options: .caseInsensitive
            ) else {
                return result
            }
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            return expression.stringByReplacingMatches(
                in: result,
                range: range,
                withTemplate: directWording
            )
        }
    }

    public static func replacingOfficeFiller(
        in output: String,
        source: String,
        intensity: Int
    ) -> String {
        guard RewriteIntensityPolicy.clampedLevel(intensity) > 0 else {
            return output
        }
        return replacingOfficeFiller(in: output, source: source)
    }

    public static func restoringUncertaintyStrength(
        in output: String,
        source: String
    ) -> String {
        let protectedPhrases = [
            "not totally sure",
            "not entirely sure",
            "not completely sure"
        ]
        let weakerAlternatives = [
            "not sure",
            "unsure"
        ]
        var result = output

        for protectedPhrase in protectedPhrases {
            guard let sourceRange = source.range(
                of: protectedPhrase,
                options: .caseInsensitive
            ), result.range(
                of: protectedPhrase,
                options: .caseInsensitive
            ) == nil else {
                continue
            }

            let exactSourcePhrase = String(source[sourceRange])
            for alternative in weakerAlternatives {
                guard let outputRange = result.range(
                    of: alternative,
                    options: .caseInsensitive
                ) else {
                    continue
                }
                result.replaceSubrange(outputRange, with: exactSourcePhrase)
                break
            }
        }
        return result
    }

    public static func restoringCommitmentStrength(
        in output: String,
        source: String
    ) -> String {
        let sourceExpression = try! NSRegularExpression(
            pattern: #"\b(can|could|may|might|should)\s+([\p{L}]+)\b"#,
            options: .caseInsensitive
        )
        let sourceRange = NSRange(source.startIndex..<source.endIndex, in: source)
        var result = output

        for match in sourceExpression.matches(in: source, range: sourceRange) {
            guard let modalRange = Range(match.range(at: 1), in: source),
                  let verbRange = Range(match.range(at: 2), in: source) else {
                continue
            }
            let modal = String(source[modalRange])
            let verb = String(source[verbRange])
            let escapedVerb = NSRegularExpression.escapedPattern(for: verb)
            let strengthenedPatterns = [
                #"\b(?:will|must)\s+\#(escapedVerb)\b"#,
                #"\b(I|you|we|they|he|she|it)['’]ll\s+\#(escapedVerb)\b"#
            ]

            for (index, pattern) in strengthenedPatterns.enumerated() {
                guard let expression = try? NSRegularExpression(
                    pattern: pattern,
                    options: .caseInsensitive
                ) else {
                    continue
                }
                let outputRange = NSRange(
                    result.startIndex..<result.endIndex,
                    in: result
                )
                guard let strengthened = expression.firstMatch(
                    in: result,
                    range: outputRange
                ), let fullRange = Range(strengthened.range, in: result) else {
                    continue
                }

                if index == 0 {
                    result.replaceSubrange(fullRange, with: "\(modal) \(verb)")
                } else if let subjectRange = Range(
                    strengthened.range(at: 1),
                    in: result
                ) {
                    let subject = String(result[subjectRange])
                    result.replaceSubrange(
                        fullRange,
                        with: "\(subject) \(modal.lowercased()) \(verb)"
                    )
                }
                break
            }
        }
        return result
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
