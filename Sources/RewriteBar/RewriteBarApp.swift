import AppKit
import Combine
import OSLog
import RewriteCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let logger = Logger(
        subsystem: AppConstants.bundleIdentifier,
        category: "Lifecycle"
    )
    private let viewModel = RewriteViewModel()
    private let settings = RewriteSettingsStore.shared
    private let clipboard = ClipboardService()
    private let hotKeyRegistrar = GlobalHotKeyRegistrar()
    private let shortcutCoordinator = SelectedTextRewriteCoordinator()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var previouslyActiveApplication: NSRunningApplication?
    private var restoresFocusAfterClose = false
    private var shortcutSettingsObservation: AnyCancellable?
    private var statusFeedbackTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configurePopover()
        configureStatusItem()
        configureShortcutFlow()
        logger.notice("Application launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyRegistrar.unregister()
        statusFeedbackTask?.cancel()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        SettingsWindowController.shared.show()
        return true
    }

    func popoverDidClose(_ notification: Notification) {
        viewModel.popoverClosed()

        let applicationToRestore = restoresFocusAfterClose
            ? previouslyActiveApplication
            : nil
        restoresFocusAfterClose = false
        previouslyActiveApplication = nil

        if let applicationToRestore {
            NSApp.yieldActivation(to: applicationToRestore)
            _ = applicationToRestore.activate(
                from: .current,
                options: []
            )
        }
    }

    func popoverWillShow(_ notification: Notification) {
        viewModel.popoverOpened()
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu(from: sender)
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            rememberActiveApplication()
            popover.show(
                relativeTo: sender.bounds,
                of: sender,
                preferredEdge: .minY
            )
        }
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 292, height: 156)
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(
                viewModel: viewModel,
                close: { [weak self] in
                    self?.closeAfterCompletion()
                },
                openSettings: { [weak self] in
                    self?.openSettings()
                }
            )
        )
    }

    private func rememberActiveApplication() {
        guard let activeApplication = NSWorkspace.shared.frontmostApplication,
              activeApplication.processIdentifier
                != ProcessInfo.processInfo.processIdentifier else {
            previouslyActiveApplication = nil
            return
        }

        previouslyActiveApplication = activeApplication
    }

    private func closeAfterCompletion() {
        guard popover.isShown else { return }
        restoresFocusAfterClose = true
        popover.performClose(nil)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "RewriteBar.StatusItem"
        item.isVisible = true
        guard let button = item.button else { return }

        button.title = "∞"
        button.font = .systemFont(ofSize: 16, weight: .medium)
        button.toolTip = "RewriteBar"
        button.setAccessibilityLabel("RewriteBar")
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
    }

    private func configureShortcutFlow() {
        shortcutCoordinator.onCompletion = { [weak self] output in
            guard let self else { return }
            clipboard.writePlainText(output)
            showShortcutSuccess(replacedSelection: true)
        }
        shortcutCoordinator.onCopyOnlyCompletion = { [weak self] output, failure in
            guard let self else { return }
            clipboard.writePlainText(output)
            logger.notice(
                "Shortcut result copied after replacement was unavailable: \(failure.localizedDescription, privacy: .public)"
            )
            showShortcutSuccess(replacedSelection: false)
        }
        shortcutCoordinator.onFailure = { [weak self] failure in
            self?.showShortcutFailure(failure)
        }

        shortcutSettingsObservation = settings.$keyboardShortcut
            .removeDuplicates()
            .sink { [weak self] shortcut in
                self?.registerGlobalShortcut(shortcut)
            }
    }

    private func registerGlobalShortcut(_ shortcut: GlobalShortcut?) {
        hotKeyRegistrar.unregister()
        settings.reportShortcutRegistrationError(nil)
        guard let shortcut else { return }

        do {
            try hotKeyRegistrar.register(shortcut) { [weak self] in
                self?.startSelectedTextRewrite()
            }
        } catch let failure as AccessibilityRewriteFailure {
            settings.reportShortcutRegistrationError(failure.localizedDescription)
            showShortcutFailure(failure)
        } catch {
            let failure = AccessibilityRewriteFailure.shortcutRegistrationFailed(-1)
            settings.reportShortcutRegistrationError(failure.localizedDescription)
            showShortcutFailure(failure)
        }
    }

    private func startSelectedTextRewrite() {
        guard !shortcutCoordinator.isRewriting else {
            showShortcutFailure(.rewriteAlreadyRunning)
            return
        }

        statusFeedbackTask?.cancel()
        statusFeedbackTask = nil
        showStatusItem(
            title: "◌",
            toolTip: "Rewriting selected text"
        )
        shortcutCoordinator.startRewrite(
            intensity: settings.defaultIntensity,
            writingStyle: settings.writingStyle,
            customInstructions: settings.customInstructionsEnabled
                ? settings.customInstructions
                : nil,
            customInstructionsExclusive: settings.customInstructionsExclusive,
            promptingForPermission: false
        )
    }

    private func showShortcutSuccess(replacedSelection: Bool) {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .now
        )
        showTemporaryStatus(
            title: "✓",
            toolTip: replacedSelection
                ? "Selection rewritten and copied"
                : "Rewrite copied to the clipboard",
            duration: .milliseconds(1_500)
        )
    }

    private func showShortcutFailure(_ failure: AccessibilityRewriteFailure) {
        logger.notice(
            "Shortcut rewrite unavailable: \(failure.localizedDescription, privacy: .public)"
        )
        NSSound.beep()
        showTemporaryStatus(
            title: "!",
            toolTip: failure.localizedDescription,
            duration: .seconds(2)
        )

        if failure == .permissionRequired {
            SettingsWindowController.shared.show(
                emphasizeAccessibilitySetup: true
            )
        }
    }

    private func showTemporaryStatus(
        title: String,
        toolTip: String,
        duration: Duration
    ) {
        statusFeedbackTask?.cancel()
        showStatusItem(title: title, toolTip: toolTip)
        statusFeedbackTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled, let self else { return }
            showStatusItem(title: "∞", toolTip: "RewriteBar")
            shortcutCoordinator.resetState()
            statusFeedbackTask = nil
        }
    }

    private func showStatusItem(title: String, toolTip: String) {
        guard let button = statusItem?.button else { return }
        button.title = title
        button.toolTip = toolTip
        button.setAccessibilityLabel(toolTip)
    }

    private func showStatusMenu(from button: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        let menu = NSMenu()

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(
            title: "About RewriteBar",
            action: #selector(openAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit RewriteBar",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        NSMenu.popUpContextMenu(menu, with: event, for: button)
    }

    @objc private func openSettings() {
        if popover.isShown {
            popover.performClose(nil)
        }
        SettingsWindowController.shared.show()
    }

    @objc private func openAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }
}

@main
struct RewriteBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        Task.detached(priority: .userInitiated) {
            await LocalModelService.shared.warmUp()
        }
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
