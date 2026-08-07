import RewriteCore
import Testing

@Test
func sourceFallbackPreservesLiteralSourceContent() throws {
    let source = "“Keep this exact sentence.”"

    let fallback = try OutputSanitizer.sanitizeSourceFallback(source)

    #expect(fallback == source)
}

@Test
func sourceFallbackRemovesForbiddenDashCharactersSafely() throws {
    let source = "Project update\n- First item\nVersion alpha-beta"

    let fallback = try OutputSanitizer.sanitizeSourceFallback(source)

    #expect(fallback == "Project update\n• First item\nVersion alpha beta")
}
