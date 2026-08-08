import Foundation
import RewriteCore
import Testing
@testable import RewriteBar

@Test @MainActor
func settingsUseProductDefaultsAndPersistChanges() throws {
    let suiteName = "RewriteBarTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = RewriteSettingsStore(defaults: defaults)
    #expect(store.defaultIntensity == 3)
    #expect(store.writingStyle == .rewriteBar)
    #expect(store.keyboardShortcut == .rewriteDefault)
    #expect(store.keyboardShortcut?.displayName == "⌘R")
    #expect(!store.customInstructionsEnabled)
    #expect(!store.customInstructionsExclusive)

    store.defaultIntensity = 14
    store.writingStyle = .clear
    store.keyboardShortcut = nil
    store.customInstructionsEnabled = true
    store.customInstructionsExclusive = true
    store.saveCustomInstructions("  Keep it direct.  ")

    let reloaded = RewriteSettingsStore(defaults: defaults)
    #expect(reloaded.defaultIntensity == 10)
    #expect(reloaded.writingStyle == .clear)
    #expect(reloaded.keyboardShortcut == nil)
    #expect(reloaded.customInstructionsEnabled)
    #expect(reloaded.customInstructionsExclusive)
    #expect(reloaded.customInstructions == "Keep it direct.")

    reloaded.resetCustomInstructions()
    #expect(!reloaded.customInstructionsEnabled)
    #expect(!reloaded.customInstructionsExclusive)
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

    init(output: String) {
        self.output = output
    }

    func rewrite(
        request: RewriteRequest,
        onProgress: (@Sendable (Int) async -> Void)?
    ) async throws -> String {
        output
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
