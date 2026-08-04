import AppKit
import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: RewriteViewModel
    var close: () -> Void = {}
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
                        if viewModel.perform() {
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
                        if viewModel.restorePreviousClipboard() {
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
            }
        }
        .padding(16)
        .frame(width: 292)
        .background { glassBackground }
        .tint(AppPalette.accent)
        .onAppear {
            viewModel.popoverOpened()
        }
        .onDisappear {
            viewModel.popoverClosed()
        }
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.86),
            value: viewModel.state
        )
    }

    private var glassBackground: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            RadialGradient(
                colors: [
                    .white.opacity(0.20),
                    AppPalette.silver.opacity(0.10),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 250
            )

            LinearGradient(
                colors: [
                    AppPalette.frost.opacity(0.08),
                    AppPalette.graphite.opacity(0.05),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [.white.opacity(0.15), .clear],
                startPoint: .top,
                endPoint: .center
            )
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.24))
                .frame(height: 1)
        }
        .ignoresSafeArea()
    }
}
