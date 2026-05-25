import AppKit
import Combine
import Foundation

@MainActor
final class LogsViewModel: ObservableObject {
    let controller: SleepGuardController

    init(controller: SleepGuardController) {
        self.controller = controller
    }

    func loadLogs() async {
        await controller.loadPMSetLog()
    }

    func copyRawLog() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(controller.rawLogText, forType: .string)
    }

    func loadJSONLog(at url: URL) async {
        do {
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let importer = PMSetJSONLogImporter()
            let rawLog = try importer.rawLog(from: data)
            let events = try importer.events(from: data)
            controller.loadImportedLog(rawLog: rawLog, events: events, sourceName: url.lastPathComponent)
        } catch {
            controller.loadImportedLog(rawLog: error.localizedDescription, events: [], sourceName: "JSON")
        }
    }
}
