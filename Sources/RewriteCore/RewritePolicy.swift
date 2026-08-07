import Foundation

public enum RewriteStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case rewriteBar
    case clear
    case professional
    case conversational
    case persuasive

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .rewriteBar:
            "RewriteBar"
        case .clear:
            "Clear"
        case .professional:
            "Professional"
        case .conversational:
            "Conversational"
        case .persuasive:
            "Persuasive"
        }
    }

    public var explanation: String {
        switch self {
        case .rewriteBar:
            "Balanced improvements that preserve your natural voice."
        case .clear:
            "Clearer structure and wording at approximately the same length."
        case .professional:
            "Precise, composed writing without corporate jargon."
        case .conversational:
            "Natural human phrasing that remains true to your tone."
        case .persuasive:
            "Stronger reasoning without invented urgency, claims, or certainty."
        }
    }

    public var promptInstruction: String {
        switch self {
        case .rewriteBar:
            "Use the balanced RewriteBar style. Improve clarity, flow, and naturalness without imposing a new voice or level of formality."
        case .clear:
            "Add a subtle emphasis on clarity. Improve sentence order and remove ambiguity while preserving the author's voice, tone, truth, intent, details, and approximate length."
        case .professional:
            "Add a subtle emphasis on precision and composure. Preserve the author's existing formality, voice, tone, truth, intent, details, and approximate length. Never introduce corporate jargon, office filler, or inflated language."
        case .conversational:
            "Add a subtle emphasis on natural human rhythm and familiar wording. Preserve the author's existing formality, personality, tone, truth, intent, details, and approximate length rather than forcing casual language."
        case .persuasive:
            "Add a subtle emphasis on the strength and order of reasoning already present. Preserve the author's voice, tone, truth, intent, uncertainty, details, and approximate length. Never invent urgency, evidence, benefits, claims, conclusions, or certainty."
        }
    }
}

public enum RewriteIntensityPolicy {
    public static let definitions: [String] = [
        "Proofread only: Fix obvious spelling, grammar, and punctuation errors. Preserve the original wording and structure.",
        "Minimal correction: Make essential corrections and very small wording changes for clarity.",
        "Light polish: Improve grammar, flow, and readability while staying very close to the original.",
        "Gentle rewrite: Rephrase awkward sentences and improve structure without changing the tone or meaning.",
        "Moderate polish: Rewrite unclear or repetitive parts and make the text smoother and more natural.",
        "Balanced rewrite: Freely improve wording, flow, and organization while fully preserving the core message.",
        "Strong rewrite: Restructure sentences and paragraphs where needed, with noticeable improvements in clarity and style.",
        "Substantial rewrite: Rework most of the text for stronger impact, consistency, and readability while keeping the original intent.",
        "Creative rewrite: Use significant freedom in wording, tone, and structure while preserving the main ideas.",
        "Near-complete rewrite: Rebuild the text almost entirely, keeping only the essential message and key details.",
        "Full transformation: Create the strongest possible version from the original idea, with maximum freedom in style, structure, and expression."
    ]

    public static func clampedLevel(_ intensity: Int) -> Int {
        min(10, max(0, intensity))
    }

    public static func definition(for intensity: Int) -> String {
        definitions[clampedLevel(intensity)]
    }

    public static func operationalGuidance(for intensity: Int) -> String {
        switch clampedLevel(intensity) {
        case 0:
            "Change only clear spelling, grammar, or punctuation errors. If wording and structure are already correct, copy them unchanged."
        case 1:
            "Keep nearly all original wording and sentence order. Make only essential corrections and isolated clarity edits."
        case 2:
            "Keep the original sentence shapes and most wording. Smooth grammar and flow with restrained phrase level edits."
        case 3:
            "Rephrase sentences that are awkward or unclear, but leave effective sentences close to their original form."
        case 4:
            "Rewrite unclear or repetitive passages and improve transitions. Keep the overall structure recognizable."
        case 5:
            "Improve the whole draft, not only its errors. Rework wording and sentence order wherever that creates a clearly better result."
        case 6:
            "Make noticeable changes throughout. Restructure sentences and the internal organization of paragraphs where useful."
        case 7:
            "Recompose most sentences with new construction and stronger flow. At least half of the sentences should use a clearly new sentence shape. The result must be visibly different while unmistakably preserving the author and message."
        case 8:
            "Use substantially new wording and sentence construction across the text. Nearly every sentence should be newly composed. Reorganize the presentation when useful while preserving the author's tone and every source detail."
        case 9:
            "Rebuild the draft from its essential points rather than polishing it sentence by sentence. Open with a different part of the message, choose a new presentation sequence, and give every sentence a newly composed structure. Do not retain source sentence openings or chains of familiar source phrases unless they contain a required name, quotation, number, or technical term. Communicate the same message, details, exact uncertainty, and voice at approximately the same length."
        default:
            "Transform the draft completely by starting from a blank page. Do not return a close paraphrase. Open with the central action, decision, or most useful idea instead of the source opening. Use a clearly different presentation sequence and reconstruct every sentence. Split, combine, and reorder ideas when meaning permits. Do not reuse source sentence openings or chains of more than four ordinary source words except where required for names, exact details, quotations, or technical terms. Write the strongest new composition of the same message in the same author's voice and at approximately the same length."
        }
    }
}

public enum RewriteCustomInstructionsPolicy {
    public static let maximumCharacters = 2_000

    public static func normalized(_ instructions: String?) -> String? {
        guard let instructions else { return nil }

        let cleaned = instructions
            .replacingOccurrences(of: "\0", with: "")
            .replacingOccurrences(of: "<", with: "‹")
            .replacingOccurrences(of: ">", with: "›")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return nil }
        return String(cleaned.prefix(maximumCharacters))
    }
}

public enum RewriteFidelityPolicy {
    private static let qualifierPatterns = [
        "not totally sure",
        "not entirely sure",
        "not completely sure",
        "have not confirmed",
        "has not confirmed",
        "not confirmed",
        "not necessarily",
        "not sure",
        "maybe",
        "probably",
        "roughly",
        "approximately",
        "perhaps",
        "might",
        "unlikely",
        "likely"
    ]

    public static func qualifiers(in source: String) -> [String] {
        var remaining = source
        var matches: [String] = []

        for pattern in qualifierPatterns {
            while let range = remaining.range(
                of: pattern,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) {
                matches.append(String(remaining[range]))
                remaining.replaceSubrange(
                    range,
                    with: String(repeating: " ", count: remaining[range].count)
                )
            }
        }

        return matches
    }
}
