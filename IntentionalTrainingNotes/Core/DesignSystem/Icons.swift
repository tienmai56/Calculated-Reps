import SwiftUI
import UIKit

struct GoalIconLibrary {
    static let icons = ["target", "flame", "bolt.fill", "star.fill", "heart.fill",
                        "figure.walk", "dollarsign.circle.fill", "music.note", "book.fill",
                        "wand.and.stars", "paintbrush.fill", "camera.fill", "leaf.fill",
                        "hammer.fill", "flag.fill", "shield.fill", "arrow.up.right",
                        "arrow.up.arrow.down", "sportscourt", "pencil",
                        "custom.arm", "custom.leg", "custom.toe"]
    static let customIcons: Set<String> = ["custom.arm", "custom.leg", "custom.toe"]

    static func isCustomIcon(_ name: String) -> Bool { customIcons.contains(name) }
    static let colors: [(name: String, color: Color)] = [
        ("indigo", AppColors.indigo),
        ("mint", AppColors.mint),
        ("coral", AppColors.coral),
        ("slate", Color(.systemGray)),
        ("blue", Color(.systemBlue)),
        ("purple", Color(.systemPurple)),
        ("teal", Color(.systemTeal)),
        ("orange", .orange)
    ]
    static func color(for name: String) -> Color {
        colors.first(where: { $0.name == name })?.color ?? AppColors.indigo
    }
}

// Renders SF Symbol or custom SVG icon with gradient fill, standalone (no background shape)
struct GoalIconImage: View {
    let name: String
    let color: Color
    let size: CGFloat

    private var gradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [color, color.opacity(0.55)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        if GoalIconLibrary.isCustomIcon(name) {
            filledShape
                .frame(width: size, height: size)
        } else {
            Image(systemName: name)
                .font(.system(size: size * 0.5, weight: .medium, design: .rounded))
                .foregroundColor(.clear)
                .overlay(
                    gradient.mask(
                        Image(systemName: name)
                            .font(.system(size: size * 0.5, weight: .medium, design: .rounded))
                    )
                )
        }
    }

    @ViewBuilder
    private var filledShape: some View {
        switch name {
        case "custom.arm": ArmIconShape().fill(gradient)
        case "custom.leg": LegIconShape().fill(gradient)
        case "custom.toe": ToeIconShape().fill(gradient)
        default: ArmIconShape().fill(gradient)
        }
    }
}

// MARK: - SVG Path Parser

