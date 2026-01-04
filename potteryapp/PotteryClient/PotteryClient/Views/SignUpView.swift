import SwiftUI

struct SignUpView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var selectedImage: UIImage? = nil
    @State private var videoURL: URL? = nil
    @State private var showImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var isSigningUp = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Avatar Picker
                Button(action: {
                    showImagePicker = true
                }) {
                    Group {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.secondary, lineWidth: 2))
                    .shadow(radius: 3)
                }
                .padding(.top, 40)
                .accessibilityLabel("Avatar picker")

                VStack(spacing: 20) {
                    TextField("Username", text: $username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    
                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                }
                .padding(.horizontal, 24)
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Button(action: {
                    signUp()
                }) {
                    if isSigningUp {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Create Account")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSigningUp || username.isEmpty || password.isEmpty)
                .padding()
                .background((isSigningUp || username.isEmpty || password.isEmpty) ? Color.gray : Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal, 24)
                .padding(.bottom, 10)

                Spacer()
            }
            .navigationBarTitle("Sign Up", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedImage, videoURL: $videoURL, sourceType: sourceType)
            }
            .onChange(of: videoURL) { oldURL, newURL in
                // Clear video if selected (we only want images for avatar)
                if newURL != nil {
                    videoURL = nil
                }
            }
        }
    }
    
    func signUp() {
        isSigningUp = true
        errorMessage = nil
        
        Task {
            do {
                try await NetworkManager.shared.signUp(username: username, password: password, avatar: selectedImage)
                await MainActor.run {
                    self.isSigningUp = false
                    self.presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    self.isSigningUp = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

