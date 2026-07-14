import FirebaseFirestore
import Foundation

final class FirestoreLettersService: LettersProviding {
    private let database = Firestore.firestore()

    func startListening(userID: String, onChange: @escaping ([LetterSummary]) -> Void) -> AnyObject? {
        let query = database
            .collection(AppConfiguration.firebaseUsersCollection)
            .document(userID)
            .collection(AppConfiguration.firebaseLettersCollection)

        let listener = query.addSnapshotListener { snapshot, error in
            Task { @MainActor in
                guard error == nil, let documents = snapshot?.documents else {
                    onChange([])
                    return
                }
                let letters = documents.compactMap(Self.letterSummary(from:))
                onChange(letters)
            }
        }

        return listener
    }

    func stopListening(_ token: AnyObject?) {
        (token as? ListenerRegistration)?.remove()
    }

    private static func letterSummary(from document: QueryDocumentSnapshot) -> LetterSummary? {
        let data = document.data()
        guard
            let sendTo = data["sendTo"] as? String,
            let sendFrom = data["sendFrom"] as? String,
            let statusRaw = data["status"] as? String,
            let status = ShipmentStatus(rawValue: statusRaw)
        else {
            return nil
        }

        return LetterSummary(
            trackingNumber: document.documentID,
            origin: LetterEndpoint(rawValue: sendFrom),
            destination: LetterEndpoint(rawValue: sendTo),
            status: status,
            hasLetter: data["hasLetter"] as? Bool ?? false,
            letterFormat: (data["letterFormat"] as? String).flatMap(LetterFormat.init(rawValue:)),
            letterMimeType: data["letterMimeType"] as? String,
            letterEncoding: data["letterEncoding"] as? String,
            letterByteSize: data["letterByteSize"] as? Int,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
        )
    }
}