private func parseSVGPath(_ d: String, in rect: CGRect, viewBox: CGRect) -> Path {
    var path = Path()
    let scaleX = rect.width / viewBox.width
    let scaleY = rect.height / viewBox.height
    let offsetX = -viewBox.minX
    let offsetY = -viewBox.minY

    func scale(_ point: CGPoint, relative: Bool = false) -> CGPoint {
        if relative {
            return CGPoint(x: point.x * scaleX, y: point.y * scaleY)
        }
        return CGPoint(x: (point.x + offsetX) * scaleX, y: (point.y + offsetY) * scaleY)
    }

    var tokens: [String] = []
    var current = ""
    var lastWasDigit = false
    for char in d {
        if char.isLetter {
            if !current.isEmpty { tokens.append(current); current = "" }
            tokens.append(String(char))
            lastWasDigit = false
        } else if char == "-" {
            if lastWasDigit && !current.isEmpty { tokens.append(current); current = String(char) }
            else { current.append(char) }
            lastWasDigit = false
        } else if char == "." || char.isNumber {
            current.append(char)
            lastWasDigit = true
        } else if char == " " || char == "," {
            if !current.isEmpty { tokens.append(current); current = "" }
            lastWasDigit = false
        }
    }
    if !current.isEmpty { tokens.append(current) }

    var cp = CGPoint.zero
    var lastCP = CGPoint.zero
    var i = 0

    while i < tokens.count {
        let token = tokens[i]
        guard let cmd = token.first, token.count == 1, cmd.isLetter else { i += 1; continue }
        i += 1

        func num() -> Double? {
            guard i < tokens.count, let v = Double(tokens[i]) else { return nil }
            i += 1; return v
        }
        func pt(_ rel: Bool) -> CGPoint? {
            guard let x = num(), let y = num() else { return nil }
            return rel ? CGPoint(x: cp.x + x, y: cp.y + y) : CGPoint(x: x, y: y)
        }
        func hasMore() -> Bool { i < tokens.count && tokens[i].first?.isLetter == false }

        switch cmd {
        case "M":
            if let p = pt(false) { path.move(to: scale(p)); cp = p; lastCP = p
                while hasMore() { if let lp = pt(false) { path.addLine(to: scale(lp)); cp = lp; lastCP = lp } else { break } }
            }
        case "m":
            if let p = pt(true) { path.move(to: scale(p)); cp = p; lastCP = p
                while hasMore() { if let lp = pt(true) { path.addLine(to: scale(lp)); cp = lp; lastCP = lp } else { break } }
            }
        case "L":
            while hasMore() { if let p = pt(false) { path.addLine(to: scale(p)); cp = p; lastCP = p } else { break } }
        case "l":
            while hasMore() { if let p = pt(true) { path.addLine(to: scale(p)); cp = p; lastCP = p } else { break } }
        case "H":
            while hasMore() { if let x = num() { let p = CGPoint(x: x, y: cp.y); path.addLine(to: scale(p)); cp = p; lastCP = p } else { break } }
        case "h":
            while hasMore() { if let dx = num() { let p = CGPoint(x: cp.x + dx, y: cp.y); path.addLine(to: scale(p)); cp = p; lastCP = p } else { break } }
        case "V":
            while hasMore() { if let y = num() { let p = CGPoint(x: cp.x, y: y); path.addLine(to: scale(p)); cp = p; lastCP = p } else { break } }
        case "v":
            while hasMore() { if let dy = num() { let p = CGPoint(x: cp.x, y: cp.y + dy); path.addLine(to: scale(p)); cp = p; lastCP = p } else { break } }
        case "C":
            while hasMore() { if let c1 = pt(false), let c2 = pt(false), let e = pt(false) { path.addCurve(to: scale(e), control1: scale(c1), control2: scale(c2)); lastCP = c2; cp = e } else { break } }
        case "c":
            while hasMore() { if let c1 = pt(true), let c2 = pt(true), let e = pt(true) { path.addCurve(to: scale(e), control1: scale(c1), control2: scale(c2)); lastCP = c2; cp = e } else { break } }
        case "S":
            while hasMore() { let r = CGPoint(x: 2*cp.x - lastCP.x, y: 2*cp.y - lastCP.y)
                if let c2 = pt(false), let e = pt(false) { path.addCurve(to: scale(e), control1: scale(r), control2: scale(c2)); lastCP = c2; cp = e } else { break } }
        case "s":
            while hasMore() { let r = CGPoint(x: 2*cp.x - lastCP.x, y: 2*cp.y - lastCP.y)
                if let c2 = pt(true), let e = pt(true) { path.addCurve(to: scale(e), control1: scale(r), control2: scale(c2)); lastCP = c2; cp = e } else { break } }
        case "Z", "z":
            path.closeSubpath()
        default: break
        }
    }
    return path
}

// MARK: - Custom SVG Icon Shapes

