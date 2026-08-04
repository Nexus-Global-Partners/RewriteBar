import SwiftUI

struct GlassyIntensitySlider: View {
    @Binding var value: Double
    let onEditingChanged: (Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool
    @State private var isDragging = false

    private let range = 0.0...10.0
    private let thumbSize: CGFloat = 26
    private let focusedThumbScale: CGFloat = 1.08
    private let endpointPadding: CGFloat = 8

    init(
        value: Binding<Double>,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        _value = value
        self.onEditingChanged = onEditingChanged
    }

    var body: some View {
        GeometryReader { geometry in
            let thumbFootprint = thumbSize * focusedThumbScale
            let thumbInset = (thumbFootprint - thumbSize) / 2
            let contentWidth = max(1, geometry.size.width - endpointPadding * 2)
            let availableWidth = max(1, contentWidth - thumbFootprint)
            let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let progressWidth = availableWidth * progress
            let thumbOffset = endpointPadding + thumbInset + progressWidth

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppPalette.silver.opacity(0.07),
                                        .white.opacity(0.12),
                                        AppPalette.silver.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.white.opacity(0.44), lineWidth: 0.7)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.white.opacity(0.44), lineWidth: 2.5)
                            .blur(radius: 2)
                            .offset(x: -1, y: -1)
                            .mask {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                            }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(AppPalette.graphite.opacity(0.055), lineWidth: 2.5)
                            .blur(radius: 2.2)
                            .offset(x: 1, y: 1)
                            .mask {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                            }
                    }

                Capsule(style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(AppPalette.graphite.opacity(0.018))
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(AppPalette.graphite.opacity(0.10), lineWidth: 2)
                            .blur(radius: 1.3)
                            .offset(x: 0.6, y: 0.6)
                            .mask { Capsule(style: .continuous) }
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(.white.opacity(0.58), lineWidth: 2)
                            .blur(radius: 1)
                            .offset(x: -0.6, y: -0.6)
                            .mask { Capsule(style: .continuous) }
                    }
                    .frame(height: 12)
                    .padding(.horizontal, endpointPadding + thumbFootprint / 2)

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppPalette.frost,
                                AppPalette.silver,
                                AppPalette.steel
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(0.78)
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(.white.opacity(0.52))
                            .frame(height: 1)
                    }
                    .overlay(alignment: .bottom) {
                        Capsule()
                            .fill(AppPalette.graphite.opacity(0.10))
                            .frame(height: 1)
                    }
                    .frame(width: max(6, progressWidth), height: 8)
                    .padding(.leading, endpointPadding + thumbFootprint / 2)

                ZStack {
                    Circle()
                        .fill(.white)
                    Circle()
                        .strokeBorder(.white.opacity(0.76), lineWidth: 0.7)
                    Circle()
                        .strokeBorder(.white.opacity(0.58), lineWidth: 2.4)
                        .blur(radius: 1.2)
                        .offset(x: -0.7, y: -0.7)
                        .mask { Circle() }
                    Circle()
                        .strokeBorder(AppPalette.graphite.opacity(0.10), lineWidth: 2.4)
                        .blur(radius: 1.2)
                        .offset(x: 0.7, y: 0.7)
                        .mask { Circle() }
                    Circle()
                        .strokeBorder(AppPalette.graphite.opacity(0.06), lineWidth: 0.7)
                        .padding(1.2)

                    Text("\(Int(value.rounded()))")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppPalette.deepGraphite.opacity(0.96))
                }
                .frame(width: thumbSize, height: thumbSize)
                .scaleEffect(isFocused ? focusedThumbScale : 1)
                .offset(x: thumbOffset)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged(true)
                        }
                        updateValue(at: gesture.location.x, width: geometry.size.width)
                    }
                    .onEnded { gesture in
                        updateValue(at: gesture.location.x, width: geometry.size.width)
                        isDragging = false
                        onEditingChanged(false)
                    }
            )
            .focusable()
            .focusEffectDisabled()
            .focused($isFocused)
            .onKeyPress(.leftArrow) {
                commitAdjustment(by: -1)
                return .handled
            }
            .onKeyPress(.rightArrow) {
                commitAdjustment(by: 1)
                return .handled
            }
            .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.78), value: value)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isFocused)
        }
        .frame(height: 34)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rewrite intensity")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Use the arrow keys to choose a level from zero to ten.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: commitAdjustment(by: 1)
            case .decrement: commitAdjustment(by: -1)
            @unknown default: break
            }
        }
    }

    private var accessibilityValue: String {
        let level = Int(value.rounded())
        let description: String
        switch level {
        case 0: description = "essential corrections only"
        case 1...3: description = "light improvement"
        case 4...6: description = "moderate rewrite"
        case 7...9: description = "substantial rewrite"
        default: description = "strongest polished rewrite"
        }
        return "Level \(level) of 10, \(description)"
    }

    private func updateValue(at xPosition: CGFloat, width: CGFloat) {
        let thumbFootprint = thumbSize * focusedThumbScale
        let contentWidth = max(1, width - endpointPadding * 2)
        let availableWidth = max(1, contentWidth - thumbFootprint)
        let adjusted = min(
            availableWidth,
            max(0, xPosition - endpointPadding - thumbFootprint / 2)
        )
        let newValue = Double(adjusted / availableWidth) * 10
        value = newValue.rounded()
    }

    private func adjust(by amount: Double) {
        value = min(range.upperBound, max(range.lowerBound, value + amount))
    }

    private func commitAdjustment(by amount: Double) {
        onEditingChanged(true)
        adjust(by: amount)
        onEditingChanged(false)
    }
}
