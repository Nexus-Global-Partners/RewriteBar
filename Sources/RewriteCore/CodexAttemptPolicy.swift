public enum CodexAttemptPolicy {
    public static let minimumSeconds = 4.75
    public static let maximumSeconds = 6.5

    public static func timeoutSeconds(forCharacterCount characterCount: Int) -> Double {
        let scaled = minimumSeconds + Double(max(0, characterCount)) / 1_000
        return min(maximumSeconds, scaled)
    }
}
