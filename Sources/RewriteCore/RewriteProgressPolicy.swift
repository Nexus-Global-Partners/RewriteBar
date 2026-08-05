public enum RewriteProgressPolicy {
    public static let preparationCeiling = 0.12
    public static let generationCeiling = 0.92

    public static func preparationProgress(
        elapsedSeconds: Double,
        sourceCharacterCount: Int
    ) -> Double {
        let expectedPreparationSeconds = min(
            3,
            max(0.7, Double(max(0, sourceCharacterCount)) / 1_200)
        )
        let fraction = max(0, elapsedSeconds) / expectedPreparationSeconds
        return min(preparationCeiling, fraction * preparationCeiling)
    }

    public static func generationProgress(
        generatedCharacterCount: Int,
        sourceCharacterCount: Int
    ) -> Double {
        let expectedOutputCharacters = max(
            1,
            Int(Double(max(1, sourceCharacterCount)) * 0.9)
        )
        let generatedFraction = min(
            1,
            Double(max(0, generatedCharacterCount)) / Double(expectedOutputCharacters)
        )
        return preparationCeiling
            + generatedFraction * (generationCeiling - preparationCeiling)
    }
}
