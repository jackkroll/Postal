import Foundation

protocol PendingTimeCapsuleStoring: AnyObject {
    func list() -> [PendingTimeCapsule]
    func load(id: UUID) -> PendingTimeCapsule?
    func save(_ capsule: PendingTimeCapsule)
    func delete(id: UUID)
}

/// Persists pending time-capsule letters until the send API lands.
final class PendingTimeCapsuleStore: PendingTimeCapsuleStoring {
    private let fileManager: FileManager
    private let rootDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let queue = DispatchQueue(label: "com.postal.PendingTimeCapsuleStore")

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        rootDirectory = support.appendingPathComponent("PendingTimeCapsules", isDirectory: true)
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }

    func list() -> [PendingTimeCapsule] {
        queue.sync {
            guard let urls = try? fileManager.contentsOfDirectory(
                at: rootDirectory,
                includingPropertiesForKeys: nil
            ) else {
                return []
            }
            return urls
                .filter { $0.pathExtension == "json" }
                .compactMap { url -> PendingTimeCapsule? in
                    guard let data = try? Data(contentsOf: url) else { return nil }
                    return try? decoder.decode(PendingTimeCapsule.self, from: data)
                }
                .sorted { $0.createdAt > $1.createdAt }
        }
    }

    func load(id: UUID) -> PendingTimeCapsule? {
        queue.sync {
            let url = jsonURL(for: id)
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(PendingTimeCapsule.self, from: data)
        }
    }

    func save(_ capsule: PendingTimeCapsule) {
        queue.sync {
            do {
                let data = try encoder.encode(capsule)
                try data.write(to: jsonURL(for: capsule.id), options: .atomic)
            } catch {
                // Best-effort local persistence.
            }
        }
    }

    func delete(id: UUID) {
        queue.sync {
            try? fileManager.removeItem(at: jsonURL(for: id))
        }
    }

    private func jsonURL(for id: UUID) -> URL {
        rootDirectory.appendingPathComponent("\(id.uuidString).json")
    }
}
