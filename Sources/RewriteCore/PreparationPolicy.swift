public enum PreparationPolicy {
    public static func timeoutSeconds(forCharacterCount characterCount: Int) -> Double {
        let scaledTimeout = 10 + Double(max(0, characterCount)) / 250
        return min(18, max(12, scaledTimeout))
    }
}
