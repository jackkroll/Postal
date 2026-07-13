import Foundation

enum AppConfiguration {
    /// Local PostalSim server. Use your machine's LAN IP when running on a physical device.
    static let apiBaseURL = URL(string: "http://192.168.1.115:8000")!

    static let firebaseLettersCollection = "letters"
    static let firebaseUsersCollection = "users"
    static let firebaseTrackCollection = "track"
}
