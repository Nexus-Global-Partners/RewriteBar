import AppKit
import Foundation
import RewriteCore
import SwiftUI
import Testing
@testable import RewriteBar

@Test @MainActor
func shortcutRecorderSuspendsAndRestoresGlobalRegistration() {
    let button = ShortcutRecorderButton()
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 220, height: 60),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    window.contentView = button

    let beginCount = NotificationCounter()
    let endCount = NotificationCounter()
    let center = NotificationCenter.default
    let beginObserver = center.addObserver(
        forName: .rewriteBarShortcutRecordingDidBegin,
        object: button,
        queue: nil
    ) { _ in
        beginCount.value += 1
    }
    let endObserver = center.addObserver(
        forName: .rewriteBarShortcutRecordingDidEnd,
        object: button,
        queue: nil
    ) { _ in
        endCount.value += 1
    }
    defer {
        center.removeObserver(beginObserver)
        center.removeObserver(endObserver)
    }

    button.performClick(nil)
    #expect(button.isRecording)
    #expect(beginCount.value == 1)

    _ = window.makeFirstResponder(nil)
    #expect(!button.isRecording)
    #expect(endCount.value == 1)
}

@Test @MainActor
func codexConnectionFeedbackAppearsOnlyAfterAReadyConnection() {
    #expect(
        CodexConnectionFeedbackPolicy.showsConfirmation(
            previous: .connecting,
            current: .connected(plan: "pro", lunaAvailable: true, usedPercent: 19)
        )
    )
    #expect(
        !CodexConnectionFeedbackPolicy.showsConfirmation(
            previous: .checking,
            current: .connected(plan: "pro", lunaAvailable: true, usedPercent: 19)
        )
    )
    #expect(
        !CodexConnectionFeedbackPolicy.showsConfirmation(
            previous: .connecting,
            current: .connected(plan: "pro", lunaAvailable: false, usedPercent: 19)
        )
    )
}

@Test
func shortcutFailureFeedbackExplainsWhatTheUserCanDoNext() {
    #expect(ShortcutFailureFeedbackPolicy.fontSize == 11)
    #expect(
        ShortcutFailureFeedbackPolicy.title(for: .noFocusedApplication)
            == "Select text"
    )
    #expect(
        ShortcutFailureFeedbackPolicy.title(for: .noFocusedElement)
            == "Select text"
    )
    #expect(
        ShortcutFailureFeedbackPolicy.title(for: .permissionRequired)
            == "Set Up"
    )
    #expect(
        ShortcutFailureFeedbackPolicy.title(for: .selectionNotEditable)
            == "Not editable"
    )
}

@Test
func shortcutCopyOnlyFeedbackNeverLooksLikeReplacementSuccess() {
    #expect(ShortcutCopyOnlyFeedbackPolicy.title == "Copied")
    #expect(ShortcutCopyOnlyFeedbackPolicy.fontSize == 11)
    let toolTip = ShortcutCopyOnlyFeedbackPolicy.toolTip(for: .selectionChanged)
    #expect(toolTip.contains("not replaced"))
    #expect(toolTip.contains("clipboard"))
}

@Test @MainActor
func accessibilityPrefersTheSystemWideFocusedElementForTheActiveProcess() {
    #expect(
        AccessibilitySelectionClient.shouldUseSystemWideFocusedElement(
            elementProcessIdentifier: 2468,
            focusedProcessIdentifier: 2468
        )
    )
    #expect(
        !AccessibilitySelectionClient.shouldUseSystemWideFocusedElement(
            elementProcessIdentifier: 9753,
            focusedProcessIdentifier: 2468
        )
    )
    #expect(
        !AccessibilitySelectionClient.shouldUseSystemWideFocusedElement(
            elementProcessIdentifier: nil,
            focusedProcessIdentifier: 2468
        )
    )
}

@Test @MainActor
func accessibilityFindsAUniqueEditableSelectionBelowTheFocusedWindow() throws {
    let children = [
        0: [1, 2],
        1: [3],
        2: [],
        3: []
    ]

    let candidate = try AccessibilitySelectionClient.uniqueSelectionCandidate(
        roots: [0],
        children: { children[$0] ?? [] },
        hasEditableSelection: { $0 == 3 }
    )

    #expect(candidate == 3)
}

@Test @MainActor
func accessibilityRefusesAmbiguousWindowSelectionFallback() {
    #expect(throws: AccessibilityRewriteFailure.multipleSelectionsUnsupported) {
        _ = try AccessibilitySelectionClient.uniqueSelectionCandidate(
            roots: [0],
            children: { $0 == 0 ? [1, 2] : [] },
            hasEditableSelection: { $0 == 1 || $0 == 2 }
        )
    }
}

