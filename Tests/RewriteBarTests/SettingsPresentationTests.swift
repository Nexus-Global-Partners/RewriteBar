import Testing
@testable import RewriteBar

@Test @MainActor
func accessibilitySetupEmphasisCanBeRequestedAgain() {
    let presentation = SettingsPresentationModel()

    #expect(presentation.accessibilitySetupEmphasis == 0)

    presentation.emphasizeAccessibilitySetup()
    #expect(presentation.accessibilitySetupEmphasis == 1)

    presentation.emphasizeAccessibilitySetup()
    #expect(presentation.accessibilitySetupEmphasis == 2)
}

@Test
func setupAttentionHandlesAPendingRequestWhenTheButtonAppears() {
    var attention = SetupAttentionState()

    let ignoresEmptyToken = attention.shouldEmphasize(for: 0)
    let handlesFirstToken = attention.shouldEmphasize(for: 1)
    let ignoresHandledToken = attention.shouldEmphasize(for: 1)
    let handlesNextToken = attention.shouldEmphasize(for: 2)

    #expect(!ignoresEmptyToken)
    #expect(handlesFirstToken)
    #expect(!ignoresHandledToken)
    #expect(handlesNextToken)
}
