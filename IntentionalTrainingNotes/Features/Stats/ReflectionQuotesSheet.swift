import SwiftUI

/// Identifies which reflection(s) to open in the drill-down sheet launched from a
/// Stat tab feedback quote.
struct ReflectionQuotesContext: Identifiable {
    enum Kind { case working, stuck }
    let kind: Kind
    let reflectionIds: [String]
    let accent: Color

    var id: String { "\(kind == .working ? "w" : "s")-\(reflectionIds.joined(separator: ","))" }
    var filter: PatternKind { kind == .working ? .wins : .stuck }
    var headline: String { kind == .working ? "What's working" : "Where you're stuck" }
}

/// Self-contained list of the reflection(s) behind a Stat feedback quote.
struct ReflectionQuotesSheet: View {
    @ObservedObject var store: NotebookStore
    let context: ReflectionQuotesContext
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
                        EmptyDashedState(title: "No entries", subtitle: "This reflection is no longer available.")
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
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }
}
