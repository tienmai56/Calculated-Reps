import SwiftUI

struct WelcomeView: View {
    var errorMessage: String?
    var isOffline: Bool = false
    var showsGoogleSignIn: Bool = true
    var onGoogle: () -> Void

    private var statusMessage: String? {
        errorMessage ?? (isOffline ? "You're offline. Saved training data works after sign-in, but signing in needs internet." : nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5])).foregroundColor(Color(.systemGray4)).frame(width: 300, height: 300)
                Circle().stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5])).foregroundColor(Color(.systemGray5)).frame(width: 210, height: 210)
                VStack(spacing: 18) {
                    Text("Intentional\nTraining Notes")
                        .font(.system(size: 30, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                    VStack(spacing: 6) {
                        Text("Welcome to Intentional Training Notes")
                            .font(.caption)
                            .foregroundColor(AppColors.label)
                            .uppercaseTracking()
                        Text("Train with more intentionality.\nGet better, faster.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            Spacer()
            VStack(spacing: 10) {
                if let statusMessage = statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(errorMessage == nil ? .secondary : AppColors.coral)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Button(action: onGoogle) {
                    HStack {
                        Text("G")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                        Text("Continue with Google")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())

                Text("By continuing you agree to our Terms & Privacy.")
                    .font(.caption)
                    .foregroundColor(AppColors.label)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }
}

struct ProfileSetupView: View {
    var account: UserAccount?
    var profile: UserProfile?
    var onSave: (String, String) -> Void
    var onSignOut: () -> Void

    @State private var firstName = ""
    @State private var lastName = ""

    private var canSave: Bool {
        firstName.nilIfBlank != nil && lastName.nilIfBlank != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(title: "Profile", rightTitle: "Sign out", rightAction: onSignOut)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Finish your setup")
                            .font(.title)
                            .fontWeight(.medium)
                        Text("This keeps your training notebook tied to the right account on this device.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.label)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("First name").fieldLabel()
                        TextField("Alex", text: $firstName)
                            .textFieldStyle(TrainingTextFieldStyle())
                        Text("Last name").fieldLabel()
                        TextField("Rivera", text: $lastName)
                            .textFieldStyle(TrainingTextFieldStyle())
                    }

                }
                .padding(20)
            }
            Button("Save Profile") {
                onSave(firstName, lastName)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canSave)
            .padding()
        }
        .onAppear {
            guard firstName.isEmpty, lastName.isEmpty else { return }
            if let profile = profile {
                firstName = profile.firstName
                lastName = profile.lastName
                return
            }
            guard let displayName = account?.displayName else { return }
            let parts = displayName.split(separator: " ")
            firstName = parts.first.map(String.init) ?? ""
            lastName = parts.dropFirst().joined(separator: " ")
        }
    }
}
