import Foundation

public enum RewriteOutputProcessor {
    public static func finalize(
        _ output: String,
        protectedSource: ProtectedSource,
        source: String,
        intensity: Int,
        customInstructions: String?
    ) throws -> String {
        guard let restored = protectedSource.restoringProtectedContent(
            in: output
        ) else {
            throw RewriteError.generationFailed
        }
        let sanitized = try OutputSanitizer.sanitize(restored)
        let withoutFraming = OutputStyleGuard.removingIntroducedFraming(
            from: sanitized,
            source: source
        )
        let withoutOfficeFiller = OutputStyleGuard.replacingOfficeFiller(
            in: withoutFraming,
            source: source,
            intensity: intensity
        )
        let withUncertainty = OutputStyleGuard.restoringUncertaintyStrength(
            in: withoutOfficeFiller,
            source: source
        )
        let withCommitment = OutputStyleGuard.restoringCommitmentStrength(
            in: withUncertainty,
            source: source
        )
        return RewriteCustomInstructionsPolicy.applyingPresentation(
            to: withCommitment,
            source: source,
            instructions: customInstructions
        )
    }

    public static func validateFidelity(
        source: String,
        output: String
    ) throws -> String {
        guard OutputFidelityValidator.evaluate(
            source: source,
            output: output
        ).preservesMeaningSignals else {
            throw RewriteError.generationFailed
        }
        return output
    }
}
