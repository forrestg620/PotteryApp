import SwiftUI

struct ListForSaleView: View {
    let post: Post
    @Binding var isPresented: Bool

    @State private var price: String = ""
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                // Thumbnail image
                if let url = post.coverImageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 90, height: 90)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 90, height: 90)
                                .clipped()
                                .cornerRadius(10)
                        case .failure:
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 90, height: 90)
                                .foregroundColor(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .foregroundColor(.gray.opacity(0.4))
                }

                // Price input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sale Price")
                        .font(.headline)
                    TextField("Enter price (e.g. 30.00)", text: $price)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.title2)
                }
                .padding(.horizontal)

                Spacer()

                Button(action: {
                    submitListing()
                }) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    } else {
                        Text("List for Sale")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isSubmitEnabled ? Color.accentColor : Color.gray.opacity(0.4))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .disabled(!isSubmitEnabled || isSubmitting)
                .padding(.horizontal)

            }
            .padding(.top, 32)
            .navigationTitle("List for Sale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .alert("Error", isPresented: $showError, actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            })
        }
    }

    private var isSubmitEnabled: Bool {
        // Only enable if price input is a valid, positive decimal
        if let value = Double(price.trimmingCharacters(in: .whitespaces)), value > 0 {
            return true
        }
        return false
    }

    private func submitListing() {
        guard let value = Double(price.trimmingCharacters(in: .whitespaces)), value > 0 else {
            errorMessage = "Enter a valid price greater than 0."
            showError = true
            return
        }
        isSubmitting = true
        Task {
            do {
                try await NetworkManager.shared.convertPostToShelf(postId: post.id, price: value)
                await MainActor.run {
                    isSubmitting = false
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isSubmitting = false
                }
            }
        }
    }
}


