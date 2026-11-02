import SwiftUI

/// Add friends: show my code, or scan someone's. No requests, no approvals.
struct QRScreen: View {
    @Environment(AppModel.self) private var mm
    @State private var tab: String
    @State private var found: String? = nil
    @State private var sweep = false

    init(startOnScan: Bool = false) {
        _tab = State(initialValue: startOnScan ? "scan" : "code")
    }

    private var scanning: Bool { tab == "scan" }

    var body: some View {
        MMScreen(background: scanning ? Color(mmHex: 0x141210) : MMColor.bgApp) {
            VStack(spacing: 0) {
                MMHeader(title: "Add friends", titleColor: scanning ? .white : MMColor.ink900, leading: {
                    MMIconButton("x", variant: scanning ? .overlay : .ghost, label: "Close") { mm.back() }
                })
                MMTabs(items: [MMTabItem("code", "My code"), MMTabItem("scan", "Scan")], selection: Binding(
                    get: { tab },
                    set: { tab = $0; found = nil }
                ))
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
        } content: {
            if scanning { scanView } else { codeView }
        }
        .task(id: tab) {
            guard tab == "scan", found == nil else { return }
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled, tab == "scan" else { return }
            withAnimation(MMMotion.easeOut(0.25)) { found = "lena" }
            mm.addFriend("lena")
        }
    }

    private var codeView: some View {
        let me = mm.me
        return VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(me.name).mmFont(.display, 24, tracking: -0.03, lineHeight: 1).foregroundStyle(.white)
                MMBelt(rank: me.belt, stripes: me.stripes, size: .xs, width: 120)
                    .padding(.top, 10)
                    .padding(.bottom, 18)
                QRGrid(size: 196)
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white))
                    .shadow(color: Color(mmHex: 0x781E00).opacity(0.3), radius: 15, x: 0, y: 10)
                    .rotationEffect(.degrees(-2))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 54)
            .padding(.horizontal, 24)
            .padding(.bottom, 26)
            .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(MMColor.coral500))
            .overlay(alignment: .top) {
                MMAvatar(name: me.name, photo: me.photo, size: 80, belt: me.belt, ring: MMColor.coral500)
                    .background(Circle().fill(MMColor.bgApp).padding(-5))
                    .offset(y: -40)
            }

            Text("Hold this up after class").mmFont(.display, 20, lineHeight: 1.2).foregroundStyle(MMColor.ink900).padding(.top, 26)
            Text("When a training partner scans it, you're friends. No requests, no waiting.")
                .mmFont(.body, 15).foregroundStyle(MMColor.textSecondary).padding(.top, 6)
            MMButton("Scan someone instead", variant: .secondary, iconLeft: "scan-line") { tab = "scan" }
                .padding(.top, 18)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.top, 68)
    }

    private var scanView: some View {
        ZStack {
            Image("team-lineup").resizable().scaledToFill()
                .brightness(-0.3)
                .saturation(0.8)
            ZStack(alignment: .top) {
                ForEach(0..<4, id: \.self) { i in
                    ScanCorner()
                        .stroke(found == nil ? Color.white : MMColor.mint500, style: StrokeStyle(lineWidth: 5, lineCap: .butt))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(Double(i) * 90))
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: [Alignment.topLeading, .topTrailing, .bottomTrailing, .bottomLeading][i])
                }
                if found == nil {
                    Capsule().fill(MMColor.sun400)
                        .frame(height: 3)
                        .shadow(color: MMColor.sun400, radius: 8)
                        .padding(.horizontal, 14)
                        .offset(y: sweep ? 200 : 14)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { sweep = true }
                        }
                }
            }
            .frame(width: 220, height: 220)
            .offset(y: -34)
            Text(found == nil ? "Point at a friend's Mat Mind code" : "Got it!")
                .mmFont(.body, 15, .bold)
                .foregroundStyle(.white)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 28)
            if let found {
                ConnectedView(friendID: found) {
                    self.found = nil
                    mm.back()
                }
                .transition(.opacity)
            }
        }
        .frame(height: 560)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }
}

/// Top-left L bracket with a rounded corner; rotated for the other corners.
private struct ScanCorner: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 2.5, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + 2.5, y: rect.minY + 18))
        p.addArc(tangent1End: CGPoint(x: rect.minX + 2.5, y: rect.minY + 2.5),
                 tangent2End: CGPoint(x: rect.minX + 18, y: rect.minY + 2.5), radius: 16)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 2.5))
        return p
    }
}

