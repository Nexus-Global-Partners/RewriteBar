import AppKit
import Combine
import OSLog
import QuartzCore
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
    private var statusProgressIndicator: MenuBarProgressIndicator?
    private var previouslyActiveApplication: NSRunningApplication?
    private var restoresFocusAfterClose = false
    private var shortcutSettingsObservation: AnyCancellable?
    private var shortcutRecordingBeginObservation: AnyCancellable?
    private var shortcutRecordingEndObservation: AnyCancellable?
    private var codexAccountObservation: AnyCancellable?
    private var previousCodexAccountState: CodexAccountController.State = .idle
    private var statusFeedbackTask: Task<Void, Never>?
    private var accessibilityRecovery = AccessibilityPermissionRecoveryState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configurePopover()
        configureStatusItem()
        configureShortcutFlow()
        configureCodexConnectionFeedback()
        logger.notice("Application launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyRegistrar.unregister()
        statusFeedbackTask?.cancel()
        let shutdownFinished = DispatchSemaphore(value: 0)
        Task.detached {
            await CodexAppServerClient.shared.shutdown()
            shutdownFinished.signal()
        }
        _ = shutdownFinished.wait(timeout: .now() + 0.5)
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

        let progressIndicator = MenuBarProgressIndicator()
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(progressIndicator)
        NSLayoutConstraint.activate([
            progressIndicator.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            progressIndicator.widthAnchor.constraint(equalToConstant: 14),
            progressIndicator.heightAnchor.constraint(equalToConstant: 14)
        ])

        statusProgressIndicator = progressIndicator
        statusItem = item
    }

    private func configureShortcutFlow() {
        shortcutCoordinator.onCompletion = { [weak self] output in
            guard let self else { return }
            clipboard.writePlainText(output)
            logger.notice("Shortcut selection replaced and copied")
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

        shortcutRecordingBeginObservation = NotificationCenter.default
            .publisher(for: .rewriteBarShortcutRecordingDidBegin)
            .sink { [weak self] _ in
                self?.hotKeyRegistrar.unregister()
            }
        shortcutRecordingEndObservation = NotificationCenter.default
            .publisher(for: .rewriteBarShortcutRecordingDidEnd)
            .sink { [weak self] _ in
                guard let self else { return }
                registerGlobalShortcut(settings.keyboardShortcut)
            }
    }

    private func configureCodexConnectionFeedback() {
        codexAccountObservation = CodexAccountController.shared.$state
            .removeDuplicates()
            .sink { [weak self] state in
                guard let self else { return }
                let previousState = previousCodexAccountState
                previousCodexAccountState = state
                guard CodexConnectionFeedbackPolicy.showsConfirmation(
                    previous: previousState,
                    current: state
                ), !shortcutCoordinator.isRewriting else {
                    return
                }
                NSHapticFeedbackManager.defaultPerformer.perform(
                    .alignment,
                    performanceTime: .now
                )
                showTemporaryStatus(
                    title: "✓",
                    toolTip: "Codex connected",
                    duration: .seconds(2),
                    resetsShortcutState: false
                )
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
        showStatusProgress(toolTip: "Rewriting selected text")
        shortcutCoordinator.startRewrite(
            intensity: settings.defaultIntensity,
            writingStyle: settings.writingStyle,
            customInstructions: settings.customInstructionsEnabled
                ? settings.customInstructions
                : nil,
            customInstructionsExclusive: settings.customInstructionsExclusive,
            provider: settings.rewriteProvider,
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
        logger.error(
            "Shortcut rewrite unavailable: \(failure.localizedDescription, privacy: .public)"
        )
        showTemporaryStatus(
            title: ShortcutFailureFeedbackPolicy.title(for: failure),
            toolTip: failure.localizedDescription,
            duration: .seconds(3),
            length: NSStatusItem.variableLength
        )

        if failure == .permissionRequired {
            if accessibilityRecovery.shouldBeginSetup(for: failure) {
                AccessibilityPermission.beginSetup()
            }
            SettingsWindowController.shared.show(
                emphasizeAccessibilitySetup: true
            )
        }
    }

    private func showTemporaryStatus(
        title: String,
        toolTip: String,
        duration: Duration,
        length: CGFloat = NSStatusItem.squareLength,
        resetsShortcutState: Bool = true
    ) {
        statusFeedbackTask?.cancel()
        showStatusItem(title: title, toolTip: toolTip, length: length)
        statusFeedbackTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled, let self else { return }
            showStatusItem(title: "∞", toolTip: "RewriteBar")
            if resetsShortcutState {
                shortcutCoordinator.resetState()
            }
            statusFeedbackTask = nil
        }
    }

    private func showStatusItem(
        title: String,
        toolTip: String,
        length: CGFloat = NSStatusItem.squareLength
    ) {
        guard let statusItem, let button = statusItem.button else { return }
        statusItem.length = length
        statusProgressIndicator?.stopAnimation(nil)
        button.title = title
        button.toolTip = toolTip
        button.setAccessibilityLabel(toolTip)
    }

    private func showStatusProgress(toolTip: String) {
        guard let statusItem, let button = statusItem.button else { return }
        statusItem.length = NSStatusItem.squareLength
        button.title = ""
        button.toolTip = toolTip
        button.setAccessibilityLabel(toolTip)
        statusProgressIndicator?.startAnimation(nil)
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

final class MenuBarProgressIndicator: NSView {
    private let arcLayer = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        isHidden = true

        arcLayer.fillColor = NSColor.clear.cgColor
        arcLayer.strokeColor = NSColor.white.cgColor
        arcLayer.lineWidth = 1.8
        arcLayer.lineCap = .round
        arcLayer.strokeStart = 0.08
        arcLayer.strokeEnd = 0.78
        layer?.addSublayer(arcLayer)
    }

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        arcLayer.frame = bounds
        arcLayer.path = CGPath(
            ellipseIn: bounds.insetBy(dx: 1.4, dy: 1.4),
            transform: nil
        )
    }

    func startAnimation(_ sender: Any?) {
        isHidden = false
        arcLayer.removeAnimation(forKey: "rotation")
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            return
        }

        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = Double.pi * 2
        rotation.duration = 0.75
        rotation.repeatCount = .infinity
        rotation.timingFunction = CAMediaTimingFunction(name: .linear)
        arcLayer.add(rotation, forKey: "rotation")
    }

    func stopAnimation(_ sender: Any?) {
        arcLayer.removeAnimation(forKey: "rotation")
        isHidden = true
    }
}

enum CodexConnectionFeedbackPolicy {
    static func showsConfirmation(
        previous: CodexAccountController.State,
        current: CodexAccountController.State
    ) -> Bool {
        guard case .connecting = previous,
              case .connected(_, true, _) = current else {
            return false
        }
        return true
    }
}

enum ShortcutFailureFeedbackPolicy {
    static func title(for failure: AccessibilityRewriteFailure) -> String {
        switch failure {
        case .permissionRequired:
            return "Set Up"
        case .noFocusedApplication, .noFocusedElement, .selectionEmpty:
            return "Select text"
        case .secureField:
            return "Secure field"
        case .selectionUnavailable, .selectionNotEditable:
            return "Not editable"
        case .multipleSelectionsUnsupported:
            return "One selection"
        case .focusChanged, .selectionChanged:
            return "Selection changed"
        case .rewriteAlreadyRunning:
            return "Working"
        case .invalidShortcut, .shortcutConflict, .shortcutRegistrationFailed:
            return "Shortcut error"
        case .accessibilityFailure:
            return "Accessibility error"
        case .rewriteFailed:
            return "Rewrite failed"
        }
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