@Test @MainActor
func settingsEnabledStatusAdaptsToLightAndDarkAppearances() throws {
    let lightAppearance = try #require(NSAppearance(named: .aqua))
    let darkAppearance = try #require(NSAppearance(named: .darkAqua))

    var resolvedLightColor: NSColor?
    lightAppearance.performAsCurrentDrawingAppearance {
        resolvedLightColor = NSColor(AppPalette.settingsEnabledText)
            .usingColorSpace(.deviceRGB)
    }

    var resolvedDarkColor: NSColor?
    darkAppearance.performAsCurrentDrawingAppearance {
        resolvedDarkColor = NSColor(AppPalette.settingsEnabledText)
            .usingColorSpace(.deviceRGB)
    }

    let lightColor = try #require(resolvedLightColor)
    let darkColor = try #require(resolvedDarkColor)

    #expect(lightColor.redComponent < 0.15)
    #expect(lightColor.greenComponent < 0.15)
    #expect(lightColor.blueComponent < 0.15)
    #expect(darkColor.redComponent > 0.85)
    #expect(darkColor.greenComponent > 0.85)
    #expect(darkColor.blueComponent > 0.85)
    #expect(lightColor.alphaComponent > 0.60)
    #expect(darkColor.alphaComponent > 0.60)
}

@Test @MainActor
func settingsUseProductDefaultsAndPersistChanges() throws {
    let suiteName = "RewriteBarTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = RewriteSettingsStore(defaults: defaults)
    #expect(store.rewriteProvider == .codexLuna)
    #expect(store.defaultIntensity == 3)
    #expect(store.writingStyle == .rewriteBar)
    #expect(store.keyboardShortcut == .rewriteDefault)
    #expect(store.keyboardShortcut?.keyCode == 15)
    #expect(store.keyboardShortcut?.modifiers == [.option])
    #expect(store.keyboardShortcut?.displayName == "⌥R")
    #expect(!store.customInstructionsEnabled)
    #expect(!store.customInstructionsExclusive)

    store.defaultIntensity = 14
    store.rewriteProvider = .codexLuna
    store.writingStyle = .clear
    store.keyboardShortcut = nil
    store.customInstructionsEnabled = true
    store.customInstructionsExclusive = true
    store.saveCustomInstructions("  Keep it direct.  ")

    let reloaded = RewriteSettingsStore(defaults: defaults)
    #expect(reloaded.rewriteProvider == .codexLuna)
    #expect(reloaded.defaultIntensity == 10)
    #expect(reloaded.writingStyle == .clear)
    #expect(reloaded.keyboardShortcut == nil)
    #expect(reloaded.customInstructionsEnabled)
    #expect(reloaded.customInstructionsExclusive)
    #expect(reloaded.customInstructions == "Keep it direct.")

    reloaded.resetCustomInstructions()
    #expect(!reloaded.customInstructionsEnabled)
    #expect(!reloaded.customInstructionsExclusive)

    reloaded.resetAll()
    #expect(reloaded.rewriteProvider == .codexLuna)
    #expect(reloaded.keyboardShortcut == .rewriteDefault)
    #expect(reloaded.keyboardShortcut?.displayName == "⌥R")
}

@Test @MainActor
func settingsMigrateThePreviousDefaultWithoutChangingCustomShortcuts() throws {
    let oldSuiteName = "RewriteBarTests.OldDefault.\(UUID().uuidString)"
    let oldDefaults = try #require(UserDefaults(suiteName: oldSuiteName))
    defer { oldDefaults.removePersistentDomain(forName: oldSuiteName) }

    let previousDefault = GlobalShortcut(keyCode: 15, modifiers: [.command])
    oldDefaults.set(
        try JSONEncoder().encode(previousDefault),
        forKey: RewriteSettingsStore.Key.keyboardShortcut
    )

    let migrated = RewriteSettingsStore(defaults: oldDefaults)
    #expect(migrated.keyboardShortcut == .rewriteDefault)
    #expect(migrated.keyboardShortcut?.displayName == "⌥R")

    let customSuiteName = "RewriteBarTests.CustomShortcut.\(UUID().uuidString)"
    let customDefaults = try #require(UserDefaults(suiteName: customSuiteName))
    defer { customDefaults.removePersistentDomain(forName: customSuiteName) }

    let customShortcut = GlobalShortcut(keyCode: 40, modifiers: [.control])
    customDefaults.set(
        try JSONEncoder().encode(customShortcut),
        forKey: RewriteSettingsStore.Key.keyboardShortcut
    )

    let preserved = RewriteSettingsStore(defaults: customDefaults)
    #expect(preserved.keyboardShortcut == customShortcut)
}

