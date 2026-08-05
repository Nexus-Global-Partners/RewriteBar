import AppKit
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
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var previouslyActiveApplication: NSRunningApplication?
    private var restoresFocusAfterClose = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configurePopover()
        configureStatusItem()
        logger.notice("Application launched")
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
        statusItem = item
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
