import Foundation

/// Persisted to ~/Library/Application Support/Ramona/state.json so needs
/// pick up from wall-clock time across launches - including catching up on
/// decay after being quit for days - instead of resetting to full.
struct CatSaveState: Codable {
    var needs: NeedsState
    var lastUpdate: Date

    private static let directory: URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ramona", isDirectory: true)
    }()
    private static let fileURL = directory.appendingPathComponent("state.json")

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func load() -> CatSaveState? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(CatSaveState.self, from: data)
    }

    func persist() {
        try? FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        guard let data = try? Self.encoder.encode(self) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }
}