@Test @MainActor
func selectionContinuityUsesTheStableRange() {
    let original = CFRange(location: 42, length: 18)

    #expect(
        AccessibilitySelectionClient.selectionRangeIsUnchanged(
            original: original,
            current: CFRange(location: 42, length: 18)
        )
    )
    #expect(
        !AccessibilitySelectionClient.selectionRangeIsUnchanged(
            original: original,
            current: CFRange(location: 42, length: 17)
        )
    )
    #expect(
        !AccessibilitySelectionClient.selectionRangeIsUnchanged(
            original: original,
            current: CFRange(location: 43, length: 18)
        )
    )
}

@Test @MainActor
func accessibilityRangeHelpersUseUTF16Offsets() {
    let value = "Start 👋 selected text end"
    let selected = "selected text"
    let location = (value as NSString).range(of: selected).location
    let range = CFRange(location: location, length: (selected as NSString).length)

    #expect(AccessibilitySelectionClient.text(in: value, range: range) == selected)
    #expect(
        AccessibilitySelectionClient.replacingText(
            in: value,
            range: range,
            with: "rewritten"
        ) == "Start 👋 rewritten end"
    )
}

@Test @MainActor
func accessibilityRangeHelpersRejectInvalidEditorRanges() {
    let value = "Short value"

    #expect(
        AccessibilitySelectionClient.text(
            in: value,
            range: CFRange(location: 40, length: 2)
        ) == nil
    )
    #expect(
        AccessibilitySelectionClient.replacingText(
            in: value,
            range: CFRange(location: -1, length: 2),
            with: "No"
        ) == nil
    )
}

@Test @MainActor
func accessibilityFocusedApplicationFallsBackToTheFrontmostProcess() throws {
    let resolved = try AccessibilitySelectionClient
        .focusedApplicationProcessIdentifier(
            accessibilityProcessIdentifier: nil,
            frontmostProcessIdentifier: 2468,
            currentProcessIdentifier: 1357
        )

    #expect(resolved == 2468)
}

@Test @MainActor
func accessibilityFocusedApplicationPrefersTheSystemWideProcess() throws {
    let resolved = try AccessibilitySelectionClient
        .focusedApplicationProcessIdentifier(
            accessibilityProcessIdentifier: 9753,
            frontmostProcessIdentifier: 2468,
            currentProcessIdentifier: 1357
        )

    #expect(resolved == 9753)
}

@Test @MainActor
func accessibilityFocusedApplicationRejectsRewriteBarItself() {
    do {
        _ = try AccessibilitySelectionClient
            .focusedApplicationProcessIdentifier(
                accessibilityProcessIdentifier: 1357,
                frontmostProcessIdentifier: 1357,
                currentProcessIdentifier: 1357
            )
        Issue.record("RewriteBar accepted itself as the editing application.")
    } catch let failure as AccessibilityRewriteFailure {
        #expect(failure == .noFocusedApplication)
    } catch {
        Issue.record("Focused application resolution returned an unexpected error.")
    }
}

@Test @MainActor
func accessibilitySelectionPlanKeepsAPlainTextFallbackWhenAvailable() throws {
    let fullText = "Before selected after"
    let selectedRange = CFRange(location: 7, length: 8)
    let plan = try AccessibilitySelectionClient.selectionPlan(
        selectedText: "selected",
        fullText: fullText,
        fullTextIsSettable: true,
        range: selectedRange
    )

    #expect(plan.text == "selected")
    #expect(
        plan.replacementStrategy
            == .selectedTextWithPlainTextFallback(originalValue: fullText)
    )
}

@Test @MainActor
func accessibilitySelectionPlanUsesEditablePlainTextValueWhenSelectedTextIsUnavailable() throws {
    let fullText = "Before selected after"
    let selectedRange = CFRange(location: 7, length: 8)
    let plan = try AccessibilitySelectionClient.selectionPlan(
        selectedText: nil,
        fullText: fullText,
        fullTextIsSettable: true,
        range: selectedRange
    )

    #expect(plan.text == "selected")
    #expect(
        plan.replacementStrategy
            == .plainTextValue(originalValue: fullText)
    )
}

@Test @MainActor
func accessibilitySelectionPlanUsesReadableSelectionEvenWhenEditabilityIsUnknown() throws {
    let plan = try AccessibilitySelectionClient.selectionPlan(
        selectedText: "selected",
        fullText: nil,
        fullTextIsSettable: false,
        range: CFRange(location: 0, length: 8)
    )

    #expect(plan.text == "selected")
    #expect(plan.replacementStrategy == .selectedText)
}

