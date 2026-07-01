import SwiftUI
import UIKit

struct OnboardingDraft {
    var goalName: String
    var iconName: String = "target"
    var colorName: String = "indigo"
    var taskNames: [String]
    var firstTaskDescription: String = ""
    var sessionDate: Date
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
}

/// Static, illustrative example tasks shown under the first-task field. Intentionally a fixed list
/// (not derived from the live goal text) so typing in the goal field never rebuilds this section —
/// a changing list here would churn `WrappingHStack`'s layout state and drop the keyboard.
enum OnboardingSuggestions {
    static let examples = ["Break their posture", "Hip escape to angle", "Two-on-one grip", "Lasso grip"]
}

struct OnboardingContainerView: View {
    var onComplete: (OnboardingDraft) -> Void

    private enum Step { case splash, goal, session }
    @State private var step: Step = OnboardingContainerView.initialStep

    @State private var goalName = ""
    @State private var firstTask = ""
    @State private var firstTaskDescription = ""
    @State private var sessionDay: Date = Calendar.current.normalizedTrainingDay(Date())
    @State private var reminderEnabled = true
    @State private var reminderHour = 8
    @State private var reminderMinute = 0

    var body: some View {
        ZStack {
            if step == .splash {
                OnboardingSplashView(onNext: { go(.goal) })
                    .transition(.opacity)
            } else if step == .goal {
                OnboardingGoalStepView(
                    goalName: $goalName,
                    firstTask: $firstTask,
                    firstTaskDescription: $firstTaskDescription,
                    onBack: { go(.splash) },
                    onNext: { go(.session) }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                OnboardingSessionStepView(
                    goalName: goalName,
                    firstTask: firstTask,
                    sessionDay: $sessionDay,
                    reminderEnabled: $reminderEnabled,
                    reminderHour: $reminderHour,
                    reminderMinute: $reminderMinute,
                    onBack: { go(.goal) },
                    onSkip: { finish(useDefaults: true) },
                    onStart: { finish(useDefaults: false) }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }

    private func go(_ next: Step) {
        withAnimation(.easeInOut(duration: 0.3)) { step = next }
    }

    /// DEBUG-only deep link into a specific onboarding step for screenshot/QA, mirroring
    /// `MainAppView.initialTab`'s `START_TAB` override.
    static private var initialStep: Step {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["ONBOARDING_STEP"] {
        case "goal": return .goal
        case "session": return .session
        default: return .splash
        }
        #else
        return .splash
        #endif
    }

    private func finish(useDefaults: Bool) {
        let goal = goalName.trimmingCharacters(in: .whitespacesAndNewlines)
        let tasks = [firstTask.trimmingCharacters(in: .whitespacesAndNewlines)].filter { !$0.isEmpty }

        let day = useDefaults ? Calendar.current.normalizedTrainingDay(Date()) : sessionDay
        let hour = useDefaults ? 8 : reminderHour
        let minute = useDefaults ? 0 : reminderMinute

        onComplete(
            OnboardingDraft(
                goalName: goal,
                taskNames: tasks,
                firstTaskDescription: firstTaskDescription,
                sessionDate: day,
                reminderEnabled: reminderEnabled,
                reminderHour: hour,
                reminderMinute: minute
            )
        )
    }
}

// MARK: Onboarding · shared pieces

/// The Mat Mind "MM" monogram stroke used on the splash.
struct MatMindMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 120
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
        var path = Path()
        path.move(to: p(26, 88))
        path.addLine(to: p(26, 40))
        path.addLine(to: p(48, 64))
        path.addLine(to: p(70, 40))
        path.addLine(to: p(70, 64))
        path.addLine(to: p(92, 40))
        path.addLine(to: p(92, 88))
        return path
    }
}

private struct OnboardingProgressHeader: View {
    let step: Int          // 1 or 2
    let trailingLabel: String
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.secondaryLabel)
                    .frame(width: 32, height: 32, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            HStack(spacing: 7) {
                Capsule().fill(step == 1 ? AppColors.indigo : Color(red: 0.85, green: 0.83, blue: 0.80))
                    .frame(width: step == 1 ? 26 : 8, height: 6)
                Capsule().fill(step == 2 ? AppColors.indigo : Color(red: 0.85, green: 0.83, blue: 0.80))
                    .frame(width: step == 2 ? 26 : 8, height: 6)
                Spacer()
                Text(trailingLabel)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.tertiaryLabel)
            }
        }
    }
}

private struct OnboardingFieldLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .tracking(1)
            .foregroundColor(AppColors.tertiaryLabel)
    }
}

private struct OnboardingIconTile: View {
    let systemName: String
    var body: some View {
        RoundedRectangle(cornerRadius: 11)
            .fill(AppColors.indigo.opacity(0.12))
            .frame(width: 38, height: 38)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.indigo)
            )
    }
}

// MARK: Onboarding · 1 · Splash

struct OnboardingSplashView: View {
    var onNext: () -> Void

