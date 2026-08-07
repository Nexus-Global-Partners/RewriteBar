import AppKit
import RewriteCore
import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var store: RewriteSettingsStore

    @State private var instructionsDraft: String
    @State private var accessibilityGranted = AccessibilityPermission.isGranted
    @State private var didSaveInstructions = false

    init(store: RewriteSettingsStore = .shared) {
        self.store = store
        _instructionsDraft = State(initialValue: store.customInstructions)
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
                    Circle()
                        .fill(accessibilityGranted ? Color.primary : Color.secondary)
                        .frame(width: 7, height: 7)
                        .accessibilityHidden(true)

                    Text(accessibilityGranted ? "Accessibility allowed" : "Accessibility required")
                        .foregroundStyle(accessibilityGranted ? .primary : .secondary)

                    Spacer()

                    if !accessibilityGranted {
                        Button("Allow Access") {
                            accessibilityGranted = AccessibilityPermission.requestIfNeeded()
                        }
                        .accessibilityHint("Opens the macOS permission prompt for selected text rewriting")

                        Button("Open Settings") {
                            openAccessibilitySettings()
                        }
                        .accessibilityHint("Opens Accessibility privacy settings")
                    }
                }
            } header: {
                Text("Keyboard")
            } footer: {
                Text("Select editable text in any supported app, then press the shortcut. Press Delete while recording to disable it.")
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
                                .padding(.vertical, 12)
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
                        if newValue.count > RewriteSettingsStore.maximumInstructionLength {
                            instructionsDraft = String(
                                newValue.prefix(RewriteSettingsStore.maximumInstructionLength)
                            )
                        }
                        didSaveInstructions = false
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
                        didSaveInstructions = false
                    }
                    .disabled(instructionsDraft.isEmpty && store.customInstructions.isEmpty)

                    Button(didSaveInstructions ? "Saved" : "Save") {
                        store.saveCustomInstructions(instructionsDraft)
                        instructionsDraft = store.customInstructions
                        didSaveInstructions = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppPalette.graphite)
                    .disabled(
                        !store.customInstructionsEnabled
                            || normalizedDraft == store.customInstructions
                    )
                    .accessibilityHint("Saves the custom instructions used for future rewrites")
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
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.white.opacity(0.04))
                .ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Restore Defaults") {
                    store.resetAll()
                    instructionsDraft = store.customInstructions
                    didSaveInstructions = false
                    accessibilityGranted = AccessibilityPermission.isGranted
                }
                .accessibilityHint("Restores all RewriteBar settings to their defaults")

                Spacer()

                Text("Settings save on this Mac")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.thinMaterial)
            .overlay(alignment: .top) { Divider() }
        }
        .frame(width: 520, height: 590)
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            accessibilityGranted = AccessibilityPermission.isGranted
        }
    }

    private var intensityBinding: Binding<Double> {
        Binding(
            get: { Double(store.defaultIntensity) },
            set: { store.defaultIntensity = Int($0.rounded()) }
        )
    }

    private var normalizedDraft: String {
        instructionsDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