@Test @MainActor
func accessibilitySelectionPlanKeepsFallbackWhenSettableReportingIsWrong() throws {
    let fullText = "Before selected after"
    let plan = try AccessibilitySelectionClient.selectionPlan(
        selectedText: "selected",
        fullText: fullText,
        fullTextIsSettable: false,
        range: CFRange(location: 7, length: 8)
    )

    #expect(
        plan.replacementStrategy
            == .selectedTextWithPlainTextFallback(originalValue: fullText)
    )
}

@Test @MainActor
func accessibilitySelectionPlanRejectsUnavailableSelections() {
    do {
        _ = try AccessibilitySelectionClient.selectionPlan(
            selectedText: nil,
            fullText: nil,
            fullTextIsSettable: false,
            range: CFRange(location: 0, length: 0)
        )
        Issue.record("An unavailable selection was accepted.")
    } catch let failure as AccessibilityRewriteFailure {
        #expect(failure == .selectionUnavailable)
    } catch {
        Issue.record("An unavailable selection returned an unexpected error.")
    }
}

@Test @MainActor
func accessibilitySetupRefreshesWhenMacOSGrantsAccess() {
    let state = AccessibilityPermissionState()
    let model = AccessibilitySetupModel(
        permissionCheck: { state.granted },
        beginSetupAction: { state.setupRequestCount += 1 }
    )

    #expect(!model.isGranted)

    model.beginSetup()
    #expect(state.setupRequestCount == 1)
    #expect(!model.isGranted)

    state.granted = true
    model.refresh()
    #expect(model.isGranted)
}

@Test @MainActor
func accessibilitySetupClosesItsAlertOnceAccessBecomesReady() {
    let state = AccessibilityPermissionState()
    let model = AccessibilitySetupModel(
        permissionCheck: { state.granted },
        beginSetupAction: { state.setupRequestCount += 1 },
        setupDidCompleteAction: { state.setupCompletionCount += 1 }
    )

    model.beginSetup()
    #expect(state.setupCompletionCount == 0)

    state.granted = true
    model.refresh()
    #expect(model.isGranted)
    #expect(state.setupCompletionCount == 1)

    model.refresh()
    #expect(state.setupCompletionCount == 1)
}

@Test
func accessibilitySetupResetsOldIdentityBeforeRequestingCurrentBuild() {
    var actions: [String] = []

    let granted = AccessibilityPermission.refreshPermissionRecord(
        reset: {
            actions.append("reset")
            return true
        },
        request: {
            actions.append("request")
            return false
        }
    )

    #expect(actions == ["reset", "request"])
    #expect(!granted)
}

@Test
func accessibilityPermissionFailureStartsAutomaticRecoveryOnlyOnce() {
    var recovery = AccessibilityPermissionRecoveryState()
    let firstPermissionFailure = recovery.shouldBeginSetup(
        for: .permissionRequired
    )
    let repeatedPermissionFailure = recovery.shouldBeginSetup(
        for: .permissionRequired
    )
    let unrelatedFailure = recovery.shouldBeginSetup(for: .selectionEmpty)

    #expect(firstPermissionFailure)
    #expect(!repeatedPermissionFailure)
    #expect(!unrelatedFailure)
}

@Test @MainActor
func shortcutRewriteReplacesSelectionAndReportsCompletion() async throws {
    let selection = SelectionStub(text: "Original")
    let provider = SelectionProviderStub(selection: selection)
    let generator = ShortcutGeneratorStub(output: "Rewritten")
    let coordinator = SelectedTextRewriteCoordinator(
        selectionProvider: provider,
        rewriteEngine: RewriteEngine(
            generator: generator,
            timeoutSeconds: { _ in 1 }
        )
    )
    var completed: String?
    coordinator.onCompletion = { completed = $0 }

    coordinator.startRewrite(intensity: 3)
    try await waitUntil { coordinator.state == .replaced }

    #expect(selection.replacement == "Rewritten")
    #expect(completed == "Rewritten")
}

