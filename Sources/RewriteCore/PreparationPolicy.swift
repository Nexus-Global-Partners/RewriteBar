public enum PreparationPolicy {
    public static func timeoutSeconds(forCharacterCount characterCount: Int) -> Double {
        let scaledTimeout = 18 + Double(max(0, characterCount)) / 300
        return min(90, max(20, scaledTimeout))
    }
}
