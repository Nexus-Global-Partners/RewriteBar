import Foundation
import RewriteCore
import Security

struct CodexExecutableLocator: Sendable {
    private let applicationURLs: [URL]
    private let bundleIdentifier: @Sendable (URL) -> String?
    private let isExecutable: @Sendable (URL) -> Bool
    private let hasTrustedSignature: @Sendable (URL) -> Bool

    init(
        applicationURLs: [URL] = [
            URL(fileURLWithPath: "/Applications/ChatGPT.app", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications/ChatGPT.app", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications/Codex.app", isDirectory: true)
        ],
        bundleIdentifier: @escaping @Sendable (URL) -> String? = {
            Bundle(url: $0)?.bundleIdentifier
        },
        isExecutable: @escaping @Sendable (URL) -> Bool = {
            FileManager.default.isExecutableFile(atPath: $0.path)
        },
        hasTrustedSignature: @escaping @Sendable (URL) -> Bool = {
            Self.hasOpenAISignature($0)
        }
    ) {
        self.applicationURLs = applicationURLs
        self.bundleIdentifier = bundleIdentifier
        self.isExecutable = isExecutable
        self.hasTrustedSignature = hasTrustedSignature
    }

    func locate() throws -> URL {
        for applicationURL in applicationURLs {
            guard bundleIdentifier(applicationURL) == "com.openai.codex" else {
                continue
            }
            guard hasTrustedSignature(applicationURL) else { continue }
            let executableURL = applicationURL
                .appendingPathComponent("Contents/Resources/codex", isDirectory: false)
            guard isExecutable(executableURL) else {
                continue
            }
            return executableURL
        }
        throw CodexRewriteError.runtimeUnavailable
    }

    private static func hasOpenAISignature(_ applicationURL: URL) -> Bool {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(
            applicationURL as CFURL,
            [],
            &staticCode
        ) == errSecSuccess,
        let staticCode else {
            return false
        }

        var requirement: SecRequirement?
        let requirementText = """
        anchor apple generic and identifier "com.openai.codex" and \
        certificate leaf[subject.OU] = "2DC432GLL2"
        """ as CFString
        guard SecRequirementCreateWithString(
            requirementText,
            [],
            &requirement
        ) == errSecSuccess,
        let requirement else {
            return false
        }

        return SecStaticCodeCheckValidity(
            staticCode,
            SecCSFlags(rawValue: kSecCSCheckAllArchitectures),
            requirement
        ) == errSecSuccess
    }

    static func isolatedHomeURL(fileManager: FileManager = .default) throws -> URL {
        guard let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw CodexRewriteError.transportUnavailable
        }
        return applicationSupport
            .appendingPathComponent(AppConstants.appName, isDirectory: true)
            .appendingPathComponent("Codex", isDirectory: true)
    }
}
