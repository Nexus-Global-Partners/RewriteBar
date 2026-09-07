/// The saved default is durable; a menu bar adjustment lasts until reset or relaunch.
public struct SessionIntensity: Equatable, Sendable {
    public private(set) var defaultLevel: Int
    public private(set) var overrideLevel: Int?

    public init(defaultLevel: Int = 3) {
        self.defaultLevel = RewriteIntensityPolicy.clampedLevel(defaultLevel)
    }
    public var activeLevel: Int { overrideLevel ?? defaultLevel }
    public var isOverridden: Bool { overrideLevel != nil }

    public mutating func select(_ level: Int) {
        let clamped = RewriteIntensityPolicy.clampedLevel(level)
        overrideLevel = clamped == defaultLevel ? nil : clamped
    }
    public mutating func setDefault(_ level: Int) {
        defaultLevel = RewriteIntensityPolicy.clampedLevel(level)
        reset()
    }
    public mutating func reset() { overrideLevel = nil }
}