/// A stand-in QR pattern (seeded, so it looks the same every time) with the "mm." mark.
struct QRGrid: View {
    var seed = 7
    var size: CGFloat = 200

    private static let n = 25

    private func cells() -> [Bool] {
        let n = Self.n
        var x = seed
        func rnd() -> Double {
            x = (x * 9301 + 49297) % 233280
            return Double(x) / 233280
        }
        func finder(_ r: Int, _ c: Int) -> Bool? {
            for (R, C) in [(0, 0), (0, n - 7), (n - 7, 0)] {
                if r >= R && r < R + 7 && c >= C && c < C + 7 {
                    let rr = r - R, cc = c - C
                    return rr == 0 || rr == 6 || cc == 0 || cc == 6 || (rr >= 2 && rr <= 4 && cc >= 2 && cc <= 4)
                }
                if r >= R - 1 && r <= R + 7 && c >= C - 1 && c <= C + 7 { return false }
            }
            return nil
        }
        var out: [Bool] = []
        for r in 0..<n {
            for c in 0..<n {
                let f = finder(r, c)
                let mid = r > 9 && r < 15 && c > 9 && c < 15
                if mid { out.append(false) } else if let f { out.append(f) } else { out.append(rnd() > 0.52) }
            }
        }
        return out
    }

    var body: some View {
        let grid = cells()
        let n = Self.n
        Canvas { context, canvasSize in
            let cell = canvasSize.width / CGFloat(n)
            for (i, on) in grid.enumerated() where on {
                let rect = CGRect(x: CGFloat(i % n) * cell, y: CGFloat(i / n) * cell, width: cell, height: cell)
                context.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(MMColor.ink900))
            }
        }
        .frame(width: size, height: size)
        .overlay {
            Text("mm.")
                .mmFont(.display, size * 0.07, tracking: 0, lineHeight: 1)
                .foregroundStyle(.white)
                .frame(width: size * 0.18, height: size * 0.18)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(MMColor.accent))
        }
        .accessibilityLabel("Your Mat Mind code")
    }
}

/// Sun-yellow "you're friends" moment after a scan.
private struct ConnectedView: View {
    @Environment(AppModel.self) private var mm
    let friendID: String
    let onDone: () -> Void

    @State private var joined = false
    @State private var textShown = false

    var body: some View {
        let p = mm.person(friendID)
        let me = mm.me
        VStack(spacing: 0) {
            HStack(spacing: -26) {
                MMAvatar(name: me.name, photo: me.photo, size: 104)
                    .background(Circle().fill(MMColor.sun400).padding(-5))
                    .offset(x: joined ? 0 : -90)
                    .rotationEffect(.degrees(joined ? 0 : -20))
                    .opacity(joined ? 1 : 0)
                MMAvatar(name: p.name, size: 104)
                    .background(Circle().fill(MMColor.sun400).padding(-5))
                    .offset(x: joined ? 0 : 90)
                    .rotationEffect(.degrees(joined ? 0 : 20))
                    .opacity(joined ? 1 : 0)
            }
            .overlay(alignment: .bottom) {
                MMIcon("handshake", size: 28, color: MMColor.sun400)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(MMColor.ink900))
                    .background(Circle().fill(MMColor.sun400).padding(-5))
                    .scaleEffect(textShown ? 1 : 0.3)
                    .opacity(textShown ? 1 : 0)
                    .offset(y: 6)
            }
            .frame(height: 120)

            Group {
                Text("You & \(p.firstName) are friends").mmFont(.display, 30, tracking: -0.04, lineHeight: 1.05).foregroundStyle(MMColor.ink900)
                    .padding(.top, 28)
                Text("Train together this week to start your first streak.").mmFont(.body, 15).foregroundStyle(MMColor.ink800)
                    .padding(.top, 8)
                VStack(spacing: 8) {
                    MMButton("Plan a session with \(p.firstName)", variant: .inverse, size: .lg, iconLeft: "calendar-plus", fullWidth: true) {
                        mm.replace(.create(friend: friendID))
                    }
                    MMButton("Done", variant: .ghost, fullWidth: true, action: onDone)
                }
                .padding(.top, 26)
            }
            .opacity(textShown ? 1 : 0)
            .offset(y: textShown ? 0 : 10)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MMColor.sun400)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { joined = true }
            withAnimation(MMMotion.bounce(0.5).delay(0.55)) { textShown = true }
        }
    }
}
