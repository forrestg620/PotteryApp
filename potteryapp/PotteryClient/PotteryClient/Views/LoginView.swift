import SwiftUI

struct LoginView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showSignUp = false
    @FocusState private var focusedField: Field?

    enum Field {
        case username
        case password
    }

    var body: some View {
        VStack {
            Spacer()
            
            Text("PotteryClient")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 40)
            
            VStack(spacing: 20) {
                TextField("Username", text: $username)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .textContentType(.username)
                    .focused($focusedField, equals: .username)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .password
                    }

                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit {
                        login()
                    }
            }
            .padding(.horizontal, 32)
            
            Button(action: { login() }) {
                Text("Log In")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                    .opacity(isLoading ? 0.6 : 1.0)
            }
            .padding(.top, 30)
            .padding(.horizontal, 32)
            .disabled(isLoading || username.isEmpty || password.isEmpty)

            if isLoading {
                ProgressView()
                    .padding(.top, 20)
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
                    .padding(.horizontal, 32)
            }
            
            Button(action: {
                showSignUp = true
            }) {
                Text("Don't have an account? Sign Up")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.top, 20)
            }
            
            Spacer()
        }
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .sheet(isPresented: $showSignUp) {
            SignUpView()
        }
    }
    
    private func login() {
        guard !username.isEmpty && !password.isEmpty else {
            errorMessage = "Please enter both username and password."
            return
        }
        errorMessage = nil
        isLoading = true
        
        Task {
            do {
                try await NetworkManager.shared.login(username: username, password: password)
                // You may want to signal successful login/navigation here
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
