import ApplicationServices
import Foundation

@MainActor
protocol EditableTextSelection: AnyObject {
    var originalText: String { get }
    func replaceSelection(with replacement: String) throws
}

@MainActor
protocol EditableTextSelectionProviding: AnyObject {
    func captureSelection(
        promptingForPermission: Bool
    ) throws -> any EditableTextSelection
}

enum AccessibilityPermission {
    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestIfNeeded() -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

@MainActor
final class AccessibilitySelectionClient {
    func captureFocusedSelection(
        promptingForPermission: Bool = false
    ) throws -> AccessibilitySelectionSnapshot {
        let trusted = promptingForPermission
            ? AccessibilityPermission.requestIfNeeded()
            : AccessibilityPermission.isGranted
        guard trusted else {
            throw AccessibilityRewriteFailure.permissionRequired
        }

        let focused = try focusedContext()
        try refuseSecureField(focused.element)
        try refuseMultipleSelections(focused.element)

        let selectedText = try selectedText(from: focused.element)
        let selectedRange = try selectedTextRange(from: focused.element)
        guard selectedRange.length > 0, !selectedText.isEmpty else {
            throw AccessibilityRewriteFailure.selectionEmpty
        }

        var isSettable = DarwinBoolean(false)
        let settableStatus = AXUIElementIsAttributeSettable(
            focused.element,
            kAXSelectedTextAttribute as CFString,
            &isSettable
        )
        try check(
            settableStatus,
            unavailableAs: .selectionNotEditable
        )
        guard isSettable.boolValue else {
            throw AccessibilityRewriteFailure.selectionNotEditable
        }

        return AccessibilitySelectionSnapshot(
            client: self,
            application: focused.application,
            element: focused.element,
            processIdentifier: focused.processIdentifier,
            originalText: selectedText,
            originalRange: selectedRange
        )
    }

    fileprivate func replace(
        snapshot: AccessibilitySelectionSnapshot,
        with replacement: String
    ) throws {
        guard AccessibilityPermission.isGranted else {
            throw AccessibilityRewriteFailure.permissionRequired
        }

        let focused = try focusedContext()
        guard focused.processIdentifier == snapshot.processIdentifier,
              CFEqual(focused.application, snapshot.application) else {
            throw AccessibilityRewriteFailure.focusChanged
        }
        guard CFEqual(focused.element, snapshot.element) else {
            throw AccessibilityRewriteFailure.focusChanged
        }

        try refuseSecureField(focused.element)

        let currentRange = try selectedTextRange(from: focused.element)
        let currentText = try selectedText(from: focused.element)
        guard currentRange.location == snapshot.originalRange.location,
              currentRange.length == snapshot.originalRange.length,
              currentText == snapshot.originalText else {
            throw AccessibilityRewriteFailure.selectionChanged
        }

        var isSettable = DarwinBoolean(false)
        let settableStatus = AXUIElementIsAttributeSettable(
            focused.element,
            kAXSelectedTextAttribute as CFString,
            &isSettable
        )
        try check(
            settableStatus,
            unavailableAs: .selectionNotEditable
        )
        guard isSettable.boolValue else {
            throw AccessibilityRewriteFailure.selectionNotEditable
        }

        let replacementStatus = AXUIElementSetAttributeValue(
            focused.element,
            kAXSelectedTextAttribute as CFString,
            replacement as CFString
        )
        try check(
            replacementStatus,
            unavailableAs: .selectionNotEditable
        )
    }

    private func focusedContext() throws -> FocusedContext {
        let systemWide = AXUIElementCreateSystemWide()
        let application: AXUIElement = try attribute(
            kAXFocusedApplicationAttribute,
            from: systemWide,
            unavailableAs: .noFocusedApplication
        )
        let element: AXUIElement = try attribute(
            kAXFocusedUIElementAttribute,
            from: application,
            unavailableAs: .noFocusedElement
        )

        var processIdentifier: pid_t = 0
        let pidStatus = AXUIElementGetPid(application, &processIdentifier)
        try check(pidStatus, unavailableAs: .noFocusedApplication)

        return FocusedContext(
            application: application,
            element: element,
            processIdentifier: processIdentifier
        )
    }

