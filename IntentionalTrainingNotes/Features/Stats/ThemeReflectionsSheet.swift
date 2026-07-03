import SwiftUI

/// Identifies the theme whose reflections are shown in the drill-down sheet
/// launched from the Stat tab's feedback lists.
struct ThemeReflectionsContext: Identifiable {
    enum Kind { case working, stuck }
    let kind: Kind
    let theme: String
    let reflectionIds: [String]
    let accent: Color

    var id: String { "\(kind == .working ? "w" : "s")-\(theme)" }
    var filter: PatternKind { kind == .working ? .wins : .stuck }
    var headline: String { kind == .working ? "What's working" : "Where you're stuck" }
}

/// Self-contained list of the reflections that produced a given theme this month.
struct ThemeReflectionsSheet: View {
    @ObservedObject var store: NotebookStore
    let context: ThemeReflectionsContext
    let onClose: () -> Void

    private var reflections: [Reflection] {
        let ids = Set(context.reflectionIds)
        return store.notebook.reflections
            .filter { ids.contains($0.id) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(reflections) { reflection in
                        ReflectionCardView(
                            store: store,
                            reflection: reflection,
                            onReflect: {},
                            onDelete: {},
                            onShareFeedback: {},
                            filter: context.filter,
                            showShareButton: false,
                            showMenu: false
                        )
                    }
                    if reflections.isEmpty {
                        EmptyDashedState(title: "No entries", subtitle: "These reflections are no longer available.")
                            .padding(.top, 20)
                    }
                }
                .padding(16)
                .padding(.bottom, 30)
            }
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(context.headline.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundColor(context.accent)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppColors.secondaryLabel)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(AppColors.cardBackground))
                }
                .buttonStyle(PlainButtonStyle())
            }
            HStack(spacing: 10) {
                Text("\(context.reflectionIds.count)×")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(context.accent)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(context.accent.opacity(0.14)))
                Text(context.theme)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(AppColors.label)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }
}
