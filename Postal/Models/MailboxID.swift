import Foundation

/// Composite mailbox identity as used by the API: `{postOfficeID}:{CODE}`.
struct MailboxID: Hashable, Codable, RawRepresentable, CustomStringConvertible {
    let postOfficeID: Int
    let code: String

    var rawValue: String { "\(postOfficeID):\(code)" }

    var description: String { rawValue }

    init(postOfficeID: Int, code: String) {
        self.postOfficeID = postOfficeID
        self.code = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2,
              let postOfficeID = Int(parts[0]),
              !parts[1].isEmpty
        else {
            return nil
        }
        self.init(postOfficeID: postOfficeID, code: String(parts[1]))
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let parsed = MailboxID(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid mailbox id '\(rawValue)'."
            )
        }
        self = parsed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
