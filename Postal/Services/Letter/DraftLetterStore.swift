import Foundation

protocol DraftLetterStoring: AnyObject {
    func list() -> [LetterDraft]
    func load(id: UUID) -> LetterDraft?
    func loadDrawingData(id: UUID) -> Data?
    func save(_ draft: LetterDraft, drawingData: Data?)
    func delete(id: UUID)
}

/// Persists letter drafts under Application Support as JSON + optional PKDrawing files.
final class DraftLetterStore: DraftLetterStoring {
    private let fileManager: FileManager
    private let rootDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let queue = DispatchQueue(label: "com.postal.DraftLetterStore")

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        rootDirectory = support.appendingPathComponent("LetterDrafts", isDirectory: true)
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }

    func list() -> [LetterDraft] {
        queue.sync {
            guard let urls = try? fileManager.contentsOfDirectory(
                at: rootDirectory,
                includingPropertiesForKeys: nil
            ) else {
                return []
            }
            return urls
                .filter { $0.pathExtension == "json" }
                .compactMap { url -> LetterDraft? in
                    guard let data = try? Data(contentsOf: url) else { return nil }
                    return try? decoder.decode(LetterDraft.self, from: data)
                }
                .sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    func load(id: UUID) -> LetterDraft? {
        queue.sync {
            loadUnlocked(id: id)
        }
    }

    func loadDrawingData(id: UUID) -> Data? {
        queue.sync {
            let url = drawingURL(for: id)
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            return try? Data(contentsOf: url)
        }
    }

    func save(_ draft: LetterDraft, drawingData: Data?) {
        queue.sync {
            do {
                let data = try encoder.encode(draft)
                try data.write(to: jsonURL(for: draft.id), options: .atomic)
                let drawingFile = drawingURL(for: draft.id)
                if let drawingData, !drawingData.isEmpty {
                    try drawingData.write(to: drawingFile, options: .atomic)
                } else if fileManager.fileExists(atPath: drawingFile.path) {
                    try? fileManager.removeItem(at: drawingFile)
                }
            } catch {
                // Local drafts are best-effort; ignore disk errors.
            }
        }
    }

    func delete(id: UUID) {
        queue.sync {
            try? fileManager.removeItem(at: jsonURL(for: id))
            try? fileManager.removeItem(at: drawingURL(for: id))
        }
    }

    private func loadUnlocked(id: UUID) -> LetterDraft? {
        let url = jsonURL(for: id)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(LetterDraft.self, from: data)
    }

    private func jsonURL(for id: UUID) -> URL {
        rootDirectory.appendingPathComponent("\(id.uuidString).json")
    }

    private func drawingURL(for id: UUID) -> URL {
        rootDirectory.appendingPathComponent("\(id.uuidString).pkdrawing")
    }
}
