import AppKit
import Foundation

protocol ApplicationOpening {
    func openApplication(at url: URL) async -> RestoreResult
}

struct SystemAppRestorer: AppRestoring {
    var opener: ApplicationOpening
    var allowedApplicationDirectories: [URL]

    init(
        opener: ApplicationOpening = WorkspaceApplicationOpener(),
        allowedApplicationDirectories: [URL] = SystemAppRestorer.defaultAllowedApplicationDirectories()
    ) {
        self.opener = opener
        self.allowedApplicationDirectories = allowedApplicationDirectories
    }

    func restore(record: RunningAppRecord, shouldRestore: Bool) async -> RestoreResult {
        guard shouldRestore else { return .skippedByUserSetting }

        let urls = candidateURLs(for: record)
        guard !urls.isEmpty else { return .appURLMissing }

        for url in urls {
            let result = await opener.openApplication(at: url)
            if result == .success {
                return .success
            }
        }
        return .failed
    }

    private func candidateURLs(for record: RunningAppRecord) -> [URL] {
        var urls: [URL] = []
        if let appURLString = record.appURLString,
           let storedURL = URL(string: appURLString),
           let validatedURL = validatedApplicationURL(storedURL) {
            urls.append(validatedURL)
        }
        if let bundleId = record.bundleId,
           let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let validatedURL = validatedApplicationURL(bundleURL),
           !urls.contains(validatedURL) {
            urls.append(validatedURL)
        }
        return urls
    }

    private func validatedApplicationURL(_ url: URL) -> URL? {
        guard url.isFileURL else { return nil }
        let standardizedURL = url.standardizedFileURL.resolvingSymlinksInPath()
        guard standardizedURL.pathExtension == "app" else { return nil }
        guard allowedApplicationDirectories.contains(where: { allowedDirectory in
            let allowedPath = allowedDirectory.standardizedFileURL.resolvingSymlinksInPath().path
            return standardizedURL.path == allowedPath || standardizedURL.path.hasPrefix(allowedPath + "/")
        }) else {
            return nil
        }
        return standardizedURL
    }

    private static func defaultAllowedApplicationDirectories() -> [URL] {
        var urls = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true)
        ]
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        urls.append(homeDirectory.appendingPathComponent("Applications", isDirectory: true))
        return urls
    }
}

struct WorkspaceApplicationOpener: ApplicationOpening {
    func openApplication(at url: URL) async -> RestoreResult {
        await withCheckedContinuation { continuation in
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
                continuation.resume(returning: error == nil ? .success : .failed)
            }
        }
    }
}
