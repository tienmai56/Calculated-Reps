import SwiftUI

/// The prototype's signed-out entry point. Google continuation is simulated:
/// no Google SDK, credentials, network requests, or account persistence.
struct WelcomeScreen: View {
    @Environment(AppModel.self) private var mm
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings = false
    @State private var showExport = false
    @State private var isContinuing = false
    @State private var signInTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    MMWordmark(size: 36)
                        .padding(.top, MMSpace.s8)
                        .onLongPressGesture { if !mm.isLive { mm.showDemoPanel = true } }
                        .accessibilityHint("Long press for prototype tools")

                    Spacer(minLength: MMSpace.s8)
                    WelcomePhotoStack()
                        .frame(height: 320)
                    Spacer(minLength: MMSpace.s8)

                    VStack(spacing: MMSpace.s5) {
                        VStack(spacing: 0) {
                            Text("Good people.").foregroundStyle(MMColor.textPrimary)
                            Text("Great rounds.").foregroundStyle(MMColor.textAccent)
                        }
                        .mmFont(.display, 36, tracking: -0.03, lineHeight: 1)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isHeader)

                        Text("Make plans. Share the mat. Keep showing up.")
                            .mmFont(.body, 15, lineHeight: 1.45)
                            .foregroundStyle(MMColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .multilineTextAlignment(.center)

                    Spacer(minLength: MMSpace.s9)
                    VStack(spacing: MMSpace.s6) {
#if DEBUG
                        if let previewAction = mm.previewAction {
                            MMButton("Preview UI", size: .lg, iconLeft: "eye", fullWidth: true, action: previewAction)
                                .accessibilityIdentifier("welcome-ui-preview")
                            Text("Sample data. No sign-in required.")
                                .mmFont(.body, 13)
                                .foregroundStyle(MMColor.textSecondary)
                        }
#endif
                        googleButton
                        if mm.isLive {
                            Button {
                                signInTask = Task { _ = await mm.runtime?.perform("sign_in_apple", [:]) }
                            } label: {
                                HStack(spacing: 10) { Image(systemName: "apple.logo"); Text("Continue with Apple") }
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(MMButtonStyle(variant: .secondary, size: .lg, fullWidth: true))
                            .disabled(mm.busy)
                        }
                        Text("Sign up or log in. You're in the right place.")
                            .mmFont(.body, 13, lineHeight: 1.4)
                            .foregroundStyle(MMColor.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, MMSpace.s8)
                }
                .padding(.horizontal, MMSpace.s8)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(MMColor.bgApp.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            if mm.isLive {
                MMIconButton("settings", variant: .filled, label: "Settings") { showSettings = true }.padding(12)
            }
        }
        .mmSheet(isPresented: $showSettings, title: "Settings") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Export").mmFont(.display, 18)
                MMButton("Export local sessions", variant: .secondary, iconLeft: "download") { showExport = true }
            }
            .sheet(isPresented: $showExport) { mm.runtime?.exportView() }
        }
        .onDisappear { signInTask?.cancel() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active && !mm.isLive {
                signInTask?.cancel()
                isContinuing = false
            }
        }
    }

    private var googleButton: some View {
        Button(action: continueWithGoogle) {
            HStack(spacing: MMSpace.s5) {
                if isContinuing {
                    ProgressView().tint(MMColor.textPrimary)
                        .frame(width: 20, height: 20)
                } else {
                    Image("GoogleSignIn")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)
                }
                Text(isContinuing ? "Getting ready…" : "Continue with Google")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(MMButtonStyle(variant: .secondary, size: .lg, fullWidth: true))
        .disabled(isContinuing)
        .accessibilityHint(mm.isLive ? "Sign in with your Google account" : "Opens the prototype with sample data")
        .accessibilityIdentifier("welcome-google-continue")
    }

    private func continueWithGoogle() {
        guard !isContinuing else { return }
        if let runtime = mm.runtime {
            isContinuing = true
            signInTask = Task { await runtime.authenticate(); isContinuing = false }
            return
        }
        isContinuing = true
        signInTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(650))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : MMMotion.easeOut()) {
                mm.enterDemo()
            }
        }
    }
}

/// A small fan of photo memories, with a gentle bob while the screen is active.
/// Reduce Motion removes both the entrance and the continuous movement.
private struct WelcomePhotoStack: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var appeared = false

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || scenePhase != .active)) { context in
                let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                ZStack {
                    memory("roll-gi-2", caption: "One more round?", width: 202, height: 206)
                        .rotationEffect(.degrees(appeared ? -12 + sin(t * 1.4) : 0))
                        .offset(x: appeared ? -48 : 0, y: appeared ? -22 + sin(t * 1.4) * 3 : 22)
                    memory("coach-help", caption: "Always learning.", width: 202, height: 206)
                        .rotationEffect(.degrees(appeared ? 11 - sin(t * 1.4) : 0))
                        .offset(x: appeared ? 48 : 0, y: appeared ? -14 - sin(t * 1.4) * 3 : 22)
                    memory("group-class", caption: "Better with your people.", width: 228, height: 230)
                        .rotationEffect(.degrees(appeared ? -3 : 0))
                        .offset(y: appeared ? 16 + sin(t * 1.4) * 3 : 28)
                    MMPairAvatars(a: SeedData.me.avatar, b: (SeedData.people["sarah"]?.avatar ?? SeedData.me.avatar),
                                  size: 38, hue: .plum, ring: MMColor.bgApp)
                        .rotationEffect(.degrees(8))
                        .offset(x: 104, y: appeared ? 126 : 136)
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.94)
                .frame(width: 344, height: 320)
                .scaleEffect(min(geometry.size.width / 344, 1))
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .accessibilityHidden(true)
        .task {
            withAnimation(reduceMotion ? nil : MMMotion.bounce(MMMotion.slow)) {
                appeared = true
            }
        }
    }

    private func memory(_ photo: String, caption: String, width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: MMSpace.s5) {
            MMPhotoTile(photo: photo, height: height - 48, radius: MMRadius.md)
            Text(caption)
                .mmFont(.display, 13, .bold, tracking: -0.015, lineHeight: 1)
                .foregroundStyle(MMColor.textSecondary)
                .padding(.bottom, MMSpace.s2)
        }
        .padding(MMSpace.s4)
        .frame(width: width)
        .background(RoundedRectangle(cornerRadius: MMRadius.lg, style: .continuous).fill(MMColor.tape))
        .mmShadowCard()
    }
}

#Preview("Welcome") {
    WelcomeScreen().environment(AppModel())
}
