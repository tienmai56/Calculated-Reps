import SwiftUI
import UIKit

struct ReflectionCardView: View {
    @ObservedObject var store: NotebookStore
    let reflection: Reflection
    var onReflect: () -> Void
    var onDelete: () -> Void
    var onShareFeedback: () -> Void
    var filter: PatternKind = .all
    /// When true, header shows date + mood label instead of the goal name. Used by the
    /// per-task reflections screen where the goal/task context is already in the screen header.
    var dateMode: Bool = false
    /// When false, hides the "Get feedback" share button (used in contexts where sharing is out of scope).
    var showShareButton: Bool = true
    /// When false, hides the "..." overflow menu (edit/delete). Used by read-only-ish surfaces
    /// like the per-task reflections list where the only meaningful in-place action is favorite.
    var showMenu: Bool = true

    @State private var menuOpen = false

    var body: some View {
        let session = store.notebook.sessions.first { $0.id == reflection.sessionId }
        let goal = session.flatMap { store.goal(id: $0.goalId) }
        let color = goal?.goalColor ?? AppColors.indigo

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                if let mood = reflection.mood {
                    Text(mood.glyph).font(.system(size: 26))
                }
                if dateMode {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.dateLabel(reflection.date))
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.label)
                        if let mood = reflection.mood {
                            Text(mood.label)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(AppColors.secondaryLabel)
                        }
                    }
                } else {
                    Text(goal?.name ?? "Session")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                if showShareButton {
                    Button(action: onShareFeedback) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.indigo)
                            .frame(width: 32, height: 28)
                            .background(Capsule().fill(AppColors.indigo.opacity(0.10)))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Button(action: { store.toggleFavorite(reflectionId: reflection.id) }) {
                    Image(systemName: reflection.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 17))
                        .foregroundColor(reflection.isFavorite ? AppColors.coral : AppColors.tertiaryLabel)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(PlainButtonStyle())
                if showMenu {
                    Button(action: { withAnimation(.easeInOut(duration: 0.15)) { menuOpen.toggle() } }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.secondaryLabel)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            if shows(.wins), let s = reflection.workedText.nilIfBlank {
                sectionBlock(text: s, accent: AppColors.winGreen, tintUI: AppColors.winGreenUI, label: "What worked")
            }
            if shows(.stuck), let s = reflection.stuckText.nilIfBlank {
                sectionBlock(text: s, accent: AppColors.stuckCoral, tintUI: AppColors.stuckCoralUI, label: "Where I got stuck")
            }
            if shows(.upNext), let s = reflection.tryNextText.nilIfBlank {
                sectionBlock(text: s, accent: AppColors.indigo, tintUI: AppColors.indigoUI, label: "What I'll try next")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.cardBackground))
        .overlay(menuOverlay, alignment: .topTrailing)
    }

    private static func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    private func shows(_ kind: PatternKind) -> Bool {
        filter == .all || filter == kind
    }

    private func sectionBlock(text: String, accent: Color, tintUI: UIColor, label: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(accent)
                Text(text)
                    .font(.matMindBody(size: 15))
                    .foregroundColor(AppColors.label)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.tint(tintUI, light: 0.10, dark: 0.22)))
    }

    @ViewBuilder
    private var menuOverlay: some View {
        if menuOpen {
            ZStack(alignment: .topTrailing) {
                Color.black.opacity(0.001)
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .fixedSize()
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { menuOpen = false } }

                VStack(alignment: .leading, spacing: 0) {
                    Button(action: { menuOpen = false; onReflect() }) {
                        menuRowLabel(icon: "pencil", label: "Edit", color: AppColors.label)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Divider().padding(.horizontal, 10)
                    Button(action: { menuOpen = false; onDelete() }) {
                        menuRowLabel(icon: "trash", label: "Delete", color: AppColors.coral)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .background(AppColors.background)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 2)
                .frame(width: 150)
                .padding(.top, 40)
                .padding(.trailing, 6)
            }
        }
    }

    private func menuRowLabel(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.matMindBody(size: 14)).foregroundColor(color)
            Text(label).font(.matMindBody(size: 15)).foregroundColor(color)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Feedback share card

struct FeedbackCardView: View {
    let goalName: String
    let tryNextText: String
    let mood: Mood?
    let dateLabel: String
    let recipient: String
    let accent: Color

    private var tryNextLines: [String] {
        tryNextText
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(dateLabel)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(accent)
                Rectangle().fill(accent).frame(width: 60, height: 3).cornerRadius(2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Dear \(recipient.nilIfBlank ?? "Friend"),")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 44/255, green: 42/255, blue: 41/255))
                Text("Please fix my jiu-jitsu:")
                    .font(.matMindBody(size: 16))
                    .foregroundColor(Color(red: 120/255, green: 117/255, blue: 113/255))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("What I was working on")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(accent)
                Text(goalName)
                    .font(.system(size: 18, design: .rounded))
                    .foregroundColor(Color(red: 44/255, green: 42/255, blue: 41/255))
            }
            if !tryNextLines.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What I'll try next")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(accent)
                    ForEach(Array(tryNextLines.enumerated()), id: \.offset) { idx, line in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(idx + 1)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(accent)
                            Text(line)
                                .font(.system(size: 18, design: .rounded))
                                .foregroundColor(Color(red: 44/255, green: 42/255, blue: 41/255))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            if let mood = mood {
                HStack(spacing: 6) {
                    Text("Feeling:")
                        .font(.matMindBody(size: 16))
                        .foregroundColor(Color(red: 120/255, green: 117/255, blue: 113/255))
                    Text("\(mood.glyph) \(mood.label)")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(Color(red: 44/255, green: 42/255, blue: 41/255))
                }
            }
            Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1)
            VStack(alignment: .leading, spacing: 2) {
                Text("Thank you, see you on the mat.")
                    .font(.matMindBody(size: 16))
                    .foregroundColor(Color(red: 44/255, green: 42/255, blue: 41/255))
                Text("xoxo")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(accent)
            }
            Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1)
            VStack(spacing: 2) {
                Text("Mat Mind")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(accent)
                Text("matmind.com")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(Color(red: 165/255, green: 161/255, blue: 155/255))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.offWhite))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.3), lineWidth: 1))
    }
}

