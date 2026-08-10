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
