import AppKit
import RewriteCore
import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: RewriteViewModel
    var close: () -> Void = {}
    var openSettings: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            GlassyIntensitySlider(
                value: $viewModel.intensity,
                loadingProgress: viewModel.isWorking ? viewModel.rewriteProgress : nil
            )
                .disabled(viewModel.isWorking || viewModel.isConfirmation)
                .opacity(viewModel.isConfirmation ? 0.72 : 1)

            ZStack(alignment: .leading) {
                PrimaryActionButton(
                    title: viewModel.title,
                    symbol: viewModel.symbol,
                    isWorking: viewModel.isWorking,
                    accessibilityHint: viewModel.accessibilityHint,
                    action: {
                        let succeeded = viewModel.perform()
                        if PopoverActionRouter.shouldClosePopover(
                            after: .primary,
                            succeeded: succeeded
                        ) {
                            close()
                        }
                    }
                )
                .disabled(!viewModel.isEnabled)
                .opacity(viewModel.isEnabled || viewModel.isConfirmation ? 1 : 0.52)

                if viewModel.canRestorePreviousClipboard
                    && !viewModel.isWorking
                    && !viewModel.isConfirmation {
                    Button {
                        let succeeded = viewModel.restorePreviousClipboard()
                        if PopoverActionRouter.shouldClosePopover(
                            after: .restore,
                            succeeded: succeeded
                        ) {
                            close()
                        }
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppPalette.deepGraphite.opacity(0.36))
                            .frame(width: 26, height: 26)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Restore previous clipboard text")
                    .accessibilityLabel("Restore previous clipboard text")
                    .padding(.leading, 8)
                }

                if !viewModel.isWorking && !viewModel.isConfirmation {
                    HStack {
                        Spacer()

                        Button(action: openSettings) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(AppPalette.deepGraphite.opacity(0.34))
                                .frame(width: 26, height: 26)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(",", modifiers: .command)
                        .help("Open Settings")
                        .accessibilityLabel("Open Settings")
                        .padding(.trailing, 8)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 292)
        .background { AppGlassBackground() }
        .tint(AppPalette.accent)
        .task(id: viewModel.state) {
            let completionAction: PopoverAction
            switch viewModel.state {
            case .copied:
                completionAction = .automaticRewrite
            case .restored:
                completionAction = .automaticRecovery
            default:
                return
            }

            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled,
                  viewModel.isConfirmation,
                  PopoverActionRouter.shouldClosePopover(
                      after: completionAction,
                      succeeded: true
                  ) else {
                return
            }
            close()
        }
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.86),
            value: viewModel.state
        )
    }

}
