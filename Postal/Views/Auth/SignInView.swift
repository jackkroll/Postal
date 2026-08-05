import AuthenticationServices
import CryptoKit
import SwiftUI

struct SignInView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewmodel: ViewModel
    @State private var welcomeAppeared = false
    @State private var controlsAppeared = false

    init(viewmodel: ViewModel = ViewModel(auth: FirebaseAuthService())) {
        _viewmodel = State(initialValue: viewmodel)
    }

    var body: some View {
        ZStack {
            EnvelopePatternBackground()

            LinearGradient(
                colors: [
                    Color(.systemBackground).opacity(0.55),
                    Color(.systemBackground).opacity(0.15),
                    Color(.systemBackground).opacity(0.75),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "envelope.open.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 50)
                    VStack(spacing: 8) {
                        Text("Welcome to Postal")
                            .font(.largeTitle.weight(.bold))
                            .multilineTextAlignment(.center)
                        Text("Write & Send Letters")
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                .opacity(welcomeAppeared ? 1 : 0)
                .offset(y: welcomeAppeared ? 0 : 18)
                .scaleEffect(welcomeAppeared ? 1 : 0.96)

                Spacer()

                VStack(spacing: 16) {
                    if let errorMessage = viewmodel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    if viewmodel.isLoading {
                        ProgressView("Signing In…")
                    }

                    SignInWithAppleButton(.signIn) { request in
                        viewmodel.prepareAppleRequest(request)
                    } onCompletion: { result in
                        Task { await viewmodel.handleAppleSignIn(result) }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .clipShape(Capsule())
                    .frame(height: 54)
                    .padding(.horizontal, 40)
                    .disabled(viewmodel.isLoading)
                    .opacity(viewmodel.isLoading ? 0.6 : 1)

                    Button("Sign in with Email") {
                        viewmodel.showEmailSignIn = true
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .disabled(viewmodel.isLoading)
                }
                .padding(.top, 28)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)
                .background {
                    BottomLegibilityBlur()
                        .ignoresSafeArea()
                }
                .opacity(controlsAppeared ? 1 : 0)
                .offset(y: controlsAppeared ? 0 : 28)
            }
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $viewmodel.showEmailSignIn) {
            EmailSignInSheet(viewmodel: viewmodel)
        }
        .onAppear {
            withAnimation(.spring(response: 0.72, dampingFraction: 0.82).delay(0.08)) {
                welcomeAppeared = true
            }
            withAnimation(.spring(response: 0.78, dampingFraction: 0.84).delay(0.28)) {
                controlsAppeared = true
            }
        }
    }
}

// MARK: - Temporary email sign-in

private struct EmailSignInSheet: View {
    @Bindable var viewmodel: SignInView.ViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $viewmodel.email)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $viewmodel.password)
                        .textContentType(.password)
                }

                if let errorMessage = viewmodel.emailErrorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Sign in with Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewmodel.isLoading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewmodel.isLoading {
                        ProgressView()
                    } else {
                        Button("Sign In") {
                            Task {
                                let signedIn = await viewmodel.signInWithEmail()
                                if signedIn { dismiss() }
                            }
                        }
                        .disabled(viewmodel.email.isEmpty || viewmodel.password.isEmpty)
                    }
                }
            }
            .interactiveDismissDisabled(viewmodel.isLoading)
        }
        .presentationDetents([.medium])
    }
}

/// Soft material fade behind the sign-in controls.
private struct BottomLegibilityBlur: View {
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.35), location: 0.35),
                        .init(color: .black.opacity(0.85), location: 0.75),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .padding(.top, -40)
            .allowsHitTesting(false)
    }
}

// MARK: - Envelope pattern

private struct EnvelopePatternBackground: View {
    private let spacing: CGFloat = 64
    private let iconSize: CGFloat = 26

    var body: some View {
        GeometryReader { proxy in
            let diagonal = hypot(proxy.size.width, proxy.size.height) * 1.2
            let cols = Int(ceil(diagonal / spacing)) + 1
            let rows = Int(ceil(diagonal / spacing)) + 1

            ZStack {
                ForEach(0..<(rows * cols), id: \.self) { index in
                    let row = index / cols
                    let col = index % cols
                    Image(systemName: isOpen(row: row, col: col) ? "envelope.open" : "envelope")
                        .font(.system(size: iconSize, weight: .regular))
                        .foregroundStyle(.primary.opacity(opacity(row: row, col: col)))
                        .position(
                            x: CGFloat(col) * spacing + spacing / 2,
                            y: CGFloat(row) * spacing + spacing / 2
                        )
                }
            }
            .frame(width: diagonal, height: diagonal)
            .rotationEffect(.degrees(-45))
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Sparse, deterministic open envelopes so the field feels lived-in.
    private func isOpen(row: Int, col: Int) -> Bool {
        (row * 17 + col * 13) % 11 == 0
    }

    private func opacity(row: Int, col: Int) -> Double {
        isOpen(row: row, col: col) ? 0.40 : 0.25
    }
}

// MARK: - View model

extension SignInView {
    @Observable
    class ViewModel {
        let auth: AuthProviding
        var errorMessage: String?
        var isLoading: Bool = false

        var showEmailSignIn = false
        var email = ""
        var password = ""
        var emailErrorMessage: String?

        private var currentNonce: String?

        init(auth: AuthProviding) {
            self.auth = auth
        }

        func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
            let nonce = Self.randomNonceString()
            currentNonce = nonce
            request.requestedScopes = []
            request.nonce = Self.sha256(nonce)
        }

        func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
            switch result {
            case .success(let authorization):
                await completeAppleSignIn(authorization)
            case .failure(let error):
                if let authError = error as? ASAuthorizationError,
                   authError.code == .canceled || authError.code == .unknown {
                    return
                }
                errorMessage = error.localizedDescription
            }
        }

        /// Signs into an existing account only — never creates one.
        @discardableResult
        func signInWithEmail() async -> Bool {
            isLoading = true
            emailErrorMessage = nil
            errorMessage = nil
            defer { isLoading = false }

            do {
                try await auth.signIn(email: email, password: password)
                return true
            } catch {
                emailErrorMessage = error.localizedDescription
                return false
            }
        }

        private func completeAppleSignIn(_ authorization: ASAuthorization) async {
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Unable to process Apple ID credential."
                return
            }
            guard let nonce = currentNonce else {
                errorMessage = "Invalid sign-in state. Please try again."
                return
            }
            guard let tokenData = appleIDCredential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "Unable to fetch identity token."
                return
            }

            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            do {
                try await auth.signInWithApple(
                    idToken: idToken,
                    rawNonce: nonce
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        private static func randomNonceString(length: Int = 32) -> String {
            precondition(length > 0)
            var randomBytes = [UInt8](repeating: 0, count: length)
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
            precondition(errorCode == errSecSuccess, "Unable to generate nonce")

            let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
            return String(randomBytes.map { charset[Int($0) % charset.count] })
        }

        private static func sha256(_ input: String) -> String {
            let inputData = Data(input.utf8)
            let hashed = SHA256.hash(data: inputData)
            return hashed.compactMap { String(format: "%02x", $0) }.joined()
        }
    }
}

#Preview("Default") {
    SignInView(viewmodel: .preview())
}

#Preview("Loading") {
    SignInView(viewmodel: .preview(isLoading: true))
}

#Preview("Error") {
    SignInView(viewmodel: .preview(
        errorMessage: "Sign in with Apple failed. Please try again."
    ))
}
