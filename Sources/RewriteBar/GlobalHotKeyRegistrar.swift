import Carbon.HIToolbox
import Foundation

struct GlobalShortcut: Codable, Equatable, Sendable {
    struct Modifiers: OptionSet, Codable, Equatable, Sendable {
        let rawValue: UInt32

        static let command = Modifiers(rawValue: 1 << 0)
        static let control = Modifiers(rawValue: 1 << 1)
        static let option = Modifiers(rawValue: 1 << 2)
        static let shift = Modifiers(rawValue: 1 << 3)
    }

    let keyCode: UInt32
    let modifiers: Modifiers

    static let rewriteDefault = GlobalShortcut(
        keyCode: UInt32(kVK_ANSI_R),
        modifiers: [.control, .option]
    )

    fileprivate var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) {
            result |= UInt32(cmdKey)
        }
        if modifiers.contains(.control) {
            result |= UInt32(controlKey)
        }
        if modifiers.contains(.option) {
            result |= UInt32(optionKey)
        }
        if modifiers.contains(.shift) {
            result |= UInt32(shiftKey)
        }
        return result
    }

    fileprivate var isValid: Bool {
        !modifiers.intersection([.command, .control, .option]).isEmpty
    }
}

final class GlobalHotKeyRegistrar: @unchecked Sendable {
    private static let signature: OSType = 0x52574252
    private static let identifier: UInt32 = 1

    private var eventHandlerReference: EventHandlerRef?
    private var hotKeyReference: EventHotKeyRef?
    private var handler: (@MainActor () -> Void)?

    deinit {
        if let hotKeyReference {
            UnregisterEventHotKey(hotKeyReference)
        }
        if let eventHandlerReference {
            RemoveEventHandler(eventHandlerReference)
        }
    }

    @MainActor
    func register(
        _ shortcut: GlobalShortcut,
        handler: @escaping @MainActor () -> Void
    ) throws {
        guard shortcut.isValid else {
            throw AccessibilityRewriteFailure.invalidShortcut
        }

        unregister()
        try installEventHandlerIfNeeded()
        self.handler = handler

        let hotKeyID = EventHotKeyID(
            signature: Self.signature,
            id: Self.identifier
        )
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr else {
            self.handler = nil
            if status == eventHotKeyExistsErr {
                throw AccessibilityRewriteFailure.shortcutConflict
            }
            throw AccessibilityRewriteFailure.shortcutRegistrationFailed(status)
        }
        hotKeyReference = reference
    }

    @MainActor
    func unregister() {
        if let hotKeyReference {
            UnregisterEventHotKey(hotKeyReference)
            self.hotKeyReference = nil
        }
        handler = nil
    }

    @MainActor
    private func installEventHandlerIfNeeded() throws {
        guard eventHandlerReference == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            rewriteBarHotKeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerReference
        )
        guard status == noErr else {
            throw AccessibilityRewriteFailure.shortcutRegistrationFailed(status)
        }
    }

    @MainActor
    fileprivate func receiveHotKeyEvent(_ hotKeyID: EventHotKeyID) {
        guard hotKeyID.signature == Self.signature,
              hotKeyID.id == Self.identifier else {
            return
        }
        handler?()
    }
}

private func rewriteBarHotKeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else {
        return OSStatus(eventNotHandledErr)
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }

    let registrar = Unmanaged<GlobalHotKeyRegistrar>
        .fromOpaque(userData)
        .takeUnretainedValue()
    Task { @MainActor in
        registrar.receiveHotKeyEvent(hotKeyID)
    }
    return noErr
}
