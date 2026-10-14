import SwiftUI

struct AuthView: View {
    @Environment(AuthService.self) private var auth
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focus: Field?

    private enum Field { case email, password }

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 8 && !auth.isWorking
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brandCyan.opacity(0.25), Color.brandViolet.opacity(0.25), Color(.systemBackground)],
                startPoint: .topLeading, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .padding(.top, 48)

                    VStack(spacing: 6) {
                        Text("Jack's Day Counter")
                            .font(.largeTitle.bold())
                        Text(isSignUp ? "Create your account to sync your countdowns." : "Welcome back.")
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)

                    VStack(spacing: 12) {
                        TextField("Email", text: $email)
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focus, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focus = .password }
                        SecureField("Password (8+ characters)", text: $password)
                            .textContentType(isSignUp ? .newPassword : .password)
                            .focused($focus, equals: .password)
                            .submitLabel(.go)
                            .onSubmit(submit)
                    }
                    .textFieldStyle(PillFieldStyle())

                    if let error = auth.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    if let info = auth.infoMessage {
                        Label(info, systemImage: "envelope.badge")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button(action: submit) {
                        Group {
                            if auth.isWorking {
                                ProgressView().tint(.white)
                            } else {
                                Text(isSignUp ? "Create Account" : "Sign In")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .disabled(!canSubmit)

                    Button(isSignUp ? "Already have an account? Sign in" : "New here? Create an account") {
                        withAnimation(.smooth) { isSignUp.toggle() }
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal, 28)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func submit() {
        guard canSubmit else { return }
        Task {
            if isSignUp {
                await auth.signUp(email: email, password: password)
            } else {
                await auth.signIn(email: email, password: password)
            }
        }
    }
}

struct PillFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 18)
            .frame(height: 52)
            .background(.regularMaterial, in: Capsule())
    }
}

#Preview { AuthView().environment(AuthService()) }