struct ArmIconShape: Shape {
    private let pathData = "m70.012 11.109c0.38672-0.78125 1.2383-1.2188 2.0977-1.0859l15.949 2.5 0.17578 0.035156c0.86719 0.21875 1.4922 0.98828 1.5117 1.8984 0.16797 7.5117 0.31641 18.656 0.22656 28.934-0.089844 10.184-0.41797 19.773-1.2578 24-0.86328 4.3281-3.0742 8.8945-5.3945 12.762-2.332 3.8945-4.8633 7.2344-6.5156 9.1523-0.50781 0.58984-1.3164 0.83203-2.0664 0.61719l-13.953-4c-0.03125-0.007813-0.066406-0.019531-0.097656-0.03125-15.156-5.1836-26.875-16.148-36.418-28.105l-11.465 5.0469c-0.61719 0.26953-1.332 0.21094-1.8984-0.15625-0.56641-0.37109-0.90625-1-0.90625-1.6758v-36.5c0-1.1055 0.89453-2 2-2h4.8203c6.3789 0 12.496 2.5391 17 7.0586l29.648 29.746c2.168-3.4531 4.75-7.5781 6.7852-11.746 1.2305-2.5234 2.2266-4.9961 2.8008-7.2734 0.51562-2.0625 0.65625-3.8477 0.39453-5.3203l-8.5859-9.0938c-0.70703-0.75-0.72656-1.9219-0.039062-2.6992l1.3164-1.4844-0.28125-1.2539c-0.097656-0.44922-0.039063-0.91406 0.16406-1.3242zm0.97266 7.0078c0.25 0.089843 0.47656 0.23047 0.67578 0.41016l1.0977 1.0078 0.77344-1.4336 0.078125-0.13672c0.44141-0.67969 1.25-1.0312 2.0547-0.87891l4.9844 0.94922c0.67187 0.12891 1.2305 0.58984 1.4844 1.2266 0.25 0.63672 0.16016 1.3594-0.23828 1.9102l-3.9883 5.5c-0.33594 0.46484-0.85156 0.76172-1.4219 0.81641-0.56641 0.058594-1.1328-0.12891-1.5508-0.51562l-4.4805-4.1211-0.64453 0.72266-0.78125 0.88281 7.7148 8.168 0.085937 0.097656c0.19141 0.23047 0.32812 0.50391 0.40234 0.79297 0.60938 2.4414 0.36328 5.1172-0.29688 7.7461-0.66406 2.6445-1.7852 5.3906-3.0859 8.0547-2.2891 4.6914-5.2461 9.3359-7.4805 12.898l4.3594 4.3711c0.77734 0.78516 0.77734 2.0508-0.007812 2.832-0.78125 0.77734-2.0469 0.77734-2.8242-0.007813l-36.91-37.027c-3.75-3.7656-8.8477-5.8828-14.164-5.8828h-2.8203v31.434l7.3672-3.2422c-1.1484-0.76562-2.4922-1.1914-3.8828-1.1914-1.1055 0-2-0.89453-2-2s0.89453-2 2-2c3.4648 0 6.6797 1.6562 8.7734 4.3477 9.5469 12.262 21 23.211 35.684 28.246l12.645 3.6211c1.4766-1.8281 3.457-4.5352 5.3047-7.6172 2.2266-3.7148 4.168-7.8164 4.8984-11.488 0.75391-3.7734 1.0898-12.934 1.1836-23.254 0.085938-9.4844-0.039062-19.73-0.19141-27.141l-12.844-2.0117zm4.8086 4.2109 0.19141 0.17578 0.82031-1.1289-0.44922-0.085938z"
    func path(in rect: CGRect) -> Path {
        parseSVGPath(pathData, in: rect, viewBox: CGRect(x: -5, y: -10, width: 110, height: 135))
    }
}

