import SwiftUI

enum PlanSubTab {
    case training
    case competition
}

struct PlanListView: View {
    @ObservedObject var store: NotebookStore
    var onAdd: () -> Void
    var onReflect: (String) -> Void

    @State private var planTab: PlanSubTab = .training
    @State private var displayedMonth: Date = Date()
    @State private var selectedDate: Date = Date()
    @State private var editingSession: PlannedSession?
    @State private var showDeleteConfirm = false
    @State private var sessionToDelete: PlannedSession?
    @State private var feedbackReflection: Reflection?

    private var cal: Calendar { Calendar.current }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                ScreenHeader(
                    titleLead: "Plan your",
                    titleAccent: planTab == .training ? "training" : "competition",
                    accent: AppColors.indigo,
                    titleSize: 26
                )
                Spacer()
                if planTab == .training {
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.indigo)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            subTabBar
                .padding(.horizontal, 16)
                .padding(.top, 10)

            if planTab == .training {
                trainingContent
            } else {
                CompetitionView(store: store)
            }
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
        .sheet(item: $editingSession) { session in
            EditSessionView(store: store, session: session) {
                editingSession = nil
            }
        }
        .sheet(item: $feedbackReflection) { reflection in
            FeedbackPreviewView(store: store, reflection: reflection, onClose: { feedbackReflection = nil })
        }
        .overlay(deleteDialog)
    }

    // MARK: - Sub-tabs (Training / Competition) — matches Home's sub-tab bar

    private var subTabBar: some View {
        HStack(spacing: 26) {
            subTab("Training", .training)
            subTab("Competition", .competition)
            Spacer(minLength: 0)
        }
        .overlay(
            Rectangle()
                .fill(AppColors.separator.opacity(0.5))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func subTab(_ title: String, _ tab: PlanSubTab) -> some View {
        let isActive = planTab == tab
        return Button(action: { withAnimation(.easeInOut(duration: 0.2)) { planTab = tab } }) {
            VStack(spacing: 7) {
                Text(title)
                    .font(.system(size: 17, weight: isActive ? .semibold : .medium, design: .rounded))
                    .foregroundColor(isActive ? AppColors.label : AppColors.secondaryLabel)
                Rectangle()
                    .fill(isActive ? AppColors.indigo : Color.clear)
                    .frame(height: 3)
                    .cornerRadius(1.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Training content

    private var trainingContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    calendarCard
                    selectedDaySection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
        }
    }

    @ViewBuilder
    private var deleteDialog: some View {
        if showDeleteConfirm, let session = sessionToDelete {
            ConfirmDialog(
                title: "Delete Session",
                message: "This will permanently delete this planned session and any associated reflection.",
                onConfirm: {
                    store.deleteSession(id: session.id)
                    sessionToDelete = nil
                    showDeleteConfirm = false
                },
                onCancel: {
                    sessionToDelete = nil
                    showDeleteConfirm = false
                }
            )
        }
    }

    // MARK: Calendar card

    private var calendarCard: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: { shiftMonth(-1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.indigo)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                Spacer()
                HStack(spacing: 8) {
                    Text(monthTitle)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.label)
                    Text("\(monthEntryCount) \(monthEntryCount == 1 ? "Entry" : "Entries")")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.indigo)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(AppColors.indigo.opacity(0.12)))
                }
                Spacer()
                Button(action: { shiftMonth(1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.indigo)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
            }

            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { wd in
                    Text(wd)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(AppColors.secondaryLabel)
                        .frame(maxWidth: .infinity)
                }
            }

            let days = gridDays
            let rows = (days.count + 6) / 7
            VStack(spacing: 6) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let idx = row * 7 + col
                            if idx < days.count, let date = days[idx] {
                                dayCell(date)
                            } else {
                                Color.clear.frame(maxWidth: .infinity, minHeight: 48)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.cardBorder, lineWidth: 1))
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = cal.isDate(date, inSameDayAs: selectedDate)
        let isToday = cal.isDateInToday(date)
        let glyph = moodGlyph(on: date)
        let planned = glyph == nil && hasPlan(on: date)
        return Button(action: { selectedDate = date }) {
            VStack(spacing: 1) {
                ZStack {
                    if isSelected {
                        Circle().fill(AppColors.indigo).frame(width: 34, height: 34)
                    } else if isToday {
                        Circle().stroke(AppColors.indigo, lineWidth: 1.5).frame(width: 34, height: 34)
                    }
                    Text("\(cal.component(.day, from: date))")
                        .font(.matMonkeysBody(size: 16))
                        .foregroundColor(isSelected ? .white : AppColors.label)
                }
                .frame(height: 34)
                ZStack {
                    if let glyph = glyph {
                        Text(glyph).font(.system(size: 12))
                    } else if planned {
                        Circle().fill(AppColors.coral).frame(width: 6, height: 6)
                    }
                }
                .frame(height: 14)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: Selected day

    private var selectedDaySection: some View {
        let daySessions = sessions(on: selectedDate)
        return VStack(alignment: .leading, spacing: 12) {
            Text(longDateLabel)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.label)
            if daySessions.isEmpty {
                VStack(spacing: 14) {
                    Text("Nothing planned.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.secondaryLabel)
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(AppColors.indigo))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.cardBackground))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.cardBorder, lineWidth: 1))
            } else {
                ForEach(daySessions) { session in
                    if let reflection = store.reflection(forSessionId: session.id) {
                        ReflectionCardView(
                            store: store,
                            reflection: reflection,
                            onReflect: { onReflect(session.id) },
                            onDelete: { store.deleteReflection(id: reflection.id) },
                            onShareFeedback: { feedbackReflection = reflection }
                        )
                    } else {
                        PlannedSessionCard(
                            store: store,
                            session: session,
                            onReflect: { onReflect(session.id) },
                            onEdit: { editingSession = session },
                            onDelete: { sessionToDelete = session; showDeleteConfirm = true }
                        )
                        .zIndex(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Helpers

    private var weekdaySymbols: [String] { ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] }

    private var monthFirst: Date {
        cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
    }

    private var monthTitle: String {
        return DateFormatter.monthYear.string(from: monthFirst)
    }

    private var longDateLabel: String {
        return DateFormatter.weekdayShortDateYear.string(from: selectedDate)
    }

    private var gridDays: [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: monthFirst) else { return [] }
        let weekdayOfFirst = cal.component(.weekday, from: monthFirst) // 1 = Sunday
        var days: [Date?] = Array(repeating: nil, count: weekdayOfFirst - 1)
        for d in range {
            days.append(cal.date(byAdding: .day, value: d - 1, to: monthFirst))
        }
        return days
    }

    private var monthEntryCount: Int {
        store.notebook.sessions.filter { cal.isDate($0.date, equalTo: monthFirst, toGranularity: .month) }.count
    }

    private func sessions(on date: Date) -> [PlannedSession] {
        store.notebook.sessions
            .filter { cal.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func moodGlyph(on date: Date) -> String? {
        store.notebook.reflections
            .filter { cal.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first?.mood?.glyph
    }

    private func hasPlan(on date: Date) -> Bool {
        store.notebook.sessions.contains { cal.isDate($0.date, inSameDayAs: date) }
    }

    private func shiftMonth(_ delta: Int) {
        if let d = cal.date(byAdding: .month, value: delta, to: monthFirst) {
            displayedMonth = d
        }
    }
}

// MARK: - Edit Session


// MARK: - Competition sub-tab

private enum CompSheet: Identifiable {
    case new
    case edit(Competition)
    case result(Competition)
    case reflect(Competition)
    case reflectionSummary(Competition)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let c): return "edit-\(c.id)"
        case .result(let c): return "result-\(c.id)"
        case .reflect(let c): return "reflect-\(c.id)"
        case .reflectionSummary(let c): return "summary-\(c.id)"
        }
    }
}

/// The Competition sub-tab under Plan. Upcoming competitions surface as gold "NEXT UP"
/// cards with an editable strategy; logged competitions live under "Past competitions".
struct CompetitionView: View {
    @ObservedObject var store: NotebookStore

    @State private var sheet: CompSheet?
    // Inline strategy-focus editing
    @State private var editingFocusId: String?
    @State private var focusDraft: String = ""
    @State private var addingFocusCompId: String?
    @State private var newFocusDraft: String = ""
    // Confirmation dialogs
    @State private var focusToDelete: FocusRef?
    @State private var competitionToDelete: Competition?
    // iOS 13 ActionSheet fallback (Menu requires iOS 14+)
    @State private var fallbackMenu: ActiveMenu?
    @State private var showCompNotYet = false
    @State private var expandedReflectionId: String?
    private struct FocusRef: Identifiable { let competitionId: String; let focusId: String; var id: String { focusId } }

    private enum ActiveMenu: Identifiable {
        case competition(Competition)
        case focus(FocusRef)
        var id: String {
            switch self {
            case .competition(let c): return "c-\(c.id)"
            case .focus(let r): return "f-\(r.focusId)"
            }
        }
    }

    private func presentSheet(_ s: CompSheet) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { sheet = s }
    }

    private var cal: Calendar { Calendar.current }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headerRow
                if store.notebook.competitions.isEmpty {
                    emptyState
                } else {
                    if !store.upcomingCompetitions.isEmpty { nextUpSection }
                    pastSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .new:
                CompetitionEditView(store: store, competition: nil, onClose: { sheet = nil })
            case .edit(let c):
                CompetitionEditView(store: store, competition: c, onClose: { sheet = nil })
            case .result(let c):
                CompetitionResultView(store: store, competitionId: c.id, onClose: { sheet = nil })
            case .reflect(let c):
                CompetitionReflectFlowView(store: store, competitionId: c.id, resetToken: UUID(), onClose: { sheet = nil })
            case .reflectionSummary(let c):
                CompetitionReflectionSummaryView(store: store, competitionId: c.id, onClose: { sheet = nil })
            }
        }
        .overlay(dialogs)
        .actionSheet(item: $fallbackMenu) { menu in
            switch menu {
            case .competition(let c): return competitionActionSheet(c)
            case .focus(let r): return focusActionSheet(r)
            }
        }
        .alert(isPresented: $showCompNotYet) {
            Alert(
                title: Text("Competition hasn't happened yet"),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: ActionSheet fallback (iOS 13)

    private func competitionActionSheet(_ comp: Competition) -> ActionSheet {
        var buttons: [ActionSheet.Button] = []
        if comp.hasResult {
            buttons.append(.default(Text("Edit result")) { presentSheet(.result(comp)) })
        }
        buttons.append(.default(Text("Edit details")) { presentSheet(.edit(comp)) })
        buttons.append(.destructive(Text("Delete")) { competitionToDelete = comp })
        buttons.append(.cancel())
        return ActionSheet(title: Text(comp.name.nilIfBlank ?? "Competition"), buttons: buttons)
    }

    private func focusActionSheet(_ ref: FocusRef) -> ActionSheet {
        ActionSheet(title: Text("Strategy focus"), buttons: [
            .default(Text("Edit")) {
                if let comp = store.competition(id: ref.competitionId),
                   let f = comp.strategy.first(where: { $0.id == ref.focusId }) {
                    editingFocusId = f.id
                    focusDraft = f.text
                }
            },
            .destructive(Text("Delete")) { focusToDelete = ref },
            .cancel()
        ])
    }

    // MARK: Header

    private var headerRow: some View {
        HStack {
            Spacer()
            Button(action: { sheet = .new }) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.indigo)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("🏆")
                .font(.system(size: 34))
            Text("No competitions yet.")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.label)
            Text("Add a tournament to plan your strategy, then log the result and reflect after.")
                .font(.matMonkeysBody(size: 14))
                .foregroundColor(AppColors.secondaryLabel)
                .multilineTextAlignment(.center)
            Button(action: { sheet = .new }) {
                Text("Add a competition")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(AppColors.indigo))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 18)
        .background(RoundedRectangle(cornerRadius: 20).fill(AppColors.tint(AppColors.indigoUI, light: 0.08, dark: 0.16)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.indigo.opacity(0.3), lineWidth: 1))
    }

    // MARK: Next up

    private var nextUpSection: some View {
        let upcoming = store.upcomingCompetitions
        return VStack(alignment: .leading, spacing: 12) {
            if let next = upcoming.first {
                sectionLabel("Next up", trailing: daysAway(next.date))
                upcomingCard(next)
            }
            if upcoming.count > 1 {
                sectionLabel("Later", trailing: nil)
                    .padding(.top, 6)
                ForEach(Array(upcoming.dropFirst())) { comp in
                    upcomingCard(comp)
                }
            }
        }
    }

    private var pastSection: some View {
        let past = store.pastCompetitions
        return VStack(alignment: .leading, spacing: 12) {
            if !past.isEmpty {
                sectionLabel("Past competitions", trailing: nil)
                    .padding(.top, 6)
                ForEach(past) { comp in
                    pastCard(comp)
                }
            }
        }
    }

    private func sectionLabel(_ text: String, trailing: String?) -> some View {
        HStack {
            Text(text.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.4)
                .foregroundColor(AppColors.tertiaryLabel)
            Spacer()
            if let trailing = trailing {
                Text(trailing)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(0.5)
                    .foregroundColor(AppColors.secondaryLabel)
            }
        }
    }

    // MARK: Upcoming card

    @ViewBuilder
    private func upcomingCard(_ comp: Competition) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Eyebrow
            HStack {
                Text("◆ UPCOMING")
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                if let divRank = divisionRank(comp) {
                    Text(divRank)
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                        .foregroundColor(.white.opacity(0.9))
                }
                if #available(iOS 14.0, *) {
                    Menu {
                        Button(action: { presentSheet(.edit(comp)) }) {
                            Label("Edit details", systemImage: "pencil")
                        }
                        Button(action: { competitionToDelete = comp }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 28, height: 24)
                            .contentShape(Rectangle())
                    }
                } else {
                    Button(action: { fallbackMenu = .competition(comp) }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 28, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Title
            HStack(spacing: 11) {
                Text("🏆")
                    .font(.system(size: 18))
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.22)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(comp.name.nilIfBlank ?? "Competition")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text(dateVenue(comp))
                        .font(.matMonkeysBody(size: 13))
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer(minLength: 0)
            }

            // Strategy
            Text("● STRATEGY")
                .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundColor(.white.opacity(0.9))

            VStack(spacing: 8) {
                ForEach(Array(comp.strategy.enumerated()), id: \.element.id) { idx, focus in
                    focusRow(comp, focus, index: idx)
                }
                addFocusRow(comp)
            }

            // Log result
            Button(action: {
                let isFuture = Calendar.current.startOfDay(for: comp.date) > Calendar.current.startOfDay(for: Date())
                if isFuture {
                    showCompNotYet = true
                } else {
                    sheet = .result(comp)
                }
            }) {
                Text("Log result")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.coralDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
            }
            .buttonStyle(PlainButtonStyle())

            if comp.hasReflection && expandedReflectionId == comp.id {
                inlineReflectionContentLight(comp)
            }

            reflectFooter(comp)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [AppColors.coral, AppColors.coralDeep]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(22)
    }

    private func focusNumber(_ i: Int) -> some View {
        Text("\(i + 1)")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(AppColors.coralDeep)
            .frame(width: 18, height: 18)
            .background(Circle().fill(Color.white))
    }

    @ViewBuilder
    private func focusRow(_ comp: Competition, _ focus: StrategyFocus, index: Int) -> some View {
        HStack(alignment: .center, spacing: 10) {
            focusNumber(index)
            if editingFocusId == focus.id {
                TextField("Focus", text: $focusDraft, onCommit: { commitFocusEdit(comp, focus) })
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .accentColor(.white)
                Button(action: { commitFocusEdit(comp, focus) }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Text(focus.text)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                if #available(iOS 14.0, *) {
                    Menu {
                        Button(action: {
                            editingFocusId = focus.id
                            focusDraft = focus.text
                        }) {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(action: { focusToDelete = FocusRef(competitionId: comp.id, focusId: focus.id) }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 26, height: 24)
                            .contentShape(Rectangle())
                    }
                } else {
                    Button(action: { fallbackMenu = .focus(FocusRef(competitionId: comp.id, focusId: focus.id)) }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 26, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 11).fill(Color.white.opacity(0.15)))
    }

    @ViewBuilder
    private func addFocusRow(_ comp: Competition) -> some View {
        if addingFocusCompId == comp.id {
            HStack(spacing: 10) {
                focusNumber(comp.strategy.count)
                TextField("New focus", text: $newFocusDraft, onCommit: { commitNewFocus(comp) })
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .accentColor(.white)
                Button(action: { commitNewFocus(comp) }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 11).fill(Color.white.opacity(0.15)))
        } else {
            Button(action: { addingFocusCompId = comp.id; newFocusDraft = "" }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("Add focus")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Spacer(minLength: 0)
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 11)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func reflectFooter(_ comp: Competition) -> some View {
        let isExpanded = comp.hasReflection && expandedReflectionId == comp.id
        return VStack(spacing: 0) {
            Rectangle().fill(Color.white.opacity(0.25)).frame(height: 1)
            Button(action: {
                if comp.hasReflection {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        expandedReflectionId = isExpanded ? nil : comp.id
                    }
                } else {
                    openReflect(comp)
                }
            }) {
                HStack(spacing: 6) {
                    Text(comp.hasReflection ? "Reflected" : "Reflect after competition")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Image(systemName: isExpanded ? "chevron.up" : (comp.hasReflection ? "chevron.down" : "chevron.right"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: Past card

    @ViewBuilder
    private func pastCard(_ comp: Competition) -> some View {
        let resultLabel: String = {
            switch comp.result {
            case .win: return "Win"
            case .draw: return "Draw"
            case .loss, .none: return "Loss"
            }
        }()
        let resultColor: Color = {
            switch comp.result {
            case .win: return AppColors.winGreen
            case .draw: return AppColors.indigo
            case .loss, .none: return AppColors.secondaryLabel
            }
        }()
        let resultGlyph = comp.result == .win ? "🏆" : "•"
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Text(resultGlyph)
                        .font(.system(size: 12))
                    Text("\(resultLabel) · \(comp.recordString)")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                }
                .foregroundColor(resultColor)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(resultColor.opacity(0.14)))
                Spacer()
                Text(DateFormatter.monthDay.string(from: comp.date))
                    .font(.matMonkeysBody(size: 13))
                    .foregroundColor(AppColors.secondaryLabel)
                if #available(iOS 14.0, *) {
                    Menu {
                        if comp.hasResult {
                            Button(action: { presentSheet(.result(comp)) }) {
                                Label("Edit result", systemImage: "list.bullet.clipboard")
                            }
                        }
                        Button(action: { presentSheet(.edit(comp)) }) {
                            Label("Edit details", systemImage: "pencil")
                        }
                        Button(action: { competitionToDelete = comp }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.tertiaryLabel)
                            .frame(width: 28, height: 24)
                            .contentShape(Rectangle())
                    }
                } else {
                    Button(action: { fallbackMenu = .competition(comp) }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.tertiaryLabel)
                            .frame(width: 28, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(comp.name.nilIfBlank ?? "Competition")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundColor(AppColors.label)
                if let sub = pastSubtitle(comp) {
                    Text(sub)
                        .font(.matMonkeysBody(size: 13))
                        .foregroundColor(AppColors.secondaryLabel)
                }
            }

            if !comp.strategy.isEmpty {
                Text("DID THE PLAN WORK?")
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                    .tracking(1.1)
                    .foregroundColor(AppColors.tertiaryLabel)
                VStack(spacing: 7) {
                    ForEach(comp.strategy) { focus in
                        HStack(spacing: 10) {
                            planMark(focus.worked)
                            Text(focus.text)
                                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                                .foregroundColor(AppColors.label)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }

            if !comp.imageFileNames.isEmpty {
                VStack(spacing: 8) {
                    ForEach(comp.imageFileNames, id: \.self) { fn in
                        if let data = store.competitionImageData(competitionId: comp.id, fileName: fn),
                           let ui = UIImage(data: data) {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(maxWidth: .infinity)
                                .frame(height: 180)
                                .overlay(
                                    Image(uiImage: ui)
                                        .resizable()
                                        .scaledToFill()
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }

            if comp.hasReflection, expandedReflectionId != comp.id, let snippet = reflectionSnippet(comp) {
                HStack(alignment: .top, spacing: 8) {
                    if let mood = comp.mood { Text(mood.glyph).font(.system(size: 15)) }
                    Text(snippet)
                        .font(.matMonkeysBody(size: 13))
                        .foregroundColor(AppColors.secondaryLabel)
                        .italic()
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }

            if comp.hasReflection && expandedReflectionId == comp.id {
                inlineReflectionContent(comp)
            }

            reflectFooterPlain(comp)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(AppColors.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppColors.cardBorder, lineWidth: 1))
    }

    private func planMark(_ worked: Bool?) -> some View {
        Group {
            switch worked {
            case .some(true):
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.winGreen))
            case .some(false):
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.stuckCoral)
                    .frame(width: 20, height: 20)
                    .background(RoundedRectangle(cornerRadius: 6).stroke(AppColors.stuckCoral, lineWidth: 1.5))
            case .none:
                RoundedRectangle(cornerRadius: 6)
                    .stroke(AppColors.tertiaryLabel.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 20, height: 20)
            }
        }
    }

    private func reflectFooterPlain(_ comp: Competition) -> some View {
        let isExpanded = comp.hasReflection && expandedReflectionId == comp.id
        return VStack(spacing: 0) {
            Rectangle().fill(AppColors.cardBorder).frame(height: 1)
            Button(action: {
                if comp.hasReflection {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        expandedReflectionId = isExpanded ? nil : comp.id
                    }
                } else {
                    openReflect(comp)
                }
            }) {
                HStack(spacing: 6) {
                    Text(comp.hasReflection ? "Reflected" : "Reflect after competition")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.indigo)
                    Image(systemName: isExpanded ? "chevron.up" : (comp.hasReflection ? "chevron.down" : "chevron.right"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.indigo)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func inlineReflectionContent(_ comp: Competition) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                if let mood = comp.mood { Text(mood.glyph).font(.system(size: 20)) }
                Text("Reflection")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.label)
                Spacer()
                Button(action: { sheet = .reflect(comp) }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.indigo)
                        .frame(width: 28, height: 28)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.indigo.opacity(0.10)))
                }
                .buttonStyle(PlainButtonStyle())
            }
            if let s = comp.workedText.nilIfBlank {
                inlineReflectionBlock(text: s, accent: AppColors.winGreen, tintUI: AppColors.winGreenUI, label: "What worked")
            }
            if let s = comp.stuckText.nilIfBlank {
                inlineReflectionBlock(text: s, accent: AppColors.stuckCoral, tintUI: AppColors.stuckCoralUI, label: "Where you got exposed")
            }
            if let s = comp.tryNextText.nilIfBlank {
                inlineReflectionBlock(text: s, accent: AppColors.indigo, tintUI: AppColors.indigoUI, label: "What you'll drill next")
            }
        }
        .padding(.top, 4)
        .transition(.opacity)
    }

    private func inlineReflectionContentLight(_ comp: Competition) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                if let mood = comp.mood { Text(mood.glyph).font(.system(size: 20)) }
                Text("Reflection")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { sheet = .reflect(comp) }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.22)))
                }
                .buttonStyle(PlainButtonStyle())
            }
            if let s = comp.workedText.nilIfBlank {
                inlineReflectionBlockLight(text: s, label: "What worked")
            }
            if let s = comp.stuckText.nilIfBlank {
                inlineReflectionBlockLight(text: s, label: "Where you got exposed")
            }
            if let s = comp.tryNextText.nilIfBlank {
                inlineReflectionBlockLight(text: s, label: "What you'll drill next")
            }
        }
        .padding(.top, 4)
        .transition(.opacity)
    }

    private func inlineReflectionBlockLight(text: String, label: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.6)).frame(width: 3)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                Text(text)
                    .font(.matMonkeysBody(size: 14))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.15)))
    }

    private func inlineReflectionBlock(text: String, accent: Color, tintUI: UIColor, label: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 3)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(accent)
                Text(text)
                    .font(.matMonkeysBody(size: 14))
                    .foregroundColor(AppColors.label)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.tint(tintUI, light: 0.10, dark: 0.22)))
    }

    // MARK: Dialogs

    @ViewBuilder
    private var dialogs: some View {
        if let ref = focusToDelete {
            ConfirmDialog(
                title: "Delete strategy focus?",
                message: "This removes it from your game plan for this competition.",
                onConfirm: {
                    store.deleteStrategyFocus(competitionId: ref.competitionId, focusId: ref.focusId)
                    focusToDelete = nil
                    if editingFocusId == ref.focusId { editingFocusId = nil }
                },
                onCancel: { focusToDelete = nil }
            )
        } else if let comp = competitionToDelete {
            ConfirmDialog(
                title: "Delete competition?",
                message: "This will permanently delete “\(comp.name.nilIfBlank ?? "this competition")” with its strategy, result, and reflection.",
                onConfirm: {
                    store.deleteCompetition(id: comp.id)
                    competitionToDelete = nil
                },
                onCancel: { competitionToDelete = nil }
            )
        }
    }

    // MARK: Actions

    private func commitFocusEdit(_ comp: Competition, _ focus: StrategyFocus) {
        let trimmed = focusDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            focusToDelete = FocusRef(competitionId: comp.id, focusId: focus.id)
        } else {
            store.updateStrategyFocus(competitionId: comp.id, focusId: focus.id, text: trimmed)
        }
        editingFocusId = nil
    }

    private func commitNewFocus(_ comp: Competition) {
        store.addStrategyFocus(competitionId: comp.id, text: newFocusDraft)
        newFocusDraft = ""
        addingFocusCompId = nil
    }

    /// If a reflection already exists, show its summary; otherwise start the reflect flow.
    private func openReflect(_ comp: Competition) {
        sheet = comp.hasReflection ? .reflectionSummary(comp) : .reflect(comp)
    }

    // MARK: Helpers

    private func divisionRank(_ comp: Competition) -> String? {
        let parts = [comp.division.nilIfBlank, comp.rank.nilIfBlank].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func dateVenue(_ comp: Competition) -> String {
        let date = DateFormatter.weekdayShortDate.string(from: comp.date)
        if let venue = comp.venue.nilIfBlank { return "\(date) · \(venue)" }
        return date
    }

    private func pastSubtitle(_ comp: Competition) -> String? {
        var parts = [divisionRank(comp)].compactMap { $0 }
        if let placement = comp.placement.nilIfBlank {
            parts.append("\(medalGlyph(placement)) \(placement)".trimmingCharacters(in: .whitespaces))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func reflectionSnippet(_ comp: Competition) -> String? {
        comp.workedText.nilIfBlank ?? comp.tryNextText.nilIfBlank ?? comp.stuckText.nilIfBlank
    }

    private func medalGlyph(_ p: String) -> String {
        switch p.lowercased() {
        case "gold": return "🥇"
        case "silver": return "🥈"
        case "bronze": return "🥉"
        default: return "🎖"
        }
    }

    private func daysAway(_ date: Date) -> String {
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow · \(DateFormatter.monthDay.string(from: date))" }
        if days > 1 { return "\(days) days · \(DateFormatter.monthDay.string(from: date))" }
        return DateFormatter.monthDay.string(from: date)
    }
}

// MARK: - Competition edit sheet

struct CompetitionEditView: View {
    @ObservedObject var store: NotebookStore
    let competition: Competition?
    var onClose: () -> Void

    @State private var name: String
    @State private var date: Date
    @State private var venue: String
    @State private var division: String
    @State private var rank: String
    @State private var strategy: [StrategyFocus]
    @State private var newFocus: String = ""
    @State private var showDatePicker = false

    private let divisions = ["Youth", "Adult", "Master"]

    init(store: NotebookStore, competition: Competition?, onClose: @escaping () -> Void) {
        self.store = store
        self.competition = competition
        self.onClose = onClose
        _name = State(initialValue: competition?.name ?? "")
        _date = State(initialValue: competition?.date ?? Date())
        _venue = State(initialValue: competition?.venue ?? "")
        _division = State(initialValue: competition?.division ?? "")
        _rank = State(initialValue: competition?.rank ?? "")
        _strategy = State(initialValue: competition?.strategy ?? [])
    }

    private var isEditing: Bool { competition != nil }
    private var canSave: Bool { name.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.secondaryLabel)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                Spacer()
                Text(isEditing ? "EDIT COMPETITION" : "NEW COMPETITION")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(1.0)
                    .foregroundColor(AppColors.secondaryLabel)
                Spacer()
                Button(action: save) {
                    Text("Save")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(canSave ? AppColors.indigo : AppColors.indigo.opacity(0.4)))
                }
                .disabled(!canSave)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    fieldLabel("Competition")
                    TextField("e.g. Chicago Summer Open", text: $name)
                        .textFieldStyle(TrainingTextFieldStyle())

                    fieldLabel("Date")
                    Button(action: { withAnimation { showDatePicker.toggle() } }) {
                        HStack {
                            Text(DateFormatter.weekdayShortDate.string(from: date))
                                .foregroundColor(AppColors.label)
                            Spacer()
                            Image(systemName: "calendar").foregroundColor(AppColors.indigo)
                        }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 13).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).stroke(AppColors.cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(PlainButtonStyle())
                    if showDatePicker {
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(WheelDatePickerStyle())
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                    }

                    fieldLabel("Venue (optional)")
                    TextField("e.g. UIC Pavilion", text: $venue)
                        .textFieldStyle(TrainingTextFieldStyle())

                    fieldLabel("Division")
                    HStack(spacing: 8) {
                        ForEach(divisions, id: \.self) { d in
                            Button(action: { division = (division == d ? "" : d) }) {
                                Text(d)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(division == d ? .white : AppColors.label)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 11).fill(division == d ? AppColors.indigo : AppColors.secondaryBackground))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    fieldLabel("Rank")
                    TextField("e.g. Intermediate", text: $rank)
                        .textFieldStyle(TrainingTextFieldStyle())

                    HStack {
                        fieldLabel("Strategy")
                        Spacer()
                        Text(strategy.isEmpty ? "Add a few focuses" : "\(strategy.count) \(strategy.count == 1 ? "focus" : "focuses")")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(AppColors.indigo)
                    }
                    Text("The one game plan you’ll actually try to run. Keep it short.")
                        .font(.matMonkeysBody(size: 13))
                        .foregroundColor(AppColors.secondaryLabel)

                    ForEach(Array(strategy.enumerated()), id: \.element.id) { idx, focus in
                        HStack(spacing: 10) {
                            Text("\(idx + 1)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(AppColors.indigo))
                            TextField("Focus", text: binding(for: focus))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            Button(action: { strategy.removeAll { $0.id == focus.id } }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 17))
                                    .foregroundColor(AppColors.stuckCoral.opacity(0.8))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 11).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 11).fill(AppColors.secondaryBackground))
                    }

                    HStack(spacing: 10) {
                        TextField("Add a focus", text: $newFocus, onCommit: addFocus)
                            .textFieldStyle(TrainingTextFieldStyle())
                        Button(action: addFocus) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(newFocus.trimmingCharacters(in: .whitespaces).isEmpty ? AppColors.indigo.opacity(0.4) : AppColors.indigo)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(newFocus.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(16)
                .padding(.bottom, 40)
            }
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .tracking(0.8)
            .foregroundColor(AppColors.tertiaryLabel)
    }

    private func binding(for focus: StrategyFocus) -> Binding<String> {
        Binding(
            get: { strategy.first(where: { $0.id == focus.id })?.text ?? "" },
            set: { newValue in
                if let idx = strategy.firstIndex(where: { $0.id == focus.id }) { strategy[idx].text = newValue }
            }
        )
    }

    private func addFocus() {
        let trimmed = newFocus.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        strategy.append(StrategyFocus(text: trimmed))
        newFocus = ""
    }

    private func save() {
        guard canSave else { return }
        let cleaned = strategy.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if let existing = competition {
            var updated = existing
            updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.date = date
            updated.venue = venue.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.division = division.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.rank = rank.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.strategy = cleaned
            store.updateCompetition(updated)
        } else {
            store.addCompetition(name: name, date: date, venue: venue, division: division, rank: rank, strategy: cleaned)
        }
        onClose()
    }
}

