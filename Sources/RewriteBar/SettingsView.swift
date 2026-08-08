import AppKit
import RewriteCore
import SwiftUI

@MainActor
final class AccessibilitySetupModel: ObservableObject {
    @Published private(set) var isGranted: Bool

    private let permissionCheck: @MainActor () -> Bool
    private let beginSetupAction: @MainActor () -> Void
    private let setupDidCompleteAction: @MainActor () -> Void
    private var isAwaitingSetupCompletion = false

    init(
        permissionCheck: @escaping @MainActor () -> Bool = {
            AccessibilityPermission.isGranted
        },
        beginSetupAction: @escaping @MainActor () -> Void = {
            AccessibilityPermission.beginSetup()
        },
        setupDidCompleteAction: @escaping @MainActor () -> Void = {
            AccessibilityPermission.dismissSetupAlert()
        }
    ) {
        self.permissionCheck = permissionCheck
        self.beginSetupAction = beginSetupAction
        self.setupDidCompleteAction = setupDidCompleteAction
        isGranted = permissionCheck()
    }

    func refresh() {
        let granted = permissionCheck()
        let setupCompleted = isAwaitingSetupCompletion && granted
        isGranted = granted

        if setupCompleted {
            isAwaitingSetupCompletion = false
            setupDidCompleteAction()
        }
    }

    func beginSetup() {
        isAwaitingSetupCompletion = true
        beginSetupAction()
        refresh()
    }
}

@MainActor
struct SettingsView: View {
    @ObservedObject var store: RewriteSettingsStore

    @State private var instructionsDraft: String
    @StateObject private var accessibility: AccessibilitySetupModel

    init(
        store: RewriteSettingsStore = .shared,
        accessibility: AccessibilitySetupModel = AccessibilitySetupModel()
    ) {
        self.store = store
        _instructionsDraft = State(initialValue: store.customInstructions)
        _accessibility = StateObject(wrappedValue: accessibility)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Shortcut intensity") {
                    HStack(spacing: 10) {
                        Slider(
                            value: intensityBinding,
                            in: 0...10,
                            step: 1
                        )
                        .frame(width: 190)
                        .accessibilityLabel("Default rewrite intensity")
                        .accessibilityValue("\(store.defaultIntensity) out of 10")

                        Text("\(store.defaultIntensity)")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                            .frame(width: 28, height: 24)
                            .background(.thinMaterial, in: Circle())
                            .accessibilityHidden(true)
                    }
                }

                Text(
                    RewriteIntensityPolicy.definition(
                        for: store.defaultIntensity
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Shortcut intensity description")

                Picker("Writing style", selection: $store.writingStyle) {
                    ForEach(RewriteStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .accessibilityLabel("Default writing style")

                Text(store.writingStyle.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Style description")
                    .accessibilityValue(store.writingStyle.explanation)
            } header: {
                Text("Rewrite")
            } footer: {
                Text("The slider in the menu bar still lets you change intensity for each rewrite.")
            }

            Section {
                LabeledContent("Rewrite selection") {
                    ShortcutRecorderView(shortcut: $store.keyboardShortcut)
                        .frame(width: 142, height: 26)
                }

                if let error = store.shortcutRegistrationError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Shortcut error: \(error)")
                }

                HStack(spacing: 8) {
                    Image(
                        systemName: accessibility.isGranted
                            ? "checkmark.circle.fill"
                            : "circle.dotted"
                    )
                    .foregroundStyle(accessibility.isGranted ? .primary : .secondary)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(accessibility.isGranted ? "Ready" : "Setup needed")
                            .foregroundStyle(accessibility.isGranted ? .primary : .secondary)

                        Text(
                            accessibility.isGranted
                                ? "Selected text can be replaced."
                                : "Allow this copy of RewriteBar in macOS Accessibility."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !accessibility.isGranted {
                        Button("Set Up") {
                            accessibility.beginSetup()
                        }
                        .accessibilityHint("Opens macOS Accessibility settings")
                    }
                }
            } header: {
                Text("Keyboard")
            } footer: {
                Text(
                    accessibility.isGranted
                        ? "Select editable text, then press the shortcut. The result replaces the selection and is copied."
                        : "Set Up refreshes any older RewriteBar permission, then macOS asks you to allow this copy."
                )
            }

            Section {
                Toggle("Use custom instructions", isOn: $store.customInstructionsEnabled)
                    .accessibilityHint("Applies your preferences to every rewrite")

                TextEditor(text: $instructionsDraft)
                    .font(.body)
                    .frame(minHeight: 78, maxHeight: 108)
                    .padding(5)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if instructionsDraft.isEmpty {
                            Text("For example: Keep my sentences short and direct.")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(.separator.opacity(0.65), lineWidth: 0.5)
                    }
                    .disabled(!store.customInstructionsEnabled)
                    .opacity(store.customInstructionsEnabled ? 1 : 0.48)
                    .accessibilityLabel("Custom rewrite instructions")
                    .onChange(of: instructionsDraft) { _, newValue in
                        let bounded = String(
                            newValue.prefix(RewriteSettingsStore.maximumInstructionLength)
                        )
                        if bounded != newValue {
                            instructionsDraft = bounded
                            return
                        }
                        store.saveCustomInstructions(bounded)
                    }

                HStack {
                    Text("\(instructionsDraft.count) of \(RewriteSettingsStore.maximumInstructionLength)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                        .accessibilityLabel("\(instructionsDraft.count) of \(RewriteSettingsStore.maximumInstructionLength) characters")

                    Spacer()

                    Button("Reset") {
                        store.resetCustomInstructions()
                        instructionsDraft = ""
                    }
                    .disabled(instructionsDraft.isEmpty && store.customInstructions.isEmpty)

                    Text("Saved automatically")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityLabel("Custom instructions save automatically")
                }
            } header: {
                Text("Custom instructions")
            } footer: {
                Text("Preferences can guide style, but cannot change the source meaning, facts, language, or safety rules.")
            }
        }
        .formStyle(.grouped)
        .tint(AppPalette.graphite)
        .scrollContentBackground(.hidden)
        .background {
            AppGlassBackground(neutralSurfaceOpacity: 0.90)
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Restore Defaults") {
                    store.resetAll()
                    instructionsDraft = store.customInstructions
                    accessibility.refresh()
                }
                .accessibilityHint("Restores all RewriteBar settings to their defaults")

                Spacer()

                Text("Settings save on this Mac")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background {
                Rectangle()
                    .fill(.thinMaterial)
                    .overlay(AppPalette.frost.opacity(0.16))
            }
            .overlay(alignment: .top) { Divider() }
        }
        .frame(width: 520, height: 590)
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            accessibility.refresh()
        }
        .task {
            while !Task.isCancelled {
                accessibility.refresh()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private var intensityBinding: Binding<Double> {
        Binding(
            get: { Double(store.defaultIntensity) },
            set: { store.defaultIntensity = Int($0.rounded()) }
        )
    }

}
