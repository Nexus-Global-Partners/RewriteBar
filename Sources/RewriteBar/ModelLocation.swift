import Foundation
import RewriteCore

enum ModelLocation {
    static let repositoryURL: URL = {
        if let developmentPath = ProcessInfo.processInfo.environment["REWRITEBAR_MODEL_PATH"],
           !developmentPath.isEmpty {
            return URL(fileURLWithPath: developmentPath, isDirectory: true)
        }

        return Bundle.main.resourceURL!
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent(
                AppConstants.bundledModelDirectoryName,
                isDirectory: true
            )
    }()

    static func isModelInstalled(fileManager: FileManager = .default) -> Bool {
        let requiredFiles = [
            "config.json",
            "tokenizer.json",
            "tokenizer_config.json"
        ]

        guard requiredFiles.allSatisfy({
            fileManager.fileExists(atPath: repositoryURL.appendingPathComponent($0).path)
        }) else {
            return false
        }

        guard let contents = try? fileManager.contentsOfDirectory(
            at: repositoryURL,
            includingPropertiesForKeys: nil
        ) else {
            return false
        }

        return contents.contains { $0.pathExtension == "safetensors" }
    }
}
