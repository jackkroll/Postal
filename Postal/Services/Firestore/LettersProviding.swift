import Foundation

protocol LettersProviding: AnyObject {
    func startListening(userID: String, onChange: @escaping ([LetterSummary]) -> Void) -> AnyObject?
    func stopListening(_ token: AnyObject?)
}
