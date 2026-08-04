import AppKit
import OSLog
import RewriteCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(
        subsystem: AppConstants.bundleIdentifier,
        category: "Lifecycle"
    )
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        logger.notice("Application launched")
    }
}

@main
struct RewriteBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = RewriteViewModel()

    init() {
        Task.detached(priority: .utility) {
            await LocalModelService.shared.warmUp()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(viewModel: viewModel)
        } label: {
            Image(systemName: "infinity")
                .accessibilityLabel("RewriteBar")
        }
        .menuBarExtraStyle(.window)
    }
}
