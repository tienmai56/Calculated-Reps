import SwiftUI
import UIKit

// MARK: - Shared Views

struct HeaderView: View {
    var title: String
    var onBack: (() -> Void)?
    var rightTitle: String?
    var rightAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            if let onBack = onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.indigo)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibility(label: Text("Back"))
            } else {
                Spacer().frame(width: 44)
            }
            Text(title)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            if let rightTitle = rightTitle, let rightAction = rightAction {
                Button(rightTitle, action: rightAction)
                    .font(.caption)
                    .foregroundColor(AppColors.label)
                    .frame(minWidth: 44, minHeight: 44)
            } else {
                Spacer().frame(width: 44)
            }
        }
        .padding(.horizontal, 6)
        .background(AppColors.background)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(.systemGray4)), alignment: .bottom)
    }
}

struct WeekStripView: View {
    var dayStates: [String: SessionStatus]
    @State private var anchor = Date()

    private let labels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        let start = Calendar.current.mondayStartOfWeek(containing: anchor)
        let days = (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
        return VStack(spacing: 10) {
            HStack {
                Button(action: { shift(-7) }) {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibility(label: Text("Previous week"))
                Spacer()
                Text("\(shortMonthDay(days.first ?? start)) - \(shortMonthDay(days.last ?? start))")
                    .font(.caption)
                    .uppercaseTracking()
                    .foregroundColor(AppColors.label)
                Spacer()
                Button(action: { shift(7) }) {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibility(label: Text("Next week"))
            }
            HStack(spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.element) { index, day in
                    VStack(spacing: 5) {
                        Text(labels[index])
                            .font(.caption)
                            .foregroundColor(AppColors.label)
                        Text("\(Calendar.current.component(.day, from: day))")
                            .font(.caption)
                            .frame(width: 32, height: 32)
                            .background(background(for: day))
                            .foregroundColor(foreground(for: day))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(.systemGray3), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cardBackground()
    }

    private func shift(_ days: Int) {
        anchor = Calendar.current.date(byAdding: .day, value: days, to: anchor) ?? anchor
    }

    private func state(for day: Date) -> SessionStatus? {
        dayStates[day.trainingDayString]
    }

    private func background(for day: Date) -> Color {
        state(for: day) == .done ? AppColors.indigo : AppColors.background
    }

    private func foreground(for day: Date) -> Color {
        state(for: day) == .done ? .white : AppColors.label
    }

    private func shortMonthDay(_ date: Date) -> String {
        DateFormatter.monthDay.string(from: date)
    }
}

struct TaskTagView: View {
    let task: TrainingTask
    @ObservedObject var store: NotebookStore

    var body: some View {
        let completed = store.notebook.sessions.filter { $0.taskIds.contains(task.id) && $0.status == .done }.count
        let label = task.name + " · " + "\(completed)d"
        return Text(label)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(Color(.label))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}

struct PlanTaskTagView: View {
    let task: TrainingTask
    var goalColor: Color = AppColors.indigo

    var body: some View {
        Text(task.name)
            .font(.system(size: 11, design: .rounded))
            .foregroundColor(goalColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(goalColor.opacity(0.12))
            .cornerRadius(10)
    }
}

struct WrappingHStack<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content
    let spacing: CGFloat = 8

    @State private var totalHeight: CGFloat = 30

    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
        .frame(height: max(totalHeight, 1))
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                content(item)
                    .padding(.trailing, spacing)
                    .padding(.bottom, spacing)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > geometry.size.width {
                            width = 0
                            height -= d.height + spacing
                        }
                        let result = width
                        if index == items.count - 1 {
                            width = 0
                        } else {
                            width -= d.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { d in
                        let result = height
                        if index == items.count - 1 {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: HeightPreferenceKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(HeightPreferenceKey.self) { totalHeight = $0 }
    }
}

private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct EmptyDashedState: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(AppColors.secondaryLabel)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(AppColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .cardBackground()
    }
}

struct EmptyStateCard: View {
    var icon: String
    var title: String
    var subtitle: String
    var ctaTitle: String?
    var ctaAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .regular, design: .rounded))
                .foregroundColor(AppColors.indigo.opacity(0.5))
            Text(title)
                .font(.subheadline)
                .foregroundColor(AppColors.secondaryLabel)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(AppColors.secondaryLabel)
            if let ctaTitle = ctaTitle, let ctaAction = ctaAction {
                Button(action: ctaAction) {
                    Text(ctaTitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(AppColors.indigo)
                        .cornerRadius(20)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .cardBackground()
    }
}

struct CircleIcon: View {
    var systemName: String
    var bgColor: Color = .black

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(AppColors.label)
            .frame(width: 38, height: 38)
            .dashedCircle()
    }
}

struct ChipButton: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 13)
                .frame(minHeight: 44)
                .background(isSelected ? AppColors.indigo : Color.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color(.systemGray2), style: StrokeStyle(lineWidth: 1, dash: isSelected ? [] : [4, 3])))
        }
        .contentShape(Rectangle())
    }
}

struct DashedPanel<Content: View>: View {
    var content: () -> Content

    var body: some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cardBackground()
    }
}

struct FlowWrap<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let content: (Data.Element) -> Content

    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(data), id: \.id) { item in
                content(item)
            }
        }
    }
}

struct AutoFocusTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var id: UUID

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.font = UIFont.preferredFont(forTextStyle: .subheadline)
        tf.borderStyle = .none
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        tf.setContentHuggingPriority(.defaultLow, for: .horizontal)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            tf.becomeFirstResponder()
        }
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text { uiView.text = text }
        if context.coordinator.lastId != id {
            context.coordinator.lastId = id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                uiView.becomeFirstResponder()
            }
        }
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AutoFocusTextField
        var lastId: UUID

        init(_ parent: AutoFocusTextField) {
            self.parent = parent
            self.lastId = parent.id
        }

        @objc func textChanged(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if let trimmed = parent.text.nilIfBlank, trimmed.count <= 15 {
                // Let the button action handle adding
            }
            return false
        }
    }
}

struct TrainingTextView: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray3.cgColor
        view.layer.cornerRadius = 8
        view.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        view.text = placeholder
        view.textColor = .placeholderText
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if text.isEmpty && !uiView.isFirstResponder {
            uiView.text = placeholder
            uiView.textColor = .placeholderText
        } else if uiView.textColor == .placeholderText && !text.isEmpty {
            uiView.text = text
            uiView.textColor = .label
        } else if uiView.textColor != .placeholderText && uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: TrainingTextView

        init(_ parent: TrainingTextView) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.textColor == .placeholderText {
                textView.text = ""
                textView.textColor = .label
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.textColor == .placeholderText ? "" : textView.text
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                textView.text = parent.placeholder
                textView.textColor = .placeholderText
                parent.text = ""
            }
        }
    }
}