struct LegIconShape: Shape {
    private let pathData = "m86 18c0-2.2148-1.7891-4-3.9805-4h-43.746c-5.8281 0-11.105 3.4727-13.426 8.8477-0.46094 1.0742-0.79297 2.1992-0.99219 3.3516l-9.8242 57.461c-0.21094 1.2305 0.73438 2.3398 1.957 2.3398h9.207c0.61719 0 1.1953-0.28516 1.5742-0.78125l9.0547-11.828c2.1445-2.8008 3.5117-6.1172 3.9609-9.6172l1.5625-12.117c0.65234-5.0352 5.7617-8.207 10.559-6.5234l13.031 4.5859c0.25781 0.089844 0.52344 0.15234 0.79688 0.1875l11.02 1.4531h5.2656c2.1914 0 3.9805-1.7852 3.9805-4zm-44.359 1.7578c0.41406-1.0273 1.5781-1.5273 2.6016-1.1133 1.0273 0.41016 1.5273 1.5742 1.1133 2.5977-1.1523 2.8828-5.1875 9.0586-12.594 12.105-1.0195 0.42188-2.1914-0.066406-2.6133-1.0859-0.41797-1.0195 0.070312-2.1914 1.0898-2.6094 6.1953-2.5508 9.5586-7.7773 10.402-9.8945zm48.359 27.602c0 4.4141-3.5664 8-7.9805 8h-5.3945c-0.085938 0-0.17188-0.003906-0.26172-0.015625l-11.152-1.4727c-0.54688-0.070313-1.082-0.19922-1.6016-0.38281l-13.031-4.582c-2.3789-0.83594-4.9375 0.73438-5.2617 3.2617l-1.5625 12.117c-0.54297 4.1953-2.1797 8.1758-4.75 11.535l-9.0586 11.832c-1.1328 1.4805-2.8867 2.3477-4.75 2.3477h-9.207c-3.7188 0-6.5273-3.3555-5.9023-7.0156l9.8281-57.461c0.25-1.4648 0.67578-2.8945 1.2617-4.2578 2.9492-6.8359 9.6641-11.266 17.098-11.266h43.746c4.4141 0 7.9805 3.5898 7.9805 8z"
    func path(in rect: CGRect) -> Path {
        parseSVGPath(pathData, in: rect, viewBox: CGRect(x: -5, y: -10, width: 110, height: 135))
    }
}

