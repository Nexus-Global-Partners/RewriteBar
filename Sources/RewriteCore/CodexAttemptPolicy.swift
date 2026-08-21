public enum CodexAttemptPolicy {
    public static let minimumSeconds = 7.0
    public static let maximumSeconds = 8.0

    public static func timeoutSeconds(forCharacterCount characterCount: Int) -> Double {
        let scaled = minimumSeconds + Double(max(0, characterCount)) / 2_000
        return min(maximumSeconds, scaled)
    }
}
