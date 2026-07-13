import SwiftUI

struct LettersListView: View {
    @State private var viewmodel: ViewModel

    init(
        viewmodel: ViewModel = ViewModel(
            auth: FirebaseAuthService(),
            lettersService: FirestoreLettersService()
        )
    ) {
        _viewmodel = State(initialValue: viewmodel)
    }

    var body: some View {
            Group {
                if viewmodel.letters.isEmpty {
                    ContentUnavailableView {
                        Label("No Letters Yet", systemImage: "envelope.open")
                    } description: {
                        Text("Shipments you create will appear here.")
                    } actions: {
                        NavigationLink("Ship a Letter", value: ViewRoute.ship)
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(viewmodel.letters) { letter in
                        NavigationLink(value: ViewRoute.track(trackingNum: letter.trackingNumber, letter: letter)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(letter.trackingNumber)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                
                                Text("\(letter.sendFrom) → \(letter.sendTo)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                Text(letter.status.rawValue.replacingOccurrences(of: "_", with: " "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if letter.hasLetter, let format = letter.letterFormat {
                                    Text(format == .text ? "Text letter" : "\(format.rawValue.capitalized) letter")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("My Letters")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(value: ViewRoute.ship) {
                        Label("Ship", systemImage: "square.and.pencil")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out") {
                        try? viewmodel.auth.signOut()
                    }
                }
            }
            .onAppear(perform: viewmodel.startListening)
            .onDisappear(perform: viewmodel.stopListening)
        
    }

    

    
}

extension LettersListView {
    @Observable
    class ViewModel {
        var auth: AuthProviding
        var lettersService: LettersProviding
        var letters: [LetterSummary] = []
        var listenerToken: AnyObject?
        
        init(auth: AuthProviding, lettersService: LettersProviding) {
            self.auth = auth
            self.lettersService = lettersService
        }
        
        func startListening() {
            guard let userID = auth.currentUserID else { return }
            stopListening()
            listenerToken = lettersService.startListening(userID: userID) { updatedLetters in
                self.letters = updatedLetters.sorted {
                    ($0.updatedAt ?? $0.createdAt ?? .distantPast) > ($1.updatedAt ?? $1.createdAt ?? .distantPast)
                }
            }
        }
        
        func stopListening() {
            lettersService.stopListening(listenerToken)
            listenerToken = nil
        }
    }
}
#Preview("Empty") {
    NavigationStack {
        LettersListView(viewmodel: .preview(letters: []))
            .navigationDestination(for: ViewRoute.self) { route in
                Router.view(for: route)
            }
    }
    .environment(Router())
}

#Preview("Populated") {
    NavigationStack {
        LettersListView(viewmodel: .preview())
            .navigationDestination(for: ViewRoute.self) { route in
                Router.view(for: route)
            }
    }
    .environment(Router())
}

#Preview("Single Letter") {
    NavigationStack {
        LettersListView(viewmodel: .preview(letters: [PreviewData.letterInTransit]))
            .navigationDestination(for: ViewRoute.self) { route in
                Router.view(for: route)
            }
    }
    .environment(Router())
}

#Preview("All Statuses") {
    NavigationStack {
        LettersListView(viewmodel: .preview(letters: PreviewData.letters))
            .navigationDestination(for: ViewRoute.self) { route in
                Router.view(for: route)
            }
    }
    .environment(Router())
}
