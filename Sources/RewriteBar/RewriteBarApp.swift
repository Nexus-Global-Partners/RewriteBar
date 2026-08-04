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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configurePopover()
        configureStatusItem()
        logger.notice("Application launched")
    }

    func popoverDidClose(_ notification: Notification) {
        viewModel.popoverClosed()
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
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
                    self?.popover.performClose(nil)
                }
            )
        )
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
