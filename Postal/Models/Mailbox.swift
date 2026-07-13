import Foundation

struct MailboxSummary: Codable, Identifiable, Hashable {
    let id: String
    let postOfficeID: Int
    let postOfficeName: String?
    let label: String
    let ownerUserID: String?
    let owned: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case postOfficeID = "post_office_id"
        case postOfficeName = "post_office_name"
        case label
        case ownerUserID = "owner_user_id"
        case owned
    }

    var locationLabel: String {
        postOfficeName ?? "Post Office \(postOfficeID)"
    }

    var pickerLabel: String {
        "\(label) · \(locationLabel)"
    }
}
