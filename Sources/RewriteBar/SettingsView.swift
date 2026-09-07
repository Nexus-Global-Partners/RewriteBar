import AppKit
import RewriteCore
import SwiftUI
import ServiceManagement

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
    @State private var showsPreferences = false
    @State private var startsAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Text("∞").font(.system(size: 38, weight: .light))
                VStack(alignment: .leading, spacing: 3) {
                    Text("RewriteBar")
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                    Text("Your words. A little clearer.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 28).padding(.top, 18).padding(.bottom, 22)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("INTENSITY")
                        HStack {
                            Text("Default level").fontWeight(.medium)
                            Spacer()
                            Text("\(store.defaultIntensity) / 10")
                                .monospacedDigit().foregroundStyle(.secondary)
                        }
                        GlassyIntensitySlider(value: Binding(
                            get: { Double(store.defaultIntensity) },
                            set: { store.defaultIntensity = Int($0.rounded()) }
                        ))
                        .accessibilityLabel("Default rewrite intensity")
                        HStack {
                            Text("Proofread")
                            Spacer()
                            Text("Rephrase")
                        }
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                        .padding(.top, -10)
                        Text(RewriteIntensityPolicy.definition(for: store.defaultIntensity))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("The menu bar changes the level until you quit or choose Use default.")
                            .font(.system(size: 10)).foregroundStyle(.tertiary)
                    }
                    Divider().opacity(0.6)
                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("SHORTCUT")
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Rewrite selected text").fontWeight(.medium)
                                Text("Select. Press. Keep writing.")
                                    .font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            ShortcutRecorderView(shortcut: $store.keyboardShortcut)
                                .frame(width: 112, height: 28)
                        }
                        if let error = store.shortcutRegistrationError {
                            Text(error).font(.caption).foregroundStyle(.secondary)
                        }
                        if !accessibility.isGranted {
                            HStack {
                                Text("Allow RewriteBar to replace your selection.")
                                    .font(.system(size: 11)).foregroundStyle(.secondary)
                                Spacer()
                                Button("Allow Access") { accessibility.beginSetup() }
                                    .help("Open macOS Accessibility settings")
                            }
                            .id(presentation.accessibilitySetupEmphasis)
                        } else {
                            Label("Ready in compatible text fields", systemImage: "checkmark")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    Divider().opacity(0.6)
                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("ACCOUNT")
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Codex").fontWeight(.medium)
                                Text(codexAccount.statusText)
                                    .font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if codexAccount.canConnect {
                                Button("Connect") { codexAccount.connect() }
                            } else if codexAccount.isConnected {
                                Menu {
                                    Button("Refresh connection") { codexAccount.refresh() }
                                    Button("Disconnect") { codexAccount.disconnect() }
                                } label: {
                                    Image(systemName: "checkmark.circle")
                                }
                                .menuStyle(.borderlessButton).frame(width: 28)
                                .accessibilityLabel("Codex account options")
                            } else {
                                Button("Check again") { codexAccount.refresh() }
                                    .disabled(codexAccount.state == .checking || codexAccount.state == .connecting)
                            }
                        }
                        Text("Rewrites use your ChatGPT subscription. Selected text and enabled writing preferences are sent to OpenAI only when you press the shortcut. Internet required.")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Divider().opacity(0.6)
                    DisclosureGroup("Writing preferences", isExpanded: $showsPreferences) {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Style", selection: $store.writingStyle) {
                                ForEach(RewriteStyle.allCases) { Text($0.displayName).tag($0) }
                            }
                            Text(store.writingStyle.explanation)
                                .font(.caption).foregroundStyle(.secondary)
                            Toggle("Custom instructions", isOn: $store.customInstructionsEnabled)
                            if store.customInstructionsEnabled {
                                TextEditor(text: $instructionsDraft)
                                    .font(.system(size: 12))
                                    .frame(height: 82)
                                    .padding(6)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 6))
                                    .overlay(alignment: .topLeading) {
                                        if instructionsDraft.isEmpty {
                                            Text("Keep my sentences short and direct.")
                                                .font(.system(size: 12)).foregroundStyle(.tertiary)
                                                .padding(11).allowsHitTesting(false)
                                        }
                                    }
                                    .accessibilityLabel("Custom rewrite instructions")
                                    .onChange(of: instructionsDraft) { _, value in
                                        let bounded = String(value.prefix(RewriteSettingsStore.maximumInstructionLength))
                                        if bounded != value { instructionsDraft = bounded }
                                        store.saveCustomInstructions(bounded)
                                    }
                                Toggle("Use these instead of the selected style", isOn: $store.customInstructionsExclusive)
                                    .font(.system(size: 11))
                                Text("Your meaning, facts, language, and selected intensity always come first.")
                                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                            }
                        }.padding(.top, 12)
                    }
                    .font(.system(size: 12, weight: .medium))
                    Toggle("Open at login", isOn: $startsAtLogin)
                        .onChange(of: startsAtLogin) { _, enabled in
                            do {
                                if enabled { try SMAppService.mainApp.register() }
                                else { try SMAppService.mainApp.unregister() }
                                loginError = nil
                            } catch {
                                loginError = "Could not change login settings. Try again."
                                startsAtLogin = SMAppService.mainApp.status == .enabled
                            }
                        }
                    if let loginError { Text(loginError).font(.caption) }
                }
                .padding(.horizontal, 28).padding(.bottom, 20)
            }
            HStack {
                Button("Restore defaults") {
                    store.resetAll()
                    instructionsDraft = store.customInstructions
                }.buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Text("Saved automatically").foregroundStyle(.tertiary)
            }
            .font(.system(size: 10)).padding(.horizontal, 28).padding(.vertical, 14)
        }
        .font(.system(size: 12))
        .controlSize(.small)
        .tint(colorScheme == .dark ? Color.white.opacity(0.65) : AppPalette.graphite)
        .background { AppGlassBackground(neutralSurfaceOpacity: 0.90) }
        .frame(width: 460, height: 620)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibility.refresh()
        }
        .task {
            codexAccount.refresh()
            accessibility.refresh()
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.system(size: 9, weight: .semibold)).tracking(1.4)
            .foregroundStyle(.tertiary)
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
