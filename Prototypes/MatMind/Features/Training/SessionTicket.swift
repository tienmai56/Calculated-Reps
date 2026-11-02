import SwiftUI

private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}

/// Signature motif: a session card with a tinted date stub, a dashed tear
/// line and punched notches. The stub uses the organizer's friend hue.
struct SessionTicket: View {
    @Environment(AppModel.self) private var mm
    let session: Session
    var big = false
    /// Background behind the card, for the punched notches.
    var notchColor: Color = MMColor.bgApp
    var onTap: (() -> Void)?

    var body: some View {
        if let onTap {
            Button(action: onTap) { ticket }.buttonStyle(MMPressStyle())
        } else {
            ticket
        }
    }

    private var ticket: some View {
        let organizer = mm.person(session.organizer)
        let hue: FriendHue = session.organizer == "me" ? .coral : organizer.hue
        let going = session.going.map { mm.person($0).avatar }
        let stubWidth: CGFloat = big ? 96 : 84
        return HStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(session.day.uppercased()).mmFont(.display, 13, tracking: 0.04, lineHeight: 1)
                Text("\(session.date)").mmFont(.display, big ? 48 : 40, tracking: -0.04, lineHeight: 1)
                    .padding(.top, 4)
                    .padding(.bottom, 2)
                Text(session.month).mmFont(.body, 12, .bold, lineHeight: 1)
            }
            .foregroundStyle(hue.ink)
            .padding(.vertical, 16)
            .frame(width: stubWidth)
            .frame(maxHeight: .infinity)
            .background(hue.tint)

            DashedLine()
                .stroke(MMColor.ink200, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .frame(width: 2)
                .padding(.vertical, 10)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 6) {
                    Text(session.title).mmFont(.display, 18, lineHeight: 1.15).foregroundStyle(MMColor.ink900)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if session.status(of: "me") == .invited {
                        MMBadge("Invite", variant: .warning, dot: true)
                    }
                }
                HStack(spacing: 6) {
                    MMIcon("clock", size: 14, color: MMColor.textTertiary)
                    Text(session.time).mmFont(.body, 13, .medium, lineHeight: 1).foregroundStyle(MMColor.textSecondary)
                        .fixedSize()
                    MMIcon("map-pin", size: 14, color: MMColor.textTertiary).padding(.leading, 4)
                    Text(session.gym).mmFont(.body, 13, .medium, lineHeight: 1).foregroundStyle(MMColor.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                HStack {
                    MMAvatarStack(people: going, size: 28, ring: .white, label: "\(going.count) going")
                    Spacer(minLength: 4)
                    Text(session.organizer == "me" ? "You host" : "by \(organizer.firstName)")
                        .mmFont(.body, 12, .semibold, lineHeight: 1).foregroundStyle(MMColor.textTertiary)
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 14)
            .padding(.leading, 16)
            .padding(.trailing, 14)
        }
        .fixedSize(horizontal: false, vertical: true)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .mmCardSurface(radius: 24)
        .overlay(alignment: .topLeading) {
            Circle().fill(notchColor).frame(width: 18, height: 18).offset(x: stubWidth - 8, y: -9)
        }
        .overlay(alignment: .bottomLeading) {
            Circle().fill(notchColor).frame(width: 18, height: 18).offset(x: stubWidth - 8, y: 9)
        }
        .accessibilityElement(children: .combine)
    }
}