// MARK: - Competition result sheet

struct CompetitionResultView: View {
    @ObservedObject var store: NotebookStore
    let competitionId: String
    var onClose: () -> Void

    @State private var result: CompetitionResult?
    @State private var wins: Int
    @State private var losses: Int
    @State private var draws: Int
    @State private var placement: String
    @State private var focusWorked: [String: Bool]
    @State private var pendingImages: [Data] = []
    @State private var existingImageNames: [String]

    private let placements = ["Gold", "Silver", "Bronze"]

    init(store: NotebookStore, competitionId: String, onClose: @escaping () -> Void) {
        self.store = store
        self.competitionId = competitionId
        self.onClose = onClose
        let comp = store.competition(id: competitionId)
        _result = State(initialValue: comp?.result)
        _wins = State(initialValue: comp?.wins ?? 0)
        _losses = State(initialValue: comp?.losses ?? 0)
        _draws = State(initialValue: comp?.draws ?? 0)
        _placement = State(initialValue: comp?.placement ?? "")
        _existingImageNames = State(initialValue: comp?.imageFileNames ?? [])
        var worked: [String: Bool] = [:]
        comp?.strategy.forEach { worked[$0.id] = $0.worked ?? true }
        _focusWorked = State(initialValue: worked)
    }

    private var comp: Competition? { store.competition(id: competitionId) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.secondaryLabel)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                Spacer()
                VStack(spacing: 1) {
                    Text("HOW DID IT GO?")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .tracking(1.0)
                        .foregroundColor(AppColors.tertiaryLabel)
                    Text(comp?.name.nilIfBlank ?? "Competition")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(AppColors.label)
                }
                Spacer()
                Button(action: save) {
                    Text("Save")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(result != nil ? AppColors.indigo : AppColors.indigo.opacity(0.4)))
                }
                .disabled(result == nil)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sectionLabel("Result")
                    HStack(spacing: 12) {
                        resultTile(.win, title: "Win", caption: "Advanced or medaled", color: AppColors.winGreen)
                        resultTile(.draw, title: "Draw", caption: "Tied", color: AppColors.indigo)
                        resultTile(.loss, title: "Loss", caption: "Eliminated", color: AppColors.secondaryLabel)
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            sectionLabel("Wins")
                            stepper($wins)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            sectionLabel("Losses")
                            stepper($losses)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            sectionLabel("Draws")
                            stepper($draws)
                        }
                    }

                    sectionLabel("Placement")
                    HStack(spacing: 8) {
                        ForEach(placements, id: \.self) { p in
                            Button(action: { placement = (placement == p ? "" : p) }) {
                                Text(p)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(placement == p ? .white : AppColors.label)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 11).fill(placement == p ? AppColors.indigo : AppColors.secondaryBackground))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    if let comp = comp, !comp.strategy.isEmpty {
                        HStack {
                            sectionLabel("Did the plan work?")
                            Spacer()
                            Text("\(workedCount(comp)) of \(comp.strategy.count)")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundColor(AppColors.secondaryLabel)
                        }
                        VStack(spacing: 8) {
                            ForEach(comp.strategy) { focus in
                                planCheckRow(focus)
                            }
                        }
                    }

                    sectionLabel("Photos")
                    photoSection
                }
                .padding(16)
                .padding(.bottom, 40)
            }
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .tracking(1.0)
            .foregroundColor(AppColors.tertiaryLabel)
    }

    private func resultTile(_ value: CompetitionResult, title: String, caption: String, color: Color) -> some View {
        let selected = result == value
        return Button(action: { result = value }) {
            VStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                Text(caption)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            }
            .foregroundColor(selected ? .white : AppColors.secondaryLabel)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 16).fill(selected ? color : AppColors.secondaryBackground))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func stepper(_ value: Binding<Int>) -> some View {
        HStack {
            Button(action: { if value.wrappedValue > 0 { value.wrappedValue -= 1 } }) {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.indigo)
                    .frame(width: 34, height: 34)
            }
            Spacer()
            Text("\(value.wrappedValue)")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(AppColors.label)
            Spacer()
            Button(action: { value.wrappedValue += 1 }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.indigo)
                    .frame(width: 34, height: 34)
            }
        }
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 12).stroke(AppColors.cardBorder, lineWidth: 1))
    }

    private func planCheckRow(_ focus: StrategyFocus) -> some View {
        let worked = focusWorked[focus.id] ?? true
        return HStack(spacing: 12) {
            Text(focus.text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.label)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            Button(action: { focusWorked[focus.id] = true }) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(worked ? .white : AppColors.tertiaryLabel)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 8).fill(worked ? AppColors.winGreen : AppColors.secondaryBackground))
            }
            .buttonStyle(PlainButtonStyle())
            Button(action: { focusWorked[focus.id] = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(!worked ? .white : AppColors.tertiaryLabel)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 8).fill(!worked ? AppColors.stuckCoral : AppColors.secondaryBackground))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 11).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 11).fill(AppColors.cardBackground))
    }

    private var photoSection: some View {
        VStack(spacing: 10) {
            // Existing images
            ForEach(existingImageNames, id: \.self) { fn in
                if let data = store.competitionImageData(competitionId: competitionId, fileName: fn),
                   let ui = UIImage(data: data) {
                    ZStack(alignment: .topTrailing) {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .overlay(
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Button(action: {
                            store.removeCompetitionImage(competitionId: competitionId, fileName: fn)
                            existingImageNames.removeAll { $0 == fn }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(6)
                    }
                }
            }
            // Pending (not yet saved) images
            ForEach(pendingImages.indices, id: \.self) { idx in
                if let ui = UIImage(data: pendingImages[idx]) {
                    ZStack(alignment: .topTrailing) {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .overlay(
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Button(action: { pendingImages.remove(at: idx) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(6)
                    }
                }
            }
            // Add photo button
            Button(action: {
                UIKitImagePicker.present { data in
                    pendingImages.append(data)
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Add photo")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(AppColors.indigo)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).stroke(AppColors.indigo.opacity(0.4), lineWidth: 1.5))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func workedCount(_ comp: Competition) -> Int {
        comp.strategy.filter { focusWorked[$0.id] ?? true }.count
    }

    private func save() {
        guard let result = result else { return }
        store.logCompetitionResult(id: competitionId, result: result, wins: wins, losses: losses, draws: draws, placement: placement, focusWorked: focusWorked)
        for imageData in pendingImages {
            store.addCompetitionImage(competitionId: competitionId, imageData: imageData)
        }
        onClose()
    }
}

// MARK: - Competition reflection flow

struct CompetitionReflectFlowView: View {
    @ObservedObject var store: NotebookStore
    let competitionId: String
    var resetToken: UUID
    var onClose: () -> Void

    @State private var step: Int = 1
    @State private var mood: Mood?
    @State private var worked: String
    @State private var stuck: String
    @State private var tryNext: String

    init(store: NotebookStore, competitionId: String, resetToken: UUID, onClose: @escaping () -> Void) {
        self.store = store
        self.competitionId = competitionId
        self.resetToken = resetToken
        self.onClose = onClose
        let comp = store.competition(id: competitionId)
        _mood = State(initialValue: comp?.mood)
        _worked = State(initialValue: comp?.workedText ?? "")
        _stuck = State(initialValue: comp?.stuckText ?? "")
        _tryNext = State(initialValue: comp?.tryNextText ?? "")
    }

    private var comp: Competition? { store.competition(id: competitionId) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                if step == 1 {
                    moodStep
                } else if step == 2 {
                    notesStep
                } else {
                    doneStep
                }
            }
        }
        .id(resetToken)
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .frame(width: 30, height: 30)
                        .dashedCircle()
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                Spacer()
                if step <= 2 {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.systemGray5))
                            Capsule().fill(AppColors.indigo)
                                .frame(width: geometry.size.width * CGFloat(step) / 2.0)
                        }
                    }
                    .frame(height: 6)
                    Spacer()
                }
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .frame(width: 30, height: 30)
                        .dashedCircle()
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
            if step <= 2 {
                Text("Step \(step) of 2")
                    .font(.caption)
                    .foregroundColor(AppColors.label)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
    }

    private var moodStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("How did the competition feel?")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                        Text("One quick read on the day. You can change it any time.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                    if let comp = comp { competitionSummary(comp) }
                    LazyMoodGrid(mood: $mood)
                }
                .padding(16)
            }
            Button("Continue", action: { if mood != nil { step = 2 } })
                .buttonStyle(PrimaryButtonStyle())
                .disabled(mood == nil)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 30)
        }
    }

    private var notesStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What stood out?")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                        Text("A line or two for each is plenty.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                    labeledField($worked, "What worked in your matches", AppColors.winGreen, "A grip, a pass, a scramble that paid off...")
                    labeledField($stuck, "Where you got exposed", AppColors.stuckCoral, "A position you lost, a gap the day revealed...")
                    labeledField($tryNext, "What you'll drill next *", AppColors.indigo, "The thing to bring back to the gym...")
                }
                .padding(16)
            }
            Button("Save reflection", action: saveReflection)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(tryNext.nilIfBlank == nil)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 30)
        }
    }

    private var doneStep: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 38, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 82, height: 82)
                .background(AppColors.indigo)
                .clipShape(Circle())
            Text("Reflection logged.")
                .font(.title)
                .fontWeight(.medium)
            Text("Wins and losses fade. What you learned is what compounds.")
                .font(.subheadline)
                .foregroundColor(AppColors.label)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
            Button("Done", action: onClose)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
        }
    }

    @ViewBuilder
    private func competitionSummary(_ comp: Competition) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("🏆")
                    .font(.system(size: 18))
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.indigo.opacity(0.18)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(comp.name.nilIfBlank ?? "Competition")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.label)
                    Text(DateFormatter.weekdayLongDate.string(from: comp.date))
                        .font(.matMonkeysBody(size: 14))
                        .foregroundColor(AppColors.secondaryLabel)
                }
                Spacer()
            }
            if comp.hasResult {
                let rl: String = { switch comp.result { case .win: return "Win"; case .draw: return "Draw"; case .loss, .none: return "Loss" } }()
                let rc: Color = { switch comp.result { case .win: return AppColors.winGreen; case .draw: return AppColors.indigo; case .loss, .none: return AppColors.secondaryLabel } }()
                Text("\(rl) · \(comp.recordString)\(comp.placement.nilIfBlank.map { " · \($0)" } ?? "")")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(rc)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.secondaryBackground))
    }

    private func labeledField(_ text: Binding<String>, _ label: String, _ color: Color, _ placeholder: String) -> some View {
        ZStack(alignment: .topLeading) {
            TrainingTextView(text: text, placeholder: placeholder)
                .frame(height: 108)
                .padding(.top, 8)
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(color)
                .cornerRadius(8)
                .offset(x: 8, y: -10)
        }
    }

    private func goBack() {
        if step <= 1 { onClose() } else { step -= 1 }
    }

    private func saveReflection() {
        guard tryNext.nilIfBlank != nil else { return }
        store.saveCompetitionReflection(id: competitionId, mood: mood, workedText: worked, stuckText: stuck, tryNextText: tryNext)
        step = 3
    }
}

