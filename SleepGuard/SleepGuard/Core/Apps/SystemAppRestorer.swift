import AppKit
import Foundation

struct SystemAppRestorer: AppRestoring {
    func restore(record: RunningAppRecord, shouldRestore: Bool) async -> RestoreResult {
        guard shouldRestore else { return .skippedByUserSetting }

        let urls = candidateURLs(for: record)
        guard !urls.isEmpty else { return .appURLMissing }

        for url in urls {
            let result = await openApplication(at: url)
            if result == .success {
                return .success
            }
        }
        return .failed
    }

    private func candidateURLs(for record: RunningAppRecord) -> [URL] {
        var urls: [URL] = []
        if let appURLString = record.appURLString, let storedURL = URL(string: appURLString) {
            urls.append(storedURL)
        }
        if let bundleId = record.bundleId,
           let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           !urls.contains(bundleURL) {
            urls.append(bundleURL)
        }
        return urls
    }

    private func openApplication(at url: URL) async -> RestoreResult {
        return await withCheckedContinuation { continuation in
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
                continuation.resume(returning: error == nil ? .success : .failed)
            }
        }
    }
}
