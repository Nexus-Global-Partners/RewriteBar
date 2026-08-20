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
    @ObservedObject var presentation: SettingsPresentationModel

    @State private var instructionsDraft: String
    @StateObject private var accessibility: AccessibilitySetupModel
    @StateObject private var codexAccount: CodexAccountController
    @Environment(\.colorScheme) private var colorScheme

    init(
        store: RewriteSettingsStore = .shared,
        presentation: SettingsPresentationModel = SettingsPresentationModel(),
        accessibility: AccessibilitySetupModel = AccessibilitySetupModel(),
        codexAccount: CodexAccountController = .shared
    ) {
        self.store = store
        self.presentation = presentation
        _instructionsDraft = State(initialValue: store.customInstructions)
        _accessibility = StateObject(wrappedValue: accessibility)
        _codexAccount = StateObject(wrappedValue: codexAccount)
    }

    var body: some View {
        Form {
            Section {
                Picker("Rewrite with", selection: $store.rewriteProvider) {
                    ForEach(RewriteProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .accessibilityLabel("Rewrite processing mode")

                if store.rewriteProvider == .codexLuna {
                    HStack(spacing: 8) {
                        Label(
                            codexAccount.statusText,
                            systemImage: codexAccount.isLunaReady
                                ? "checkmark.circle"
                                : "exclamationmark.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Spacer()

                        if codexAccount.canConnect {
                            Button("Connect Codex") {
                                codexAccount.connect()
                            }
                        } else if codexAccount.isConnected {
                            Button("Disconnect") {
                                codexAccount.disconnect()
                            }
                        }
                    }
                }
            } header: {
                Text("Processing")
            } footer: {
                Text(
                    store.rewriteProvider == .codexLuna
                        ? "Online mode sends copied or selected text and any enabled custom instructions to OpenAI through your Codex account. Requests use an isolated, temporary thread with command, image-view, web, app, and external tools disabled. Any unexpected tool request is refused. If Luna is unavailable, RewriteBar retries on this Mac."
                        : "On-device mode keeps rewrite text on this Mac and does not require an account or network connection."
                )
                .foregroundStyle(.secondary)
            }

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
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Rewrite selection") {
                    HStack(spacing: 8) {
                        ShortcutRecorderView(shortcut: $store.keyboardShortcut)
                            .frame(width: 142, height: 26)

                        if accessibility.isGranted {
                            AccessibilityEnabledPin()
                        }
                    }
                }

                if let error = store.shortcutRegistrationError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Shortcut error: \(error)")
                }

                if !accessibility.isGranted {
                    HStack(spacing: 8) {
                        Image(systemName: "circle.dotted")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Setup needed")
                                .foregroundStyle(.secondary)

                            Text("Allow this copy of RewriteBar in macOS Accessibility.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        SetupGlassButton(
                            emphasisToken: presentation.accessibilitySetupEmphasis
                        ) {
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
                        ? "Close Settings, select editable text in another app, then press \(store.keyboardShortcut?.displayName ?? "the shortcut"). RewriteBar cannot rewrite this Settings window."
                        : "Set Up refreshes any older RewriteBar permission, then macOS asks you to allow this copy."
                )
                .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Use custom instructions", isOn: $store.customInstructionsEnabled)
                    .accessibilityHint("Applies your preferences to every rewrite")

                LabeledContent("Exclusive") {
                    HStack(spacing: 8) {
                        Text(store.customInstructionsExclusive ? "Yes" : "No")
                            .foregroundStyle(.secondary)

                        Toggle(
                            "Use only custom instructions for writing style",
                            isOn: $store.customInstructionsExclusive
                        )
                        .labelsHidden()
                    }
                }
                .disabled(!store.customInstructionsEnabled)
                .opacity(store.customInstructionsEnabled ? 1 : 0.48)
                .accessibilityHint(
                    store.customInstructionsExclusive
                        ? "The selected writing style is ignored"
                        : "Custom instructions are added to the selected writing style"
                )

                TextEditor(text: $instructionsDraft)
                    .font(.body)
                    .frame(minHeight: 78, maxHeight: 108)
                    .padding(5)
                    .scrollContentBackground(.hidden)
                    .background {
                        ZStack {
                            Rectangle()
                                .fill(.thinMaterial)

                            Rectangle()
                                .fill(
                                    colorScheme == .dark
                                        ? Color.black.opacity(0.26)
                                        : Color(nsColor: .textBackgroundColor).opacity(0.72)
                                )
                        }
                    }
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
                Text(
                    store.customInstructionsExclusive
                        ? "Exclusive uses only your custom instructions for style. Meaning, facts, language, intensity, and safety rules still apply."
                        : "Custom instructions add to the selected writing style. Meaning, facts, language, intensity, and safety rules still apply."
                )
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .listRowSeparator(.hidden)
        .foregroundStyle(AppPalette.settingsPrimaryText(for: colorScheme))
        .tint(
            colorScheme == .dark
                ? Color.white.opacity(0.58)
                : AppPalette.graphite
        )
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
                ZStack {
                    Rectangle()
                        .fill(.thinMaterial)

                    Rectangle()
                        .fill(
                            colorScheme == .dark
                                ? Color.black.opacity(0.38)
                                : AppPalette.frost.opacity(0.16)
                        )
                }
            }
        }
        .frame(width: 520, height: 700)
        .onChange(of: store.rewriteProvider) { _, provider in
            if provider == .codexLuna {
                codexAccount.refresh()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            accessibility.refresh()
        }
        .task {
            if store.rewriteProvider == .codexLuna {
                codexAccount.refresh()
            }
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

private struct AccessibilityEnabledPin: View {
    var body: some View {
        Label("Enabled", systemImage: "checkmark")
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(AppPalette.settingsEnabledText)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background {
                ZStack {
                    Capsule()
                        .fill(.thinMaterial)

                    Capsule()
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.30))

                    Capsule()
                        .strokeBorder(
                            Color(nsColor: .labelColor).opacity(0.16),
                            lineWidth: 0.7
                        )
                }
            }
            .accessibilityLabel("Keyboard shortcut enabled")
    }
}

struct SetupAttentionState {
    private(set) var handledToken = 0

    mutating func shouldEmphasize(for token: Int) -> Bool {
        guard token > handledToken else { return false }
        handledToken = token
        return true
    }
}

private struct SetupGlassButton: View {
    let emphasisToken: Int
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var emphasisStrength = 0.0
    @State private var emphasisTask: Task<Void, Never>?
    @State private var attentionState = SetupAttentionState()

    var body: some View {
        Button(action: action) {
            Text("Set Up")
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(AppPalette.settingsControlText(for: colorScheme))
                .padding(.horizontal, 13)
                .frame(height: 28)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.thinMaterial)

                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                colorScheme == .dark
                                    ? Color.black.opacity(0.18 - (0.06 * emphasisStrength))
                                    : Color.white.opacity(0.62 + (0.22 * emphasisStrength))
                            )

                        if colorScheme == .dark {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.085 + (0.04 * emphasisStrength)),
                                            .white.opacity(0.012)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }

                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                .white.opacity(
                                    colorScheme == .dark
                                        ? 0.14 + (0.08 * emphasisStrength)
                                        : 0.88 + (0.12 * emphasisStrength)
                                ),
                                lineWidth: 0.8
                            )

                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                AppPalette.graphite.opacity(0.10),
                                lineWidth: 0.7
                            )
                    }
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.black.opacity(0.30 + (0.08 * emphasisStrength))
                            : AppPalette.graphite.opacity(0.12 + (0.08 * emphasisStrength)),
                        radius: 4 + (3 * emphasisStrength),
                        y: 2
                    )
                }
                .scaleEffect(
                    reduceMotion ? 1 : 1 + (0.045 * emphasisStrength)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onAppear {
            handleEmphasis(emphasisToken)
        }
        .onChange(of: emphasisToken) { _, token in
            handleEmphasis(token)
        }
        .onDisappear {
            emphasisTask?.cancel()
        }
    }

    private func handleEmphasis(_ token: Int) {
        guard attentionState.shouldEmphasize(for: token) else { return }
        emphasize()
    }

    private func emphasize() {
        emphasisTask?.cancel()

        if reduceMotion {
            emphasisStrength = 1
            emphasisTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                emphasisStrength = 0
            }
            return
        }

        withAnimation(.easeOut(duration: 0.12)) {
            emphasisStrength = 1
        }
        emphasisTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                emphasisStrength = 0
            }
        }
    }
}