    private func selectedText(from element: AXUIElement) throws -> String {
        try attribute(
            kAXSelectedTextAttribute,
            from: element,
            unavailableAs: .selectionUnavailable
        )
    }

    private func selectedTextRange(from element: AXUIElement) throws -> CFRange {
        let value: AXValue = try attribute(
            kAXSelectedTextRangeAttribute,
            from: element,
            unavailableAs: .selectionUnavailable
        )
        guard AXValueGetType(value) == .cfRange else {
            throw AccessibilityRewriteFailure.selectionUnavailable
        }

        var range = CFRange()
        guard AXValueGetValue(value, .cfRange, &range) else {
            throw AccessibilityRewriteFailure.selectionUnavailable
        }
        return range
    }

    private func refuseSecureField(_ element: AXUIElement) throws {
        let subrole: String? = try optionalAttribute(kAXSubroleAttribute, from: element)
        if subrole == kAXSecureTextFieldSubrole as String {
            throw AccessibilityRewriteFailure.secureField
        }
    }

    private func refuseMultipleSelections(_ element: AXUIElement) throws {
        let ranges: [AXValue]? = try optionalAttribute(
            kAXSelectedTextRangesAttribute,
            from: element
        )
        if let ranges, ranges.count > 1 {
            throw AccessibilityRewriteFailure.multipleSelectionsUnsupported
        }
    }

    private func attribute<Value>(
        _ name: String,
        from element: AXUIElement,
        unavailableAs fallback: AccessibilityRewriteFailure
    ) throws -> Value {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            element,
            name as CFString,
            &value
        )
        try check(status, unavailableAs: fallback)
        guard let typedValue = value as? Value else {
            throw fallback
        }
        return typedValue
    }

    private func optionalAttribute<Value>(
        _ name: String,
        from element: AXUIElement
    ) throws -> Value? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            element,
            name as CFString,
            &value
        )
        if status == .noValue || status == .attributeUnsupported {
            return nil
        }
        try check(status, unavailableAs: .selectionUnavailable)
        return value as? Value
    }

    private func check(
        _ status: AXError,
        unavailableAs fallback: AccessibilityRewriteFailure
    ) throws {
        switch status {
        case .success:
            return
        case .attributeUnsupported, .noValue, .notImplemented:
            throw fallback
        case .apiDisabled:
            throw AccessibilityRewriteFailure.permissionRequired
        default:
            throw AccessibilityRewriteFailure.accessibilityFailure(status)
        }
    }
}

extension AccessibilitySelectionClient: EditableTextSelectionProviding {
    func captureSelection(
        promptingForPermission: Bool
    ) throws -> any EditableTextSelection {
        try captureFocusedSelection(
            promptingForPermission: promptingForPermission
        )
    }
}

@MainActor
final class AccessibilitySelectionSnapshot: EditableTextSelection {
    let originalText: String
    let originalRange: CFRange

    fileprivate let client: AccessibilitySelectionClient
    fileprivate let application: AXUIElement
    fileprivate let element: AXUIElement
    fileprivate let processIdentifier: pid_t

    fileprivate init(
        client: AccessibilitySelectionClient,
        application: AXUIElement,
        element: AXUIElement,
        processIdentifier: pid_t,
        originalText: String,
        originalRange: CFRange
    ) {
        self.client = client
        self.application = application
        self.element = element
        self.processIdentifier = processIdentifier
        self.originalText = originalText
        self.originalRange = originalRange
    }

    func replaceSelection(with replacement: String) throws {
        try client.replace(snapshot: self, with: replacement)
    }
}

private struct FocusedContext {
    let application: AXUIElement
    let element: AXUIElement
    let processIdentifier: pid_t
}
