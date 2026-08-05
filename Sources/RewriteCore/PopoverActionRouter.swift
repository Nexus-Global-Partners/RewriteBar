public enum PopoverAction {
    case primary
    case restore
    case automaticRewrite
    case automaticRecovery
}

public enum PopoverActionRouter {
    public static func shouldClosePopover(
        after action: PopoverAction,
        succeeded: Bool
    ) -> Bool {
        guard succeeded else { return false }

        switch action {
        case .primary:
            return true
        case .restore:
            return false
        case .automaticRewrite:
            return true
        case .automaticRecovery:
            return true
        }
    }
}

public struct PopoverVisibilityTracker {
    public private(set) var isVisible = false

    public init() {}

    public mutating func opened() {
        isVisible = true
    }

    public mutating func closed() {
        isVisible = false
    }
}