    @State private var drawn = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 63/255, green: 61/255, blue: 158/255),
                    Color(red: 74/255, green: 63/255, blue: 160/255),
                    Color(red: 91/255, green: 71/255, blue: 166/255)
                ]),
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(AppColors.mint.opacity(0.28))
                        .frame(width: 132, height: 132)
                        .blur(radius: 26)
                        .scaleEffect(pulse ? 1.08 : 0.92)
                    MatMindMarkShape()
                        .trim(from: 0, to: drawn ? 1 : 0)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                        .frame(width: 118, height: 118)
                    Circle()
                        .fill(AppColors.mint)
                        .frame(width: 13, height: 13)
                        .offset(x: 0, y: -19)
                        .opacity(drawn ? 1 : 0)
                        .scaleEffect(pulse ? 1.15 : 1.0)
                }
                .frame(width: 148, height: 148)
                .padding(.bottom, 34)

                VStack(spacing: 14) {
                    Text("MAT MIND")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(Color.white.opacity(0.62))
                    Text("Train with\nintention.")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                    Text("Make progress faster.")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.72))
                }

                Spacer()

                VStack(spacing: 18) {
                    Button(action: onNext) {
                        HStack(spacing: 9) {
                            Text("Next")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(AppColors.indigo)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .cornerRadius(18)
                        .shadow(color: Color.black.opacity(0.28), radius: 20, x: 0, y: 12)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Text("No account needed. Nothing to sign up for.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 44)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4)) { drawn = true }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

// MARK: Onboarding · 2 · Goal & task

struct OnboardingGoalStepView: View {
    @Binding var goalName: String
    @Binding var firstTask: String
    @Binding var firstTaskDescription: String
    var onBack: () -> Void
    var onNext: () -> Void

    private var canContinue: Bool {
        goalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && firstTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    OnboardingProgressHeader(step: 1, trailingLabel: "Required", onBack: onBack)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 11) {
                        Text("What do you\nwant to get\nbetter at?")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.label)
                            .lineSpacing(1)
                        Text("Name one focus to train. Add the tasks you’ll drill inside it — you can change all of this later.")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.secondaryLabel)
                            .lineSpacing(2)
                    }
                    .padding(.top, 22)
                    .padding(.bottom, 26)

                    // Goal
                    OnboardingFieldLabel(text: "Your goal")
                        .padding(.bottom, 9)
                    HStack(spacing: 11) {
                        OnboardingIconTile(systemName: "target")
                        TextField("Closed Guard", text: $goalName)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.label)
                            .accentColor(AppColors.indigo)
                    }
                    .padding(16)
                    .background(AppColors.background)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.indigo, lineWidth: 2))
                    .cornerRadius(16)
                    .shadow(color: AppColors.indigo.opacity(0.18), radius: 12, x: 0, y: 4)
                    .padding(.bottom, 22)

                    // First task
                    OnboardingFieldLabel(text: "First task to work on")
                        .padding(.bottom, 9)
                    HStack(spacing: 11) {
                        OnboardingIconTile(systemName: "pencil")
                        TextField("Standup", text: $firstTask)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.label)
                            .accentColor(AppColors.indigo)
                    }
                    .padding(15)
                    .background(AppColors.background)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.08), lineWidth: 1.5))
                    .cornerRadius(16)

                    // Example tasks — static, illustrative examples shown under the first-task
                    // field (not tappable, and independent of the goal text so typing above never
                    // rebuilds this section).
                    Text("Example tasks")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.tertiaryLabel)
                        .padding(.top, 14)
                        .padding(.bottom, 10)

                    WrappingHStack(items: OnboardingSuggestions.examples.map { IdentifiableString($0) }) { item in
                        Text(item.value)
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.indigo)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppColors.indigo.opacity(0.1))
                            .cornerRadius(14)
                    }
                    .allowsHitTesting(false)

                    // Task description (free-form, optional)
                    OnboardingFieldLabel(text: "Task description")
                        .padding(.top, 22)
                        .padding(.bottom, 9)
                    TrainingTextView(text: $firstTaskDescription, placeholder: "Pin their shoulders to the ground")
                        .frame(minHeight: 92)

                    // Session peek
                    VStack(alignment: .leading, spacing: 7) {
                        Divider()
                            .padding(.bottom, 17)
                        OnboardingFieldLabel(text: "Plan your first session")
                        Text("Next you’ll pick when you’ll train it ↓")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.tertiaryLabel)
                    }
                    .padding(.top, 30)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            // Next CTA
            Button(action: onNext) {
                HStack(spacing: 9) {
                    Text("Next")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                    Image(systemName: "arrow.right").font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(canContinue ? AppColors.indigo : Color(.systemGray3))
                .cornerRadius(18)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canContinue)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 30)
            .background(AppColors.background.edgesIgnoringSafeArea(.bottom))
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }
}

/// Small Identifiable wrapper so `String` suggestions work with `FlowWrap`.
struct IdentifiableString: Identifiable {
    let value: String
    var id: String { value }
    init(_ value: String) { self.value = value }
}

// MARK: Onboarding · 3 · Plan session

struct OnboardingSessionStepView: View {
    let goalName: String
    let firstTask: String
    @Binding var sessionDay: Date
    @Binding var reminderEnabled: Bool
    @Binding var reminderHour: Int
    @Binding var reminderMinute: Int
    var onBack: () -> Void
    var onSkip: () -> Void
    var onStart: () -> Void

