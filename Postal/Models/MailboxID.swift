import Foundation

/// OpenAPI constraints for post office identifiers (`ClaimMailboxRequest.post_office_id` minimum is 1).
enum PostOfficeValidation {
    static let minimumID = 1

    static func isValidID(_ id: Int) -> Bool {
        id >= minimumID
    }
}

/// Client-side checks for mailbox codes entered before lookup.
enum MailboxCodeValidation {
    static let maximumLength = 32
    private static let allowedCharacters = CharacterSet.alphanumerics

    static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    static func isValid(_ raw: String) -> Bool {
        let code = normalized(raw)
        guard !code.isEmpty, code.count <= maximumLength else { return false }
        return code.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
    }
}

enum MailboxLookupError: LocalizedError {
    case invalidPostOfficeID(Int)
    case invalidMailboxCode(String)
    case notFound(code: String)

    var errorDescription: String? {
        switch self {
        case let .invalidPostOfficeID(id):
            return "Post office ID must be at least \(PostOfficeValidation.minimumID). Received \(id)."
        case let .invalidMailboxCode(code):
            if code.isEmpty {
                return "Enter a mailbox code."
            }
            return "Mailbox code must be 1–\(MailboxCodeValidation.maximumLength) letters or numbers."
        case let .notFound(code):
            return "No mailbox found with code \(code) at this post office."
        }
    }
}

/// Composite mailbox identity as used by the API: `{postOfficeID}:{CODE}`.
struct MailboxID: Hashable, Codable, RawRepresentable, CustomStringConvertible, Identifiable {
    let postOfficeID: Int
    let code: String

    var rawValue: String { "\(postOfficeID):\(code)" }

    var id: String { rawValue }

    var description: String { rawValue }

    init?(postOfficeID: Int, code: String) {
        guard PostOfficeValidation.isValidID(postOfficeID) else { return nil }
        let normalized = MailboxCodeValidation.normalized(code)
        guard MailboxCodeValidation.isValid(normalized) else { return nil }
        self.postOfficeID = postOfficeID
        self.code = normalized
    }

    init(postOfficeID: Int, code: String, file: StaticString = #file, line: UInt = #line) {
        guard let parsed = MailboxID(postOfficeID: postOfficeID, code: code) else {
            preconditionFailure("Invalid mailbox id \(postOfficeID):\(code)", file: file, line: line)
        }
        self = parsed
    }

    init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2,
              let postOfficeID = Int(parts[0])
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
