import SwiftUI

/// Shared welcome screen. The installed app uses live Google authentication;
/// the prototype and UI review use the sample-data adapter.
///
/// Layout (design "S2 · Tape confetti"): calm paper ground, strips of athletic
/// tape in the friend hues drifting down behind a clear zone around the brand,
/// a small settled pile above the single primary action.
struct WelcomeScreen: View {
    @Environment(AppModel.self) private var mm
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings = false
    @State private var showExport = false
    @State private var isContinuing = false
    @State private var signInTask: Task<Void, Never>?
    @State private var appeared = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: MMSpace.s10)
                    brand
                    Spacer(minLength: MMSpace.s10)

                    TapePile()
                        .frame(height: 56)
                        .padding(.horizontal, -MMSpace.s4)
                    VStack(spacing: MMSpace.s3) {
                        googleButton
#if DEBUG
                        if let previewAction = mm.previewAction {
                            Button(action: previewAction) {
                                Text("Preview without signing in")
                                    .underline()
                                    .mmFont(.body, 15, .bold)
                                    .foregroundStyle(MMColor.textLink)
                                    .frame(minHeight: MMLayout.tapTarget)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens the app with sample data. No sign-in required.")
                            .accessibilityIdentifier("welcome-ui-preview")
                        }
#endif
                    }
                    .padding(.top, MMSpace.s4)
                    .padding(.bottom, MMSpace.s8)
                }
                .padding(.horizontal, MMSpace.s8)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background {
            ZStack {
                MMColor.bgApp
                TapeConfetti(falling: !reduceMotion)
            }
            .ignoresSafeArea()
        }
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
        .task {
            withAnimation(reduceMotion ? nil : MMMotion.bounce(MMMotion.slow)) { appeared = true }
        }
        .onDisappear { signInTask?.cancel() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active && !mm.isLive {
                signInTask?.cancel()
                isContinuing = false
            }
        }
    }

    /// Silverback mark, lowercase wordmark and the one-line promise.
    private var brand: some View {
        VStack(spacing: MMSpace.s6) {
            Image("SilverbackMark")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 104, height: 104)
                .accessibilityHidden(true)
            HStack(spacing: 0) {
                Text("mat monkeys")
                Text(".").foregroundStyle(MMColor.accent)
            }
            .mmFont(.display, 44, tracking: -0.045, lineHeight: 1)
            .foregroundStyle(MMColor.ink900)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Mat Monkeys")
            .accessibilityAddTraits(.isHeader)
            Text("Make plans. Meet on the mat.")
                .mmFont(.body, 18, .semibold, lineHeight: 1.35)
                .foregroundStyle(MMColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .contentShape(Rectangle())
        .onLongPressGesture { if !mm.isLive { mm.showDemoPanel = true } }
        .accessibilityHint(mm.isLive ? "" : "Long press for prototype tools")
    }

    private var googleButton: some View {
        Button(action: continueWithGoogle) {
            HStack(spacing: MMSpace.s5) {
                if isContinuing {
                    ProgressView().tint(MMColor.textOnAccent)
                        .frame(width: 28, height: 28)
                } else {
                    // Google's "G" always sits on white.
                    Image("GoogleSignIn")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white))
                        .accessibilityHidden(true)
                }
                Text(isContinuing ? "Getting ready…" : "Continue with Google")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(MMButtonStyle(variant: .primary, size: .lg, fullWidth: true))
        .disabled(isContinuing)
        .accessibilityHint(mm.isLive ? "Sign up or log in with your Google account" : "Opens the prototype with sample data")
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

// MARK: - Tape confetti

/// Deterministic pseudo-random numbers so the confetti looks the same on every launch.
private struct TapeRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 33) / Double(1 << 31)
    }
}

/// Friend hues only; belt colors stay reserved for rank.
private let tapeHues: [Color] = [MMColor.coral500, MMColor.sun400, MMColor.mint500, MMColor.sky500, MMColor.plum500]

/// Strips of tape drifting down the whole screen. They fade out in a band around
/// the brand so the wordmark and tagline always stay readable. Paused off-screen
/// and replaced by nothing when Reduce Motion is on.
private struct TapeConfetti: View {
    var falling: Bool
    @Environment(\.scenePhase) private var scenePhase

    private struct Strip { let x, speed, phase, width, height, spin, angle: Double; let hue: Int }
    private static let strips: [Strip] = {
        var random = TapeRandom(seed: 7)
        return (0..<16).map { index in
            Strip(x: random.next(), speed: 46 + random.next() * 36, phase: random.next(),
                  width: 6 + random.next() * 3, height: 14 + random.next() * 8,
                  spin: (random.next() - 0.5) * 2.4, angle: random.next() * .pi, hue: index % tapeHues.count)
        }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !falling || scenePhase != .active)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                guard falling else { return }
                let travel = size.height + 60
                let clearCenter = size.height * 0.42
                let clearHalf = size.height * 0.2
                for strip in Self.strips {
                    let y = (strip.phase * travel + time * strip.speed).truncatingRemainder(dividingBy: travel) - 30
                    // 0 inside the clear zone around the brand, easing back to 1 outside it.
                    let distance = abs(y - clearCenter) / clearHalf
                    let alpha = min(1, max(0, (distance - 0.6) * 1.6))
                    guard alpha > 0.02 else { continue }
                    var layer = canvas
                    layer.opacity = alpha
                    layer.translateBy(x: strip.x * size.width, y: y)
                    layer.rotate(by: .radians(strip.angle + time * strip.spin))
                    let rect = CGRect(x: -strip.width / 2, y: -strip.height / 2, width: strip.width, height: strip.height)
                    layer.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(tapeHues[strip.hue]))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The settled pile of tape just above the primary action. Static.
private struct TapePile: View {
    private struct Piece { let x, y, width, height, angle: Double; let hue: Int }
    private static let pieces: [Piece] = {
        var random = TapeRandom(seed: 21)
        return (0..<26).map { index in
            Piece(x: random.next(), y: 0.25 + random.next() * 0.75, width: 6 + random.next() * 3,
                  height: 14 + random.next() * 8, angle: (random.next() - 0.5) * .pi, hue: (index * 2) % tapeHues.count)
        }
    }()

    var body: some View {
        Canvas { canvas, size in
            for piece in Self.pieces {
                var layer = canvas
                layer.translateBy(x: piece.x * size.width, y: piece.y * (size.height - 12) + 6)
                layer.rotate(by: .radians(piece.angle))
                let rect = CGRect(x: -piece.width / 2, y: -piece.height / 2, width: piece.width, height: piece.height)
                layer.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(tapeHues[piece.hue]))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("Welcome") {
    WelcomeScreen().environment(AppModel())
}