@Test @MainActor
func shortcutRewriteCopiesWhenSelectionCanNoLongerBeReplaced() async throws {
    let selection = SelectionStub(
        text: "Original",
        replacementFailure: .focusChanged
    )
    let provider = SelectionProviderStub(selection: selection)
    let generator = ShortcutGeneratorStub(output: "Rewritten")
    let coordinator = SelectedTextRewriteCoordinator(
        selectionProvider: provider,
        rewriteEngine: RewriteEngine(
            generator: generator,
            timeoutSeconds: { _ in 1 }
        )
    )
    var copiedOutput: String?
    var copiedFailure: AccessibilityRewriteFailure?
    coordinator.onCopyOnlyCompletion = { output, failure in
        copiedOutput = output
        copiedFailure = failure
    }

    coordinator.startRewrite(intensity: 3)
    try await waitUntil { coordinator.state == .failed(.focusChanged) }

    #expect(copiedOutput == "Rewritten")
    #expect(copiedFailure == .focusChanged)
}

@Test @MainActor
func shortcutRewriteForwardsPersonalizationSettings() async throws {
    let selection = SelectionStub(text: "Original")
    let generator = ShortcutGeneratorStub(output: "Rewritten")
    let coordinator = SelectedTextRewriteCoordinator(
        selectionProvider: SelectionProviderStub(selection: selection),
        rewriteEngine: RewriteEngine(
            generator: generator,
            timeoutSeconds: { _ in 1 }
        )
    )

    coordinator.startRewrite(
        intensity: 7,
        writingStyle: .persuasive,
        customInstructions: "Keep it understated.",
        customInstructionsExclusive: true,
        provider: .codexLuna
    )
    try await waitUntil { coordinator.state == .replaced }

    let request = await generator.lastRequest
    #expect(request?.text == "Original")
    #expect(request?.intensity == 7)
    #expect(request?.writingStyle == .persuasive)
    #expect(request?.customInstructions == "Keep it understated.")
    #expect(request?.customInstructionsExclusive == true)
    #expect(request?.provider == .codexLuna)
}

@Test @MainActor
func settingsRecoverFromAnUnknownProviderValue() throws {
    let suiteName = "RewriteBarTests.ProviderMigration.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set("future-provider", forKey: RewriteSettingsStore.Key.rewriteProvider)

    let store = RewriteSettingsStore(defaults: defaults)

    #expect(store.rewriteProvider == .codexLuna)
}

@MainActor
private func waitUntil(
    _ condition: @escaping @MainActor () -> Bool
) async throws {
    for _ in 0..<100 {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    throw ShortcutTestFailure.timedOut
}

@MainActor
private final class SelectionProviderStub: EditableTextSelectionProviding {
    let selection: SelectionStub

    init(selection: SelectionStub) {
        self.selection = selection
    }

    func captureSelection(
        promptingForPermission: Bool
    ) throws -> any EditableTextSelection {
        selection
    }
}

@MainActor
private final class SelectionStub: EditableTextSelection {
    let originalText: String
    let replacementFailure: AccessibilityRewriteFailure?
    private(set) var replacement: String?

    init(
        text: String,
        replacementFailure: AccessibilityRewriteFailure? = nil
    ) {
        originalText = text
        self.replacementFailure = replacementFailure
    }

    func replaceSelection(with replacement: String) throws {
        if let replacementFailure {
            throw replacementFailure
        }
        self.replacement = replacement
    }
}

private actor ShortcutGeneratorStub: RewriteGenerating {
    let output: String
    private(set) var lastRequest: RewriteRequest?

    init(output: String) {
        self.output = output
    }

    func rewrite(
        request: RewriteRequest,
        onProgress: (@Sendable (Int) async -> Void)?
    ) async throws -> String {
        lastRequest = request
        return output
    }
}

private enum ShortcutTestFailure: Error {
    case timedOut
}

private final class AccessibilityPermissionState: @unchecked Sendable {
    var granted = false
    var setupRequestCount = 0
    var setupCompletionCount = 0
}

private final class NotificationCounter: @unchecked Sendable {
    var value = 0
}

@Test @MainActor
func menuIntensityControlsShortcutsAndRelaunchRestoresSavedDefault() throws {
    let suite = "RewriteBarTests.Session.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = RewriteSettingsStore(defaults: defaults)
    store.defaultIntensity = 4
    #expect(store.activeIntensity == 4)
    store.selectIntensity(8)
    #expect(store.activeIntensity == 8)
    #expect(store.defaultIntensity == 4)
    let relaunched = RewriteSettingsStore(defaults: defaults)
    #expect(relaunched.activeIntensity == 4)
    store.resetIntensity()
    #expect(store.activeIntensity == 4)
    store.selectIntensity(9)
    store.defaultIntensity = 6
    #expect(store.activeIntensity == 6)
    store.defaultIntensity = 99
    #expect(store.activeIntensity == 10)
    #expect(RewriteSettingsStore(defaults: defaults).defaultIntensity == 10)
}