struct ToeIconShape: Shape {
    private let pathData = "m69 36h-1v0.5l0.011719 0.10156c0.042969 0.22656 0.24609 0.39844 0.48828 0.39844 0.27734 0 0.5-0.22266 0.5-0.5zm-24.082 2.3203v-19.227c0-2.7891-2.2969-5.0938-5.1875-5.0938s-5.1914 2.3047-5.1914 5.0938v21.227c0 1.1055-0.89453 2-2 2-1.1016 0-1.9961-0.89453-2-2v-14.133c0-4.4688-3.6758-8.1328-8.2695-8.1328s-8.2695 3.6641-8.2695 8.1328v35.34c0 1.9102 0.27344 3.8086 0.8125 5.6406l5.5352 18.832h61.496l3.4727-12.945c0.45312-1.6875 0.68359-3.4336 0.68359-5.1836v-22.871l-0.003906 0.20703c-0.10938 2.1133-1.8555 3.793-3.9961 3.793-2.2109 0-4-1.7891-4-4v-2c0-1.1055 0.89453-2 2-2h4c1.1055 0 2 0.89453 2 2v-0.59766c0-2.2305-1.8398-4.082-4.1602-4.082-2.2539 0-4.0508 1.7383-4.1602 3.8711l-0.003907 0.21094v8.1055c0 1.1016-0.89453 2-2 2s-2-0.89844-2-2v-17.227c0-2.7891-2.2969-5.0938-5.1914-5.0938-2.8906 0-5.1875 2.3047-5.1875 5.0938v9.1211c0 1.1016-0.89453 2-2 2-1.1055-0.003906-2-0.89844-2-2v-17.23c0-2.7852-2.2969-5.0898-5.1875-5.0898-2.8008 0-5.0469 2.1602-5.1836 4.832l-0.007812 0.25781v13.148c0 1.1055-0.89453 2-2 2-1.1016 0-2-0.89453-2-2zm-19.918-11.984c-0.875-0.32813-1.5586-0.48047-2.2422-0.49609-0.72656-0.019532-1.5742 0.10938-2.7578 0.52344v2.1367c0 1.3789 1.1211 2.5 2.5 2.5s2.5-1.1211 2.5-2.5zm29.5 0.66406h-1v0.5l0.011719 0.10156c0.042969 0.22656 0.24609 0.39844 0.48828 0.39844 0.27734 0 0.5-0.22266 0.5-0.5zm-14.5-5h-1v0.5l0.011719 0.10156c0.042969 0.22656 0.24609 0.39844 0.48828 0.39844 0.27734 0 0.5-0.22266 0.5-0.5zm32.992 14.73c-0.11719 2.3789-2.0859 4.2695-4.4922 4.2695-2.4844 0-4.5-2.0156-4.5-4.5v-2.5c0-1.1055 0.89453-2 2-2h5c1.1055 0 2 0.89453 2 2v2.5zm-43.992-8.2305c0 3.5898-2.9102 6.5-6.5 6.5s-6.5-2.9102-6.5-6.5v-3.5c0-0.80078 0.48047-1.5273 1.2148-1.8398 2.1172-0.90234 3.8867-1.3672 5.6484-1.3203s3.3125 0.60156 4.9531 1.332c0.71875 0.32031 1.1836 1.0391 1.1836 1.8281zm29.492-0.76953c-0.11719 2.3789-2.0859 4.2695-4.4922 4.2695-2.4844 0-4.5-2.0156-4.5-4.5v-2.5c0-1.1055 0.89453-2 2-2h5c1.1055 0 2 0.89453 2 2v2.5zm4.8047-1.9531c1.4805-1.0039 3.2695-1.5898 5.1875-1.5898 5.0508 0 9.1914 4.0469 9.1914 9.0938v2.168c1.2227-0.71875 2.6445-1.1289 4.1641-1.1289 4.4805 0 8.1602 3.5938 8.1602 8.082v25.469c0 2.1016-0.27344 4.1953-0.82031 6.2227l-3.8711 14.426c-0.23438 0.87109-1.0273 1.4805-1.9297 1.4805h-64.527c-0.88672 0-1.668-0.58594-1.918-1.4336l-5.9609-20.27c-0.64453-2.1992-0.97266-4.4805-0.97266-6.7695v-35.34c0-6.7266 5.5195-12.133 12.27-12.133 3.2617 0 6.2344 1.2617 8.4375 3.3242 0.80859-4.2188 4.5586-7.3789 9.0234-7.3789 4.5898 0 8.4258 3.3438 9.0859 7.7383 1.5-1.043 3.3281-1.6562 5.293-1.6562 5.0469 0 9.1875 4.043 9.1875 9.0898zm-19.305-3.0469c-0.11719 2.3789-2.0859 4.2695-4.4922 4.2695-2.4844 0-4.5-2.0156-4.5-4.5v-2.5c0-1.1055 0.89453-2 2-2h5c1.1055 0 2 0.89453 2 2v2.5z"
    func path(in rect: CGRect) -> Path {
        parseSVGPath(pathData, in: rect, viewBox: CGRect(x: -5, y: -10, width: 110, height: 135))
    }
}

// MARK: - Custom Pencil Icon (from SVG)

