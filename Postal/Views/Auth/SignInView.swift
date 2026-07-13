import SwiftUI

struct SignInView: View {
    @State private var viewmodel: ViewModel

    init(viewmodel: ViewModel = ViewModel(auth: FirebaseAuthService())) {
        _viewmodel = State(initialValue: viewmodel)
    }

    var body: some View {
            VStack {
                Form {
                    Section("Account") {
                        TextField("Email", text: $viewmodel.email)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        
                        SecureField("Password", text: $viewmodel.password)
                            .textContentType(.password)
                    }
                    
                    if let errorMessage = viewmodel.errorMessage  {
                        Section {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }
                    }
                }
                Spacer()
                Group {
                    if #available(iOS 26.0, *) {
                        Button(viewmodel.isLoading ? "Signing In…" : "Sign In") {
                            Task { await viewmodel.signIn() }
                        }
                        .disabled(viewmodel.isLoading || viewmodel.email.isEmpty || viewmodel.password.isEmpty)
                        .buttonSizing(.flexible)
                        .buttonStyle(.borderedProminent)
                    } else {
                        // Fallback on earlier versions
                        Button(viewmodel.isLoading ? "Signing In…" : "Sign In") {
                            Task { await viewmodel.signIn() }
                        }
                        .disabled(viewmodel.isLoading || viewmodel.email.isEmpty || viewmodel.password.isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle("Postal")
        }
}

extension SignInView {
    @Observable
    class ViewModel {
        
        
        let auth: AuthProviding
        var email: String = ""
        var password: String = ""
        var errorMessage: String?
        var isLoading: Bool = false
        func signIn() async {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            
            do {
                try await auth.signIn(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        init(auth: AuthProviding) {
            self.auth = auth
        }
    }
}

#Preview("Empty Form") {
    NavigationStack {
        SignInView(viewmodel: .preview())
    }
}

#Preview("Filled Form") {
    NavigationStack {
        SignInView(viewmodel: .preview(email: "player@postal.dev", password: "hunter2"))
    }
}

#Preview("Loading") {
    NavigationStack {
        SignInView(viewmodel: .preview(
            email: "player@postal.dev",
            password: "hunter2",
            isLoading: true
        ))
    }
}

#Preview("Invalid Credentials") {
    NavigationStack {
        SignInView(viewmodel: .preview(
            email: "player@postal.dev",
            password: "wrong-password",
            errorMessage: "The email or password is incorrect."
        ))
    }
}
