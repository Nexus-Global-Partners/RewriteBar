import Foundation

public enum AppConstants {
    public static let appName = "RewriteBar"
    public static let bundleIdentifier = "com.nexusglobalpartners.RewriteBar.Utility"

    public static let modelIdentifier = "mlx-community/Qwen3-1.7B-4bit"
    public static let modelDisplayName = "Qwen3 1.7B"
    public static let bundledModelDirectoryName = "Qwen3-1.7B-4bit"

    public static let maximumInputCharacters = 20_000
    public static let keepsModelResident = true
    public static let modelIdleLifetime: Duration = .seconds(1_800)
    public static let modelCacheLimitBytes = 1_024 * 1_024 * 1_024
}