// MARK: - Competition reflection summary

/// Read-only view of a competition reflection, shown when tapping "Reflected".
/// Mirrors the training reflection card (mood + colored sections) and offers an
/// "Edit reflection" action rather than forcing the user back through the flow.
struct CompetitionReflectionSummaryView: View {
    @ObservedObject var store: NotebookStore
    let competitionId: String
    var onClose: () -> Void

    @State private var showEdit = false

    private var comp: Competition? { store.competition(id: competitionId) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.secondaryLabel)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                Spacer()
                Text("REFLECTION")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(1.0)
                    .foregroundColor(AppColors.secondaryLabel)
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            ScrollView {
                if let comp = comp {
                    VStack(alignment: .leading, spacing: 12) {
                        header(comp)
                        if let s = comp.workedText.nilIfBlank {
                            sectionBlock(text: s, accent: AppColors.winGreen, tintUI: AppColors.winGreenUI, label: "What worked in your matches")
                        }
                        if let s = comp.stuckText.nilIfBlank {
                            sectionBlock(text: s, accent: AppColors.stuckCoral, tintUI: AppColors.stuckCoralUI, label: "Where you got exposed")
                        }
                        if let s = comp.tryNextText.nilIfBlank {
                            sectionBlock(text: s, accent: AppColors.indigo, tintUI: AppColors.indigoUI, label: "What you'll drill next")
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.cardBackground))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.cardBorder, lineWidth: 1))
                    .padding(16)
                }
            }

            Button(action: { showEdit = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                    Text("Edit reflection")
                }
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.indigo)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.indigo.opacity(0.10)))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
        .sheet(isPresented: $showEdit) {
            CompetitionReflectFlowView(store: store, competitionId: competitionId, resetToken: UUID(), onClose: { showEdit = false })
        }
    }

    private func header(_ comp: Competition) -> some View {
        HStack(alignment: .center, spacing: 10) {
            if let mood = comp.mood {
                Text(mood.glyph).font(.system(size: 26))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(comp.name.nilIfBlank ?? "Competition")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.label)
                    .fixedSize(horizontal: false, vertical: true)
                Text(resultLine(comp))
                    .font(.matMonkeysBody(size: 13))
                    .foregroundColor(AppColors.secondaryLabel)
            }
            Spacer(minLength: 0)
        }
    }

    private func resultLine(_ comp: Competition) -> String {
        let date = DateFormatter.weekdayShortDate.string(from: comp.date)
        guard comp.hasResult else { return date }
        let resultLabel: String = {
            switch comp.result {
            case .win: return "Win"
            case .draw: return "Draw"
            case .loss, .none: return "Loss"
            }
        }()
        var parts = ["\(resultLabel) · \(comp.recordString)"]
        if let placement = comp.placement.nilIfBlank { parts.append(placement) }
        parts.append(date)
        return parts.joined(separator: " · ")
    }

    private func sectionBlock(text: String, accent: Color, tintUI: UIColor, label: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(accent)
                Text(text)
                    .font(.matMonkeysBody(size: 15))
                    .foregroundColor(AppColors.label)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.tint(tintUI, light: 0.10, dark: 0.22)))
    }
}
