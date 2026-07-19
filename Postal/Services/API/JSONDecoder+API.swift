import Foundation

extension JSONDecoder {
    static func apiDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = Date.parseAPITimestamp(value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized date format: \(value)"
            )
        }
        return decoder
    }
}

private extension Date {
    private static let iso8601WithFractionalSeconds = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let iso8601 = Date.ISO8601FormatStyle()

    /// Parses API timestamps.
    ///
    /// - Timezone-aware strings (`Z` / `±HH:MM`) use `ISO8601FormatStyle` for
    ///   full fractional-second precision (`ISO8601DateFormatter` truncates to ms).
    /// - Timezone-naive strings (PostalSim’s usual form, e.g.
    ///   `2026-07-08T16:30:15.492603`) are wall-clock times in the local
    ///   timezone — treating them as UTC shifts Eastern times by 4/5 hours.
    static func parseAPITimestamp(_ value: String) -> Date? {
        if let date = try? Date(value, strategy: iso8601WithFractionalSeconds) {
            return date
        }
        if let date = try? Date(value, strategy: iso8601) {
            return date
        }

        if isTimezoneNaiveISOTimestamp(value) {
            return parseNaiveISOTimestamp(value)
        }

        return nil
    }

    private static func isTimezoneNaiveISOTimestamp(_ value: String) -> Bool {
        value.range(
            of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?$"#,
            options: .regularExpression
        ) != nil
    }

    private static func parseNaiveISOTimestamp(_ value: String) -> Date? {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }
}
