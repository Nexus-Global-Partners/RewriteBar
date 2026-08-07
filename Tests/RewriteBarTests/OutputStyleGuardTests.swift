import RewriteCore
import Testing

@Test
func commitmentGuardRestoresAnOptionChangedToAPromise() {
    let source = "If that does not work, we can refund the full amount."
    let output = "If that does not work, we'll refund the full amount."

    let restored = OutputStyleGuard.restoringCommitmentStrength(
        in: output,
        source: source
    )

    #expect(restored == "If that does not work, we can refund the full amount.")
}

@Test
func commitmentGuardLeavesUnrelatedFutureTenseAlone() {
    let source = "We can refund it. Delivery takes three days."
    let output = "We can refund it. Delivery will take three days."

    let restored = OutputStyleGuard.restoringCommitmentStrength(
        in: output,
        source: source
    )

    #expect(restored == output)
}

@Test
func officeFillerGuardReplacesWholePhrasesOnly() {
    let source = "We checked the draft."
    let output = "We should touch base, then review the leveraged position."

    let cleaned = OutputStyleGuard.replacingOfficeFiller(
        in: output,
        source: source
    )

    #expect(cleaned == "We should check in, then review the leveraged position.")
}

@Test
func officeFillerGuardPreservesQuotedSourceWording() {
    let source = "The title is “Touch Base Tomorrow”."
    let output = "The title is “Touch Base Tomorrow”."

    let cleaned = OutputStyleGuard.replacingOfficeFiller(
        in: output,
        source: source
    )

    #expect(cleaned == output)
}