struct FeedbackPreviewView: View {
    @ObservedObject var store: NotebookStore
    let reflection: Reflection
    var onClose: () -> Void

    @State private var recipient = ""
    @State private var accentName = "indigo"

    private let styles: [(name: String, color: Color)] = [
        ("indigo", AppColors.indigo),
        ("mint", AppColors.mint),
        ("coral", AppColors.coral),
        ("slate", Color(.systemGray)),
        ("blue", Color(.systemBlue)),
        ("purple", Color(.systemPurple)),
        ("teal", Color(.systemTeal))
    ]
    private var accent: Color { styles.first { $0.name == accentName }?.color ?? AppColors.indigo }

    private var goalName: String {
        guard let s = store.notebook.sessions.first(where: { $0.id == reflection.sessionId }) else { return "Training" }
        return store.goal(id: s.goalId)?.name ?? "Training"
    }
    private var dateLabel: String {
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d, yyyy"; return f.string(from: reflection.date)
    }
    private var card: FeedbackCardView {
        FeedbackCardView(goalName: goalName, tryNextText: reflection.tryNextText, mood: reflection.mood, dateLabel: dateLabel, recipient: recipient, accent: accent)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.label)
                        .frame(width: 44, height: 44)
                }
                Spacer()
                Text("Preview").font(.system(size: 18, weight: .semibold, design: .rounded))
                Spacer()
                Spacer().frame(width: 44)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 8) {
                        Text("To:").font(.system(size: 17, weight: .bold, design: .rounded)).foregroundColor(AppColors.label)
                        TextField("Friend's name", text: $recipient).font(.system(size: 17, design: .rounded))
                    }
                    .padding(.bottom, 8)
                    .overlay(Rectangle().fill(Color(.systemGray4)).frame(height: 1), alignment: .bottom)

                    card

                    VStack(alignment: .leading, spacing: 12) {
                        Text("CARD STYLE")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .kerning(0.5)
                            .foregroundColor(AppColors.secondaryLabel)
                            .frame(maxWidth: .infinity)
                        HStack(spacing: 10) {
                            ForEach(styles, id: \.name) { style in
                                Button(action: { accentName = style.name }) {
                                    ZStack {
                                        Circle().fill(style.color).frame(width: 36, height: 36)
                                        if accentName == style.name {
                                            Circle().stroke(style.color, lineWidth: 2).frame(width: 46, height: 46)
                                        }
                                    }
                                    .frame(width: 46, height: 46)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(16)
            }

            Button(action: share) {
                Text("Share")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 28).fill(AppColors.indigo))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }

    private func share() {
        let image = ShareSnapshot.image(of: card, width: 360)
        let activity = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        guard let root = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        if let pop = activity.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY - 80, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        top.present(activity, animated: true)
    }
}

// MARK: - Day Trend Point
