import SwiftUI
import UserNotifications

struct SettingsSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var showReminders = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    settingsRow(icon: "bell.fill", iconColor: Color(red: 0.9, green: 0.4, blue: 0.4), label: "Reminders", showDivider: true) {
                        showReminders = true
                    }
                    settingsRow(icon: "star.fill", iconColor: AppColors.mint, label: "Rate Mat Mind", showDivider: true) {
                        openAppStoreRating()
                    }
                    settingsRow(icon: "envelope.fill", iconColor: AppColors.indigo, label: "Feedback", showDivider: false) {
                        // Placeholder — no action yet
                    }
                }
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground)))
                .padding(.horizontal, 16)
                .padding(.top, 20)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(AppColors.groupedBackground.edgesIgnoringSafeArea(.all))
            .navigationBarTitle("Settings", displayMode: .inline)
            .navigationBarItems(leading: Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                    Text("Back")
                }
                .foregroundColor(AppColors.indigo)
            })
            .sheet(isPresented: $showReminders) {
                RemindersSettingsView()
            }
        }
    }

    private func settingsRow(icon: String, iconColor: Color, label: String, showDivider: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                        .frame(width: 28)
                    Text(label)
                        .font(.system(size: 17, design: .rounded))
                        .foregroundColor(AppColors.label)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(.systemGray3))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            if showDivider {
                Divider().padding(.leading, 58)
            }
        }
    }

    private func openAppStoreRating() {
        let appId = "com.tienmai.intentionaltrainingnotes"
        if let url = URL(string: "itms-apps://itunes.apple.com/app/id\(appId)?action=write-review") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

// MARK: - Reminders Settings

struct RemindersSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var reminderEnabled: Bool = UserDefaults.standard.object(forKey: "reminderEnabled") as? Bool ?? true
    @State private var reminderHour: Int = UserDefaults.standard.object(forKey: "reminderHour") as? Int ?? 8
    @State private var reminderMinute: Int = UserDefaults.standard.object(forKey: "reminderMinute") as? Int ?? 0
    @State private var showTimePicker = false

    private var timeLabel: String {
        let h = reminderHour % 12 == 0 ? 12 : reminderHour % 12
        let period = reminderHour < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", h, reminderMinute, period)
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                Text("REFLECTION REMINDER")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.secondaryLabel)
                    .kerning(0.5)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 10)

                VStack(spacing: 0) {
                    // Toggle row
                    HStack(spacing: 14) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(red: 0.9, green: 0.4, blue: 0.4))
                            .frame(width: 28)
                        Text("Reflection reminder")
                            .font(.system(size: 17, design: .rounded))
                            .foregroundColor(AppColors.label)
                        Spacer()
                        Toggle("", isOn: $reminderEnabled)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider().padding(.leading, 58)

                    // Time row
                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showTimePicker.toggle() } }) {
                        HStack(spacing: 14) {
                            Image(systemName: "clock")
                                .font(.system(size: 18))
                                .foregroundColor(AppColors.secondaryLabel)
                                .frame(width: 28)
                            Text("Time")
                                .font(.system(size: 17, design: .rounded))
                                .foregroundColor(AppColors.label)
                            Spacer()
                            Text(timeLabel)
                                .font(.system(size: 17, design: .rounded))
                                .foregroundColor(AppColors.secondaryLabel)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(.systemGray3))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .opacity(reminderEnabled ? 1.0 : 0.4)
                    .disabled(!reminderEnabled)

                    if showTimePicker && reminderEnabled {
                        DatePicker("", selection: Binding(
                            get: {
                                var comps = DateComponents()
                                comps.hour = reminderHour
                                comps.minute = reminderMinute
                                return Calendar.current.date(from: comps) ?? Date()
                            },
                            set: { newDate in
                                reminderHour = Calendar.current.component(.hour, from: newDate)
                                reminderMinute = Calendar.current.component(.minute, from: newDate)
                            }
                        ), displayedComponents: .hourAndMinute)
                        .datePickerStyle(WheelDatePickerStyle())
                        .labelsHidden()
                        .padding(.horizontal, 16)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground)))
                .padding(.horizontal, 16)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.groupedBackground.edgesIgnoringSafeArea(.all))
            .navigationBarTitle("Reminders", displayMode: .inline)
            .navigationBarItems(leading: Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                    Text("Back")
                }
                .foregroundColor(AppColors.indigo)
            })
            .onDisappear { saveAndSchedule() }
        }
    }

    private func saveAndSchedule() {
        UserDefaults.standard.set(reminderEnabled, forKey: "reminderEnabled")
        UserDefaults.standard.set(reminderHour, forKey: "reminderHour")
        UserDefaults.standard.set(reminderMinute, forKey: "reminderMinute")
        ReminderScheduler.shared.updateSchedule(enabled: reminderEnabled, hour: reminderHour, minute: reminderMinute)
    }
}

// MARK: - Reflection Card (Latest Entry + Patterns)
