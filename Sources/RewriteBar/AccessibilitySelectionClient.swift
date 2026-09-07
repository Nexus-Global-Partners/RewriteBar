import AppKit
import ApplicationServices
import Foundation
import OSLog
import RewriteCore

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
    private static let serviceName = "Accessibility"
    private static let setupAlertBundleIdentifier =
        "com.apple.accessibility.universalAccessAuthWarn"

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

    @discardableResult
    static func beginSetup() -> Bool {
        refreshPermissionRecord(
            reset: resetStoredDecision,
            request: requestIfNeeded
        )
    }

    static func refreshPermissionRecord(
        reset: () -> Bool,
        request: () -> Bool
    ) -> Bool {
        _ = reset()
        return request()
    }

    static func dismissSetupAlert() {
        let alerts = NSRunningApplication.runningApplications(
            withBundleIdentifier: setupAlertBundleIdentifier
        )
        for alert in alerts {
            _ = alert.terminate()
        }
    }

    private static func resetStoredDecision() -> Bool {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return false
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", serviceName, bundleIdentifier]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

struct AccessibilityPermissionRecoveryState {
    private(set) var hasRequestedSetup = false

    mutating func shouldBeginSetup(
        for failure: AccessibilityRewriteFailure
    ) -> Bool {
        guard failure == .permissionRequired,
              !hasRequestedSetup else {
            return false
        }

        hasRequestedSetup = true
        return true
    }
}

@MainActor
final class AccessibilitySelectionClient {
    private let logger = Logger(
        subsystem: AppConstants.bundleIdentifier,
        category: "AccessibilitySelection"
    )

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

        let selectedRange = try selectedTextRange(from: focused.element)
        let fullText = try stringValue(from: focused.element)
        let capturedText = try capturedText(
            from: focused.element,
            fullText: fullText,
            range: selectedRange
        )
        let selectedText = capturedText.text
        guard selectedRange.length > 0, !selectedText.isEmpty else {
            throw AccessibilityRewriteFailure.selectionEmpty
        }

        return AccessibilitySelectionSnapshot(
            client: self,
            application: focused.application,
            element: focused.element,
            processIdentifier: focused.processIdentifier,
            originalText: selectedText,
            originalRange: selectedRange,
            replacementStrategy: capturedText.replacementStrategy
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
        guard Self.selectionRangeIsUnchanged(
            original: snapshot.originalRange,
            current: currentRange
        ) else {
            throw AccessibilityRewriteFailure.selectionChanged
        }

        switch snapshot.replacementStrategy {
        case .selectedText:
            // Some editors expose a readable selected-text attribute while
            // incorrectly reporting it as not settable. The set operation is
            // the definitive capability check. If it fails, the coordinator
            // preserves the rewrite in the clipboard instead of discarding it.
            try setAttribute(
                kAXSelectedTextAttribute,
                on: focused.element,
                to: replacement as CFString
            )
            guard try selectedTextReplacementIsConfirmed(
                on: focused.element,
                replacement: replacement
            ) else {
                throw AccessibilityRewriteFailure.selectionNotEditable
            }

        case .selectedTextWithPlainTextFallback(let originalValue):
            guard let updatedValue = Self.replacingText(
                in: originalValue,
                range: snapshot.originalRange,
                with: replacement
            ) else {
                throw AccessibilityRewriteFailure.selectionNotEditable
            }
            do {
                try setAttribute(
                    kAXSelectedTextAttribute,
                    on: focused.element,
                    to: replacement as CFString
                )
                if try plainTextValueIsConfirmed(
                    on: focused.element,
                    expectedValue: updatedValue
                ) {
                    return
                }
                logger.notice(
                    "Direct selection replacement was accepted but not applied; trying the editable text value"
                )
            } catch let failure as AccessibilityRewriteFailure {
                guard failure != .permissionRequired else {
                    throw failure
                }
                logger.notice(
                    "Direct selection replacement was unavailable; trying the editable text value: \(failure.localizedDescription, privacy: .public)"
                )
            }
            try replacePlainTextValue(
                on: focused.element,
                originalValue: originalValue,
                range: snapshot.originalRange,
                with: replacement
            )

        case .plainTextValue(let originalValue):
            try replacePlainTextValue(
                on: focused.element,
                originalValue: originalValue,
                range: snapshot.originalRange,
                with: replacement
            )
        }
    }

    static func selectionRangeIsUnchanged(
        original: CFRange,
        current: CFRange
    ) -> Bool {
        original.location == current.location
            && original.length == current.length
    }

    static func text(in value: String, range: CFRange) -> String? {
        let nsRange = NSRange(
            location: range.location,
            length: range.length
        )
        let nsValue = value as NSString
        guard nsRange.location >= 0,
              nsRange.length >= 0,
              nsRange.location <= nsValue.length,
              nsRange.length <= nsValue.length - nsRange.location else {
            return nil
        }
        return nsValue.substring(with: nsRange)
    }

    static func replacingText(
        in value: String,
        range: CFRange,
        with replacement: String
    ) -> String? {
        guard text(in: value, range: range) != nil else {
            return nil
        }
        let result = NSMutableString(string: value)
        result.replaceCharacters(
            in: NSRange(location: range.location, length: range.length),
            with: replacement
        )
        return result as String
    }

    static func focusedApplicationProcessIdentifier(
        accessibilityProcessIdentifier: pid_t?,
        frontmostProcessIdentifier: pid_t?,
        currentProcessIdentifier: pid_t
    ) throws -> pid_t {
        let candidates = [
            accessibilityProcessIdentifier,
            frontmostProcessIdentifier
        ]

        guard let processIdentifier = candidates.compactMap({ $0 }).first(
            where: { $0 > 0 && $0 != currentProcessIdentifier }
        ) else {
            throw AccessibilityRewriteFailure.noFocusedApplication
        }
        return processIdentifier
    }

    static func selectionPlan(
        selectedText: String?,
        fullText: String?,
        fullTextIsSettable: Bool,
        range: CFRange
    ) throws -> AccessibilitySelectionPlan {
        // A readable selection is enough to begin a rewrite. Accessibility
        // clients are not consistent about whether selected text is reported
        // as settable, so replacement is attempted only after generation.
        if let selectedText {
            if let fullText,
               text(in: fullText, range: range) == selectedText {
                return AccessibilitySelectionPlan(
                    text: selectedText,
                    replacementStrategy: .selectedTextWithPlainTextFallback(
                        originalValue: fullText
                    )
                )
            }
            return AccessibilitySelectionPlan(
                text: selectedText,
                replacementStrategy: .selectedText
            )
        }

        let rangedText = fullText.flatMap { text(in: $0, range: range) }
        if let fullText, let rangedText, fullTextIsSettable {
            return AccessibilitySelectionPlan(
                text: rangedText,
                replacementStrategy: .plainTextValue(originalValue: fullText)
            )
        }

        if selectedText != nil || rangedText != nil {
            throw AccessibilityRewriteFailure.selectionNotEditable
        }
        throw AccessibilityRewriteFailure.selectionUnavailable
    }

    private func focusedContext() throws -> FocusedContext {
        let systemWide = AXUIElementCreateSystemWide()
        let systemWideFocusedElement: AXUIElement? = try optionalAttribute(
            kAXFocusedUIElementAttribute,
            from: systemWide
        )
        let systemWideFocusedElementProcessIdentifier = systemWideFocusedElement
            .flatMap { applicationProcessIdentifier(from: $0) }
        let accessibilityApplication: AXUIElement? = try optionalAttribute(
            kAXFocusedApplicationAttribute,
            from: systemWide
        )
        let accessibilityProcessIdentifier = accessibilityApplication.flatMap {
            applicationProcessIdentifier(from: $0)
        }
        let frontmostProcessIdentifier = NSWorkspace.shared
            .frontmostApplication?
            .processIdentifier
        let processIdentifier = try Self.focusedApplicationProcessIdentifier(
            accessibilityProcessIdentifier:
                systemWideFocusedElementProcessIdentifier
                    ?? accessibilityProcessIdentifier,
            frontmostProcessIdentifier: frontmostProcessIdentifier,
            currentProcessIdentifier: ProcessInfo.processInfo.processIdentifier
        )
        let application: AXUIElement
        if let accessibilityApplication,
           accessibilityProcessIdentifier == processIdentifier {
            application = accessibilityApplication
        } else {
            application = AXUIElementCreateApplication(processIdentifier)
        }
        let applicationFocusedElement: AXUIElement? = try optionalAttribute(
            kAXFocusedUIElementAttribute,
            from: application
        )
        let element: AXUIElement
        if Self.shouldUseSystemWideFocusedElement(
            elementProcessIdentifier: systemWideFocusedElementProcessIdentifier,
            focusedProcessIdentifier: processIdentifier
        ), let systemWideFocusedElement {
            element = systemWideFocusedElement
        } else if let applicationFocusedElement {
            element = applicationFocusedElement
        } else {
            guard let focusedWindow: AXUIElement = try optionalAttribute(
                kAXFocusedWindowAttribute,
                from: application
            ), let selection = try uniqueEditableSelection(
                in: focusedWindow,
                processIdentifier: processIdentifier
            ) else {
                throw AccessibilityRewriteFailure.noFocusedElement
            }
            element = selection
        }

        return FocusedContext(
            application: application,
            element: element,
            processIdentifier: processIdentifier
        )
    }

    static func shouldUseSystemWideFocusedElement(
        elementProcessIdentifier: pid_t?,
        focusedProcessIdentifier: pid_t
    ) -> Bool {
        elementProcessIdentifier == focusedProcessIdentifier
    }

    static func uniqueSelectionCandidate<Element>(
        roots: [Element],
        maximumVisitedElements: Int = 384,
        children: (Element) throws -> [Element],
        hasEditableSelection: (Element) throws -> Bool
    ) throws -> Element? {
        var queue = roots
        var index = 0
        var candidate: Element?

        while index < queue.count, index < maximumVisitedElements {
            let element = queue[index]
            index += 1

            if try hasEditableSelection(element) {
                guard candidate == nil else {
                    throw AccessibilityRewriteFailure.multipleSelectionsUnsupported
                }
                candidate = element
            }
            queue.append(contentsOf: try children(element))
        }

        // A partial scan cannot establish that the selection is unique.
        guard index == queue.count else {
            throw AccessibilityRewriteFailure.selectionUnavailable
        }
        return candidate
    }

    private func applicationProcessIdentifier(
        from application: AXUIElement
    ) -> pid_t? {
        var processIdentifier: pid_t = 0
        guard AXUIElementGetPid(application, &processIdentifier) == .success,
              processIdentifier > 0 else {
            return nil
        }
        return processIdentifier
    }

    private func uniqueEditableSelection(
        in focusedWindow: AXUIElement,
        processIdentifier: pid_t
    ) throws -> AXUIElement? {
        try Self.uniqueSelectionCandidate(
            roots: [focusedWindow],
            children: { element in
                let children: [AXUIElement]? = try self.optionalAttribute(
                    kAXChildrenAttribute,
                    from: element
                )
                return children ?? []
            },
            hasEditableSelection: { element in
                guard self.applicationProcessIdentifier(from: element)
                        == processIdentifier,
                      let range = try self.optionalSelectedTextRange(
                        from: element
                      ),
                      range.length > 0 else {
                    return false
                }
                return try self.isAttributeSettable(
                    kAXSelectedTextAttribute,
                    on: element
                )
            }
        )
    }

    private func capturedText(
        from element: AXUIElement,
        fullText: String?,
        range: CFRange
    ) throws -> AccessibilitySelectionPlan {
        let selectedText: String? = try optionalAttribute(
            kAXSelectedTextAttribute,
            from: element
        )
        if selectedText != nil {
            return try Self.selectionPlan(
                selectedText: selectedText,
                fullText: fullText,
                // A readable selected-text attribute is sufficient to begin.
                // The full value is retained as a native fallback and tested
                // by the actual set operation only if direct replacement fails.
                fullTextIsSettable: false,
                range: range
            )
        }

        return try Self.selectionPlan(
            selectedText: selectedText,
            fullText: fullText,
            fullTextIsSettable: fullText != nil
                && (try isAttributeSettable(kAXValueAttribute, on: element)),
            range: range
        )
    }

    private func stringValue(from element: AXUIElement) throws -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &value
        )
        if status == .noValue
            || status == .attributeUnsupported
            || status == .notImplemented {
            return nil
        }
        try check(status, unavailableAs: .selectionUnavailable)
        return value as? String
    }

    private func isAttributeSettable(
        _ name: String,
        on element: AXUIElement
    ) throws -> Bool {
        var isSettable = DarwinBoolean(false)
        let status = AXUIElementIsAttributeSettable(
            element,
            name as CFString,
            &isSettable
        )
        switch status {
        case .success:
            return isSettable.boolValue
        case .attributeUnsupported, .noValue, .notImplemented:
            return false
        case .apiDisabled:
            throw AccessibilityRewriteFailure.permissionRequired
        default:
            throw AccessibilityRewriteFailure.accessibilityFailure(status)
        }
    }

    private func setAttribute(
        _ name: String,
        on element: AXUIElement,
        to value: CFTypeRef
    ) throws {
        let status = AXUIElementSetAttributeValue(
            element,
            name as CFString,
            value
        )
        try check(status, unavailableAs: .selectionNotEditable)
    }

    private func replacePlainTextValue(
        on element: AXUIElement,
        originalValue: String,
        range: CFRange,
        with replacement: String
    ) throws {
        let currentValue = try stringValue(from: element)
        guard currentValue == originalValue else {
            throw AccessibilityRewriteFailure.selectionChanged
        }
        guard let updatedValue = Self.replacingText(
            in: originalValue,
            range: range,
            with: replacement
        ) else {
            throw AccessibilityRewriteFailure.selectionNotEditable
        }
        try setAttribute(
            kAXValueAttribute,
            on: element,
            to: updatedValue as CFString
        )
        guard try plainTextValueIsConfirmed(
            on: element,
            expectedValue: updatedValue
        ) else {
            throw AccessibilityRewriteFailure.selectionNotEditable
        }
    }

    private func selectedTextReplacementIsConfirmed(
        on element: AXUIElement,
        replacement: String
    ) throws -> Bool {
        for attempt in 0..<4 {
            let selectedText: String? = try optionalAttribute(
                kAXSelectedTextAttribute,
                from: element
            )
            if selectedText == replacement {
                return true
            }
            if attempt < 3 {
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        return false
    }

    private func plainTextValueIsConfirmed(
        on element: AXUIElement,
        expectedValue: String
    ) throws -> Bool {
        for attempt in 0..<4 {
            if try stringValue(from: element) == expectedValue {
                return true
            }
            if attempt < 3 {
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        return false
    }

    private func selectedTextRange(from element: AXUIElement) throws -> CFRange {
        guard let range = try optionalSelectedTextRange(from: element) else {
            throw AccessibilityRewriteFailure.selectionUnavailable
        }
        return range
    }

    private func optionalSelectedTextRange(
        from element: AXUIElement
    ) throws -> CFRange? {
        guard let value: AXValue = try optionalAttribute(
            kAXSelectedTextRangeAttribute,
            from: element
        ) else {
            return nil
        }
        guard AXValueGetType(value) == .cfRange else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(value, .cfRange, &range) else {
            return nil
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
        if status == .noValue
            || status == .attributeUnsupported
            || status == .notImplemented {
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
    fileprivate let replacementStrategy: AccessibilityReplacementStrategy

    fileprivate init(
        client: AccessibilitySelectionClient,
        application: AXUIElement,
        element: AXUIElement,
        processIdentifier: pid_t,
        originalText: String,
        originalRange: CFRange,
        replacementStrategy: AccessibilityReplacementStrategy
    ) {
        self.client = client
        self.application = application
        self.element = element
        self.processIdentifier = processIdentifier
        self.originalText = originalText
        self.originalRange = originalRange
        self.replacementStrategy = replacementStrategy
    }

    func replaceSelection(with replacement: String) throws {
        try client.replace(snapshot: self, with: replacement)
    }
}

enum AccessibilityReplacementStrategy: Equatable {
    case selectedText
    case selectedTextWithPlainTextFallback(originalValue: String)
    case plainTextValue(originalValue: String)
}

struct AccessibilitySelectionPlan: Equatable {
    let text: String
    let replacementStrategy: AccessibilityReplacementStrategy
}

private struct FocusedContext {
    let application: AXUIElement
    let element: AXUIElement
    let processIdentifier: pid_t
}
