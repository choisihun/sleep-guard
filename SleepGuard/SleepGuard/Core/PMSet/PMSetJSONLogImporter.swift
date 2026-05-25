import Foundation

struct PMSetJSONLogImporter {
    private struct ExportedLog: Decodable {
        var schemaVersion: Int?
        var entryCount: Int?
        var entries: [Entry]
    }

    private struct Entry: Decodable {
        var rawLine: String
    }

    var parser = PMSetLogParser()

    func rawLog(from data: Data) throws -> String {
        let exported = try JSONDecoder().decode(ExportedLog.self, from: data)
        return exported.entries.map(\.rawLine).joined(separator: "\n")
    }

    func events(from data: Data) throws -> [PMSetEvent] {
        parser.parse(try rawLog(from: data))
    }
}