    @State private var showDayPicker = false
    @State private var showTimePicker = false

    private var timeLabel: String {
        let h = reminderHour % 12 == 0 ? 12 : reminderHour % 12
        let period = reminderHour < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", h, reminderMinute, period)
    }

    private var dayLabel: String {
        if Calendar.current.isDateInToday(sessionDay) {
            let f = DateFormatter(); f.dateFormat = "MMM d"
            return "Today, \(f.string(from: sessionDay))"
        }
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"
        return f.string(from: sessionDay)
    }

    private var timeBinding: Binding<Date> {
        Binding<Date>(
            get: { Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: Date()) ?? Date() },
            set: {
                reminderHour = Calendar.current.component(.hour, from: $0)
                reminderMinute = Calendar.current.component(.minute, from: $0)
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        OnboardingProgressHeader(step: 2, trailingLabel: "", onBack: onBack)
                        Spacer()
                        Button(action: onSkip) {
                            Text("Skip")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.tertiaryLabel)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, 48)
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 11) {
                        Text("When will you\ntrain it?")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.label)
                            .lineSpacing(1)
                        Text("Plan your first session. We’ll have it ready on Home when you step on the mat.")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.secondaryLabel)
                            .lineSpacing(2)
                    }
                    .padding(.top, 22)
                    .padding(.bottom, 22)

                    sessionCard

                    // Reminder toggle
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 11)
                            .fill(AppColors.mint.opacity(0.18))
                            .frame(width: 38, height: 38)
                            .overlay(
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 17))
                                    .foregroundColor(Color(red: 61/255, green: 161/255, blue: 147/255))
                            )
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Remind me at \(timeLabel)")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundColor(AppColors.label)
                            Text("A gentle nudge, never a guilt trip")
                                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                .foregroundColor(AppColors.tertiaryLabel)
                        }
                        Spacer()
                        OnboardingPillToggle(isOn: $reminderEnabled)
                    }
                    .padding(15)
                    .background(AppColors.background)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.06), lineWidth: 1))
                    .cornerRadius(16)
                    .padding(.top, 16)

                    // Start CTA
                    Button(action: onStart) {
                        HStack(spacing: 9) {
                            Text("Start training")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                            Image(systemName: "arrow.right").font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(AppColors.indigo)
                        .cornerRadius(18)
                        .shadow(color: AppColors.indigo.opacity(0.5), radius: 18, x: 0, y: 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 22)

                    Text("Everything stays on your device.\nNo account, no cloud, no sign-in.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.tertiaryLabel)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 14)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Circle().fill(AppColors.mint).frame(width: 7, height: 7)
                Text("FIRST SESSION")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundColor(Color.white.opacity(0.72))
            }

            Text(goalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your goal" : goalName)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .padding(.top, 14)

            // Day + Time
            HStack(spacing: 10) {
                pickerTile(title: "Day", value: dayLabel, expanded: showDayPicker) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDayPicker.toggle(); if showDayPicker { showTimePicker = false }
                    }
                }
                pickerTile(title: "Time", value: timeLabel, expanded: showTimePicker) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showTimePicker.toggle(); if showTimePicker { showDayPicker = false }
                    }
                }
                .frame(width: 128)
            }
            .padding(.top, 16)

            if showDayPicker {
                DatePicker("", selection: $sessionDay, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(WheelDatePickerStyle())
                    .labelsHidden()
                    .colorScheme(.dark)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            if showTimePicker {
                DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .datePickerStyle(WheelDatePickerStyle())
                    .labelsHidden()
                    .colorScheme(.dark)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }

            // Tasks
            Text("TASKS")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundColor(Color.white.opacity(0.6))
                .padding(.top, 20)
                .padding(.bottom, 10)

            VStack(spacing: 8) {
                taskRow(firstTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "First task" : firstTask)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 63/255, green: 61/255, blue: 158/255),
                    Color(red: 77/255, green: 63/255, blue: 159/255),
                    Color(red: 91/255, green: 71/255, blue: 166/255)
                ]),
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .cornerRadius(24)
        .shadow(color: AppColors.indigo.opacity(0.5), radius: 26, x: 0, y: 16)
    }

    private func pickerTile(title: String, value: String, expanded: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(0.6)
                    .foregroundColor(Color.white.opacity(0.6))
                HStack(spacing: 6) {
                    Text(value)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color.white.opacity(0.12))
            .cornerRadius(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func taskRow(_ name: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(AppColors.mint)
                .frame(width: 18, height: 18)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(AppColors.indigo)
                )
            Text(name)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

/// Indigo pill switch matching the onboarding prototype (avoids iOS-14-only tinted `SwitchToggleStyle`).
struct OnboardingPillToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.18)) { isOn.toggle() } }) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(isOn ? AppColors.indigo : Color(.systemGray4))
                    .frame(width: 48, height: 28)
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: Color.black.opacity(0.3), radius: 1.5, x: 0, y: 1)
                    .padding(3)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Main Shell
