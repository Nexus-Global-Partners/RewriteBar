import AppKit
import Carbon.HIToolbox
import Foundation
import RewriteCore

extension GlobalShortcut {
    var displayName: String {
        modifiers.displayGlyphs + Self.keyLabel(for: keyCode)
    }

    init(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
        var converted: Modifiers = []
        if modifierFlags.contains(.command) { converted.insert(.command) }
        if modifierFlags.contains(.control) { converted.insert(.control) }
        if modifierFlags.contains(.option) { converted.insert(.option) }
        if modifierFlags.contains(.shift) { converted.insert(.shift) }
        self.init(keyCode: UInt32(keyCode), modifiers: converted)
    }

    private static func keyLabel(for keyCode: UInt32) -> String {
        switch keyCode {
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "Space"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
                  let data = TISGetInputSourceProperty(
                    source,
                    kTISPropertyUnicodeKeyLayoutData
                  ) else {
                return "Key \(keyCode)"
            }
            let layoutData = unsafeBitCast(data, to: CFData.self) as Data
            return layoutData.withUnsafeBytes { bytes in
                guard let layout = bytes.baseAddress?
                    .assumingMemoryBound(to: UCKeyboardLayout.self) else {
                    return "Key \(keyCode)"
                }
                var deadKeyState: UInt32 = 0
                var length = 0
                var characters = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(
                    layout,
                    UInt16(keyCode),
                    UInt16(kUCKeyActionDisplay),
                    0,
                    UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysBit),
                    &deadKeyState,
                    characters.count,
                    &length,
                    &characters
                )
                guard status == noErr, length > 0 else { return "Key \(keyCode)" }
                return String(utf16CodeUnits: characters, count: length).uppercased()
            }
        }
    }
}

private extension GlobalShortcut.Modifiers {
    var displayGlyphs: String {
        var result = ""
        if contains(.control) { result += "⌃" }
        if contains(.option) { result += "⌥" }
        if contains(.shift) { result += "⇧" }
        if contains(.command) { result += "⌘" }
        return result
    }
}

@MainActor
final class RewriteSettingsStore: ObservableObject {
    static let shared = RewriteSettingsStore()

    enum Key {
        static let defaultIntensity = "settings.defaultIntensity"
        static let writingStyle = "settings.writingStyle"
        static let keyboardShortcut = "settings.keyboardShortcut"
        static let customInstructionsEnabled = "settings.customInstructionsEnabled"
        static let customInstructions = "settings.customInstructions"
    }

    static let maximumInstructionLength = RewriteCustomInstructionsPolicy.maximumCharacters

    @Published var defaultIntensity: Int {
        didSet {
            let clamped = min(10, max(0, defaultIntensity))
            guard defaultIntensity == clamped else {
                defaultIntensity = clamped
                return
            }
            defaults.set(defaultIntensity, forKey: Key.defaultIntensity)
        }
    }

    @Published var writingStyle: RewriteStyle {
        didSet { defaults.set(writingStyle.rawValue, forKey: Key.writingStyle) }
    }

    @Published var keyboardShortcut: GlobalShortcut? {
        didSet { persistKeyboardShortcut() }
    }

    @Published var customInstructionsEnabled: Bool {
        didSet { defaults.set(customInstructionsEnabled, forKey: Key.customInstructionsEnabled) }
    }

    @Published private(set) var customInstructions: String
    @Published private(set) var shortcutRegistrationError: String?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults.object(forKey: Key.defaultIntensity) == nil {
            defaultIntensity = 3
        } else {
            defaultIntensity = min(10, max(0, defaults.integer(forKey: Key.defaultIntensity)))
        }

        writingStyle = defaults.string(forKey: Key.writingStyle)
            .flatMap(RewriteStyle.init(rawValue:))
            ?? .rewriteBar

        if let data = defaults.data(forKey: Key.keyboardShortcut),
           let shortcut = try? JSONDecoder().decode(GlobalShortcut.self, from: data) {
            keyboardShortcut = shortcut
        } else if defaults.object(forKey: Key.keyboardShortcut) == nil {
            keyboardShortcut = .rewriteDefault
        } else {
            keyboardShortcut = nil
        }

        customInstructionsEnabled = defaults.bool(forKey: Key.customInstructionsEnabled)
        customInstructions = defaults.string(forKey: Key.customInstructions) ?? ""
        shortcutRegistrationError = nil
    }

    func saveCustomInstructions(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        customInstructions = String(trimmed.prefix(Self.maximumInstructionLength))
        defaults.set(customInstructions, forKey: Key.customInstructions)
    }

    func resetCustomInstructions() {
        customInstructions = ""
        customInstructionsEnabled = false
        defaults.removeObject(forKey: Key.customInstructions)
    }

    func resetAll() {
        defaultIntensity = 3
        writingStyle = .rewriteBar
        keyboardShortcut = .rewriteDefault
        resetCustomInstructions()
    }

    func reportShortcutRegistrationError(_ message: String?) {
        shortcutRegistrationError = message
    }

    private func persistKeyboardShortcut() {
        guard let keyboardShortcut else {
            // Keep a marker so a deliberately disabled shortcut remains disabled on relaunch.
            defaults.set(Data(), forKey: Key.keyboardShortcut)
            return
        }

        if let data = try? JSONEncoder().encode(keyboardShortcut) {
            defaults.set(data, forKey: Key.keyboardShortcut)
        }
    }
}