struct ReflectPencilShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let sx = w / 100
        let sy = h / 100

        var path = Path()
        // Main pencil body
        path.move(to: CGPoint(x: 82.6 * sx, y: 16.9 * sy))
        path.addCurve(to: CGPoint(x: 78.2 * sx, y: 9.8 * sy),
                      control1: CGPoint(x: 82.1 * sx, y: 14.0 * sy),
                      control2: CGPoint(x: 80.6 * sx, y: 11.5 * sy))
        path.addLine(to: CGPoint(x: 73.1 * sx, y: 6.0 * sy))
        path.addCurve(to: CGPoint(x: 66.7 * sx, y: 3.9 * sy),
                      control1: CGPoint(x: 71.2 * sx, y: 4.6 * sy),
                      control2: CGPoint(x: 68.6 * sx, y: 3.9 * sy))
        path.addCurve(to: CGPoint(x: 57.8 * sx, y: 8.4 * sy),
                      control1: CGPoint(x: 63.2 * sx, y: 3.9 * sy),
                      control2: CGPoint(x: 59.9 * sx, y: 5.6 * sy))
        path.addLine(to: CGPoint(x: 14.7 * sx, y: 68.0 * sy))
        path.addCurve(to: CGPoint(x: 14.5 * sx, y: 68.3 * sy),
                      control1: CGPoint(x: 14.6 * sx, y: 68.1 * sy),
                      control2: CGPoint(x: 14.6 * sx, y: 68.2 * sy))
        path.addCurve(to: CGPoint(x: 14.4 * sx, y: 68.7 * sy),
                      control1: CGPoint(x: 14.5 * sx, y: 68.4 * sy),
                      control2: CGPoint(x: 14.5 * sx, y: 68.5 * sy))
        path.addLine(to: CGPoint(x: 12.3 * sx, y: 93.5 * sy))
        path.addCurve(to: CGPoint(x: 12.9 * sx, y: 94.8 * sy),
                      control1: CGPoint(x: 12.3 * sx, y: 94.0 * sy),
                      control2: CGPoint(x: 12.5 * sx, y: 94.5 * sy))
        path.addCurve(to: CGPoint(x: 14.4 * sx, y: 95.0 * sy),
                      control1: CGPoint(x: 13.2 * sx, y: 95.0 * sy),
                      control2: CGPoint(x: 13.8 * sx, y: 95.1 * sy))
        path.addLine(to: CGPoint(x: 36.9 * sx, y: 85.0 * sy))
        path.addCurve(to: CGPoint(x: 37.5 * sx, y: 84.5 * sy),
                      control1: CGPoint(x: 37.1 * sx, y: 84.9 * sy),
                      control2: CGPoint(x: 37.4 * sx, y: 84.7 * sy))
        path.addLine(to: CGPoint(x: 37.6 * sx, y: 84.4 * sy))
        path.addLine(to: CGPoint(x: 80.7 * sx, y: 25.0 * sy))
        path.addCurve(to: CGPoint(x: 82.6 * sx, y: 16.9 * sy),
                      control1: CGPoint(x: 82.4 * sx, y: 22.7 * sy),
                      control2: CGPoint(x: 83.1 * sx, y: 19.8 * sy))
        path.closeSubpath()
        return path
    }
}

struct ReflectPencilIcon: View {
    var size: CGFloat = 20
    var color: Color = .primary

    var body: some View {
        ReflectPencilShape()
            .fill(color)
            .frame(width: size, height: size)
    }
}

struct GoalIconColorPicker: View {
    @Binding var iconName: String
    @Binding var colorName: String

    private var selectedColor: Color { GoalIconLibrary.color(for: colorName) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            let columns = 6
            let rowCount = (GoalIconLibrary.icons.count + columns - 1) / columns
            VStack(spacing: 10) {
                ForEach(0..<rowCount, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(0..<columns, id: \.self) { col in
                            let idx = row * columns + col
                            if idx < GoalIconLibrary.icons.count {
                                let icon = GoalIconLibrary.icons[idx]
                                let isSelected = iconName == icon
                                Button(action: { iconName = icon }) {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(isSelected ? selectedColor.opacity(0.16) : Color(.systemGray6))
                                        .frame(height: 52)
                                        .overlay(GoalIconImage(name: icon, color: isSelected ? selectedColor : Color(.systemGray), size: 24))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? selectedColor.opacity(0.4) : Color.clear, lineWidth: 1.5))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .frame(maxWidth: .infinity)
                            } else {
                                Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 0) {
                ForEach(GoalIconLibrary.colors, id: \.name) { item in
                    Button(action: { colorName = item.name }) {
                        ZStack {
                            Circle().fill(item.color).frame(width: 32, height: 32)
                            if colorName == item.name {
                                Circle().stroke(item.color, lineWidth: 2.5).frame(width: 42, height: 42)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}
