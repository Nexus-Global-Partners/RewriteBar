import AppKit
import SwiftUI

@MainActor
final class SettingsPresentationModel: ObservableObject {
    @Published private(set) var accessibilitySetupEmphasis = 0

    func emphasizeAccessibilitySetup() {
        accessibilitySetupEmphasis += 1
    }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private let presentation: SettingsPresentationModel

    private init(store: RewriteSettingsStore = .shared) {
        let presentation = SettingsPresentationModel()
        self.presentation = presentation

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 590),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "RewriteBar Settings"
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unifiedCompact
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("RewriteBar.SettingsWindow")
        window.contentViewController = NSHostingController(
            rootView: SettingsView(
                store: store,
                presentation: presentation
            )
        )

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(emphasizeAccessibilitySetup: Bool = false) {
        guard let window else { return }
        NSApp.setActivationPolicy(.regular)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if emphasizeAccessibilitySetup {
            Task { @MainActor [weak self] in
                await Task.yield()
                self?.presentation.emphasizeAccessibilitySetup()
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
