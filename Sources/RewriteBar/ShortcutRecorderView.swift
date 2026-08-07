import AppKit
import SwiftUI

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var shortcut: GlobalShortcut?

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.onChange = { shortcut = $0 }
        button.shortcut = shortcut
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        button.onChange = { shortcut = $0 }
        if !button.isRecording {
            button.shortcut = shortcut
        }
    }
}

final class ShortcutRecorderButton: NSButton {
    var onChange: ((GlobalShortcut?) -> Void)?
    var shortcut: GlobalShortcut? {
        didSet { updatePresentation() }
    }
    private(set) var isRecording = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        controlSize = .regular
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(beginRecording)
        toolTip = "Click, then press a keyboard shortcut. Press Delete to disable it."
        setAccessibilityLabel("Rewrite keyboard shortcut")
        setAccessibilityHelp("Click, then press the keyboard shortcut you want to use.")
        updatePresentation()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned && isRecording {
            isRecording = false
            updatePresentation()
        }
        return resigned
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 {
            finishRecording(with: shortcut)
            return
        }

        if event.keyCode == 51 || event.keyCode == 117 {
            finishRecording(with: nil)
            return
        }

        let modifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
        guard modifiers.contains(.command)
                || modifiers.contains(.control)
                || modifiers.contains(.option) else {
            NSSound.beep()
            return
        }

        guard let keyLabel = Self.keyLabel(for: event), !keyLabel.isEmpty else {
            NSSound.beep()
            return
        }

        finishRecording(
            with: GlobalShortcut(keyCode: event.keyCode, modifierFlags: modifiers)
        )
    }

    @objc private func beginRecording() {
        isRecording = true
        window?.makeFirstResponder(self)
        updatePresentation()
    }

    private func finishRecording(with value: GlobalShortcut?) {
        isRecording = false
        shortcut = value
        onChange?(value)
        window?.makeFirstResponder(nil)
    }

    private func updatePresentation() {
        title = isRecording ? "Type shortcut" : (shortcut?.displayName ?? "Not set")
        font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        contentTintColor = isRecording ? .controlAccentColor : .labelColor
        setAccessibilityValue(shortcut?.displayName ?? "Not set")
    }

    private static func keyLabel(for event: NSEvent) -> String? {
        switch event.keyCode {
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "Space"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            return event.charactersIgnoringModifiers?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
        }
    }
}
