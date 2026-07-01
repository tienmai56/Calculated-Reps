import SwiftUI

struct PlanListView: View {
    @ObservedObject var store: NotebookStore
    var onAdd: () -> Void
    var onReflect: (String) -> Void

    @State private var displayedMonth: Date = Date()
    @State private var selectedDate: Date = Date()
    @State private var editingSession: PlannedSession?
    @State private var showDeleteConfirm = false
    @State private var sessionToDelete: PlannedSession?
    @State private var feedbackReflection: Reflection?

    private var cal: Calendar { Calendar.current }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Plan")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.indigo)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

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
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
        .sheet(item: $editingSession) { session in
            EditSessionView(store: store, session: session) {
                editingSession = nil
            }
        }
        .sheet(item: $feedbackReflection) { reflection in
            FeedbackPreviewView(store: store, reflection: reflection, onClose: { feedbackReflection = nil })
        }
        .alert(isPresented: $showDeleteConfirm) {
            Alert(
                title: Text("Delete Session"),
                message: Text("This will permanently delete this planned session and any associated reflection."),
                primaryButton: .destructive(Text("Delete")) {
                    if let s = sessionToDelete {
                        store.deleteSession(id: s.id)
                        sessionToDelete = nil
                    }
                },
                secondaryButton: .cancel { sessionToDelete = nil }
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
                        .font(.matMindBody(size: 16))
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
                        SessionCardView(
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
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: monthFirst)
    }

    private var longDateLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE, MMM d, yyyy"
        return fmt.string(from: selectedDate)
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
