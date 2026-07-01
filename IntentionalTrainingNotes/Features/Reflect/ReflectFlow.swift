import SwiftUI
import AVFoundation

struct ReflectFlowView: View {
    @ObservedObject var store: NotebookStore
    var initialSessionId: String?
    var resetToken: UUID
    var onClose: () -> Void
    var onFinish: (PlannedSession) -> Void

    @State private var step: Int
    @State private var selectedSessionId: String?
    @State private var mood: Mood?
    @State private var worked: String
    @State private var stuck: String
    @State private var tryNext: String
    @State private var link: String
    @State private var images: [String]
    @State private var showVoice = false

    init(store: NotebookStore, initialSessionId: String?, resetToken: UUID, onClose: @escaping () -> Void, onFinish: @escaping (PlannedSession) -> Void) {
        self.store = store
        self.initialSessionId = initialSessionId
        self.resetToken = resetToken
        self.onClose = onClose
        self.onFinish = onFinish
        // Initialize once per presentation (identity is keyed by .id(resetToken)).
        // Previously this lived in .onAppear, which re-fires on every re-render — so
        // saving (which mutates the store) reset `step` back to the mood screen.
        let existing = initialSessionId.flatMap { store.reflection(forSessionId: $0) }
        _step = State(initialValue: initialSessionId == nil ? 1 : 2)
        _selectedSessionId = State(initialValue: initialSessionId)
        _mood = State(initialValue: existing?.mood)
        _worked = State(initialValue: existing?.workedText ?? "")
        _stuck = State(initialValue: existing?.stuckText ?? "")
        _tryNext = State(initialValue: existing?.tryNextText ?? "")
        _link = State(initialValue: existing?.link ?? "")
        _images = State(initialValue: existing?.imageFileNames ?? [])
    }

    var body: some View {
        VStack(spacing: 0) {
            ReflectHeader(step: step, onBack: goBack, onClose: onClose)
            Group {
                if step == 1 {
                    ReflectPickSessionStep(
                        store: store,
                        selectedSessionId: $selectedSessionId,
                        onContinue: { if selectedSessionId != nil { step = 2 } }
                    )
                } else if step == 2 {
                    ReflectMoodStep(store: store, session: selectedSession, mood: $mood, onContinue: { if mood != nil { step = 3 } })
                } else if step == 3 {
                    ReflectNotesStep(
                        store: store,
                        sessionId: selectedSessionId,
                        worked: $worked,
                        stuck: $stuck,
                        tryNext: $tryNext,
                        link: $link,
                        imageFileNames: $images,
                        onUseVoice: { showVoice = true },
                        onFinish: saveReflection
                    )
                } else {
                    ReflectDoneStep(
                        store: store,
                        sessionId: selectedSessionId,
                        mood: mood,
                        onDone: {
                            if let session = selectedSession {
                                onFinish(session)
                            } else {
                                onClose()
                            }
                        }
                    )
                }
            }
        }
        .id(resetToken)
        .sheet(isPresented: $showVoice) {
            VoiceReflectionView(worked: $worked, stuck: $stuck, tryNext: $tryNext, onClose: { showVoice = false })
        }
    }

    private var selectedSession: PlannedSession? {
        guard let selectedSessionId = selectedSessionId else { return nil }
        return store.notebook.sessions.first { $0.id == selectedSessionId }
    }

    private func goBack() {
        if step <= 1 || (step == 2 && initialSessionId != nil) {
            onClose()
        } else {
            step -= 1
        }
    }

    private func saveReflection() {
        guard let sessionId = selectedSessionId, mood != nil, tryNext.nilIfBlank != nil else { return }
        _ = store.saveReflection(sessionId: sessionId, mood: mood, workedText: worked, stuckText: stuck, tryNextText: tryNext, link: link, imageFileNames: images)
        step = 4
    }
}

struct ReflectHeader: View {
    var step: Int
    var onBack: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .frame(width: 30, height: 30)
                        .dashedCircle()
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibility(label: Text("Back"))
                Spacer()
                if step >= 2 {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.systemGray5))
                            Capsule()
                                .fill(AppColors.indigo)
                                .frame(width: geometry.size.width * CGFloat(step - 1) / 3.0)
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
                .accessibility(label: Text("Close"))
            }
            if step >= 2 {
                Text("Step \(step - 1) of 3")
                    .font(.caption)
                    .foregroundColor(AppColors.label)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
    }
}

struct ReflectPickSessionStep: View {
    @ObservedObject var store: NotebookStore
    @Binding var selectedSessionId: String?
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Which session are you reflecting on?")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .fontWeight(.medium)
                        Text("Pick a planned or completed training session.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryLabel)
                    }

                    let sessions = allSessions()
                    let planned = sessions.filter { $0.status == .planned }
                    let done = sessions.filter { $0.status == .done && !sessionHasReflection($0) }

                    if planned.isEmpty && done.isEmpty {
                        EmptyDashedState(title: "No sessions to reflect on.", subtitle: "Plan a session from the + button, or all sessions have been reflected on.")
                    }

                    if !planned.isEmpty {
                        reflectSessionList(title: "Up next", sessions: planned)
                    }

                    if !done.isEmpty {
                        reflectSessionList(title: "Completed", sessions: done)
                    }
                }
                .padding(16)
            }
        }
    }

    private func sessionHasReflection(_ session: PlannedSession) -> Bool {
        store.reflection(forSessionId: session.id) != nil
    }

    private func reflectSessionList(title: String, sessions: [PlannedSession]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) · \(sessions.count)").fieldLabel()
            ForEach(sessions) { session in
                ReflectSessionRow(
                    store: store,
                    session: session,
                    selected: selectedSessionId == session.id,
                    onSelect: {
                        selectedSessionId = session.id
                        onContinue()
                    }
                )
            }
        }
    }

    private func allSessions() -> [PlannedSession] {
        return store.notebook.sessions
            .sorted { lhs, rhs in
                if lhs.status != rhs.status {
                    return lhs.status == .planned
                }
                return lhs.date > rhs.date
            }
    }
}

struct ReflectSessionRow: View {
    @ObservedObject var store: NotebookStore
    var session: PlannedSession
    var selected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(store.goal(id: session.goalId)?.name ?? "Goal")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(DateFormatter.monthDay.string(from: session.date))
                        .font(.caption)
                        .foregroundColor(selected ? Color.white.opacity(0.7) : .secondary)
                }
                let names = session.taskIds.compactMap { store.task(id: $0)?.name }
                if names.isEmpty {
                    Text("No tasks attached")
                        .font(.caption)
                        .foregroundColor(selected ? Color.white.opacity(0.7) : .secondary)
                } else {
                    Text(names.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(selected ? Color.white.opacity(0.7) : .secondary)
                }
            }
            .foregroundColor(selected ? .white : .primary)
            .padding(12)
            .background(selected ? AppColors.indigo : AppColors.background)
            .cardBackground()
        }
    }

    private func taskNames() -> String {
        let names = session.taskIds.compactMap { store.task(id: $0)?.name }
        return names.isEmpty ? "No tasks attached" : names.joined(separator: " · ")
    }
}

struct ReflectMoodStep: View {
    @ObservedObject var store: NotebookStore
    let session: PlannedSession?
    @Binding var mood: Mood?
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("How did it feel?")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .fontWeight(.medium)
                        Text("One quick read on the session. You can change it any time.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                    if let session = session {
                        reflectGoalCard(session)
                    }
                    LazyMoodGrid(mood: $mood)
                }
                .padding(16)
            }
            Button("Continue", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(mood == nil)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 30)
        }
    }

    @ViewBuilder
    private func reflectGoalCard(_ session: PlannedSession) -> some View {
        let goal = store.goal(id: session.goalId)
        let color = goal?.goalColor ?? AppColors.indigo
        let tasks = session.taskIds.compactMap { store.task(id: $0) }
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                GoalIconImage(name: goal?.iconName ?? "target", color: color, size: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal?.name ?? "Session")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.label)
                    Text(longDate(session.date))
                        .font(.matMindBody(size: 14))
                        .foregroundColor(AppColors.secondaryLabel)
                }
                Spacer()
            }
            if !tasks.isEmpty {
                WrappingHStack(items: tasks) { task in
                    Text(task.name)
                        .font(.matMindBody(size: 14))
                        .foregroundColor(color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(color.opacity(0.12))
                        .cornerRadius(14)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.secondaryBackground))
    }

    private func longDate(_ d: Date) -> String {
        return DateFormatter.weekdayLongDate.string(from: d)
    }
}

struct LazyMoodGrid: View {
    @Binding var mood: Mood?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                moodButton(.frustrated)
                moodButton(.neutral)
            }
            HStack(spacing: 12) {
                moodButton(.good)
                moodButton(.great)
            }
        }
    }

    private func moodButton(_ option: Mood) -> some View {
        Button(action: { mood = option }) {
            VStack(spacing: 8) {
                Text(option.glyph)
                    .font(.system(size: 34, weight: .medium, design: .rounded))
                Text(option.label)
                    .font(.caption)
                    .uppercaseTracking()
            }
            .frame(maxWidth: .infinity, minHeight: 124)
            .foregroundColor(mood == option ? .white : AppColors.label)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(mood == option ? AppColors.indigo : AppColors.secondaryBackground)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ReflectNotesStep: View {
    @ObservedObject var store: NotebookStore
    let sessionId: String?
    @Binding var worked: String
    @Binding var stuck: String
    @Binding var tryNext: String
    @Binding var link: String
    @Binding var imageFileNames: [String]
    var onUseVoice: () -> Void
    var onFinish: () -> Void

    @State private var showLinkField = false
    @State private var showPhotoPicker = false

    private var canFinish: Bool { tryNext.nilIfBlank != nil }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What stood out?")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .fontWeight(.medium)
                        Text("A line or two for each is plenty.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryLabel)
                    }

                    Button(action: onUseVoice) {
                        HStack(spacing: 8) {
                            Image(systemName: "mic.fill")
                            Text("Use Voice Instead")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(AppColors.indigo)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.indigo.opacity(0.10)))
                    }
                    .buttonStyle(PlainButtonStyle())

                    labeledField($worked, "What worked today", AppColors.winGreen, "A grip, a setup, a moment that clicked...")
                    labeledField($stuck, "Where I got stuck", AppColors.stuckCoral, "What didn't work, what felt off, what to adjust...")
                    labeledField($tryNext, "What I'll try next *", AppColors.indigo, "A different angle, a drill to try, something to focus on...")

                    linkRow
                    photosRow
                }
                .padding(16)
            }
            Button("Save reflection", action: onFinish)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canFinish)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 30)
        }
        .sheet(isPresented: $showPhotoPicker) {
            NoteImagePicker { data in
                if let sid = sessionId, let fn = store.addReflectionImage(sessionId: sid, imageData: data) {
                    imageFileNames.append(fn)
                }
            }
        }
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

    @ViewBuilder
    private var linkRow: some View {
        if showLinkField || link.nilIfBlank != nil {
            HStack(spacing: 8) {
                Image(systemName: "link").foregroundColor(AppColors.secondaryLabel)
                TextField("Paste link...", text: $link).font(.matMindBody(size: 14))
            }
            .padding(11)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray3), lineWidth: 1))
        } else {
            Button(action: { showLinkField = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "link.badge.plus")
                    Text("Add link").font(.system(size: 15, weight: .medium, design: .rounded))
                }
                .foregroundColor(AppColors.label)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var photosRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle")
                Text("Attach photos").font(.system(size: 15, weight: .medium, design: .rounded))
            }
            .foregroundColor(AppColors.label)

            if !imageFileNames.isEmpty, let sid = sessionId {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(imageFileNames, id: \.self) { fn in
                            thumbnail(sid: sid, fn: fn)
                        }
                    }
                }
            }

            Button(action: { showPhotoPicker = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 20))
                    Text("Choose from album").font(.system(size: 16, weight: .medium, design: .rounded))
                }
                .foregroundColor(AppColors.indigo)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.indigo.opacity(0.08)))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func thumbnail(sid: String, fn: String) -> some View {
        ZStack(alignment: .topTrailing) {
            if let data = store.reflectionImageData(sessionId: sid, fileName: fn), let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5)).frame(width: 84, height: 84)
            }
            Button(action: { imageFileNames.removeAll { $0 == fn } }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.4)))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(4)
        }
    }
}

// MARK: - Voice Reflection

struct VoiceReflectionView: View {
    @Binding var worked: String
    @Binding var stuck: String
    @Binding var tryNext: String
    var onClose: () -> Void

    private enum Phase { case idle, recording, recorded }

    @State private var index = 0
    @State private var phase: Phase = .idle
    @State private var draft = ""
    @State private var elapsed = 0
    @State private var statusMessage: String?
    @State private var recognizer = SpeechRecognizer()
    @State private var timer: Timer?

    private let questions: [(label: String, color: Color, prompt: String)] = [
        ("What worked today", AppColors.winGreen, "A grip, a setup, a moment that clicked..."),
        ("Where I got stuck", AppColors.stuckCoral, "What didn't work, what felt off, what to adjust..."),
        ("What I'll try next", AppColors.indigo, "A different angle, a drill to try, something to focus on...")
    ]
    private var q: (label: String, color: Color, prompt: String) { questions[index] }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: handleBack) {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.label).frame(width: 44, height: 44)
                }
                Spacer()
                Text("\(index + 1) of 3")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.label)
                Spacer()
                Button(action: { stopRecording(); onClose() }) {
                    Image(systemName: "xmark").font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.label).frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 8)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule().fill(q.color).frame(width: geo.size.width * CGFloat(index + 1) / 3.0)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 16)

            Spacer()

            Text(q.label)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().fill(q.color))
            Text(q.prompt)
                .font(.system(size: 22, weight: .regular, design: .rounded))
                .foregroundColor(AppColors.secondaryLabel)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 16)

            Spacer()

            phaseContent

            Spacer()

            if let s = statusMessage {
                Text(s)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            bottomButton
                .padding(.horizontal, 16)
                .padding(.bottom, phase == .idle ? 8 : 30)

            if phase == .idle {
                Button(action: skip) {
                    Text("Skip").font(.system(size: 17, design: .rounded)).foregroundColor(AppColors.secondaryLabel)
                }
                .padding(.bottom, 24)
            }
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
        .onAppear {
            draft = bindingValue()
            phase = draft.nilIfBlank != nil ? .recorded : .idle
            recognizer.onText = { text in draft = text }
            recognizer.onStatus = { msg in statusMessage = msg }
        }
        .onDisappear { stopRecording() }
    }

    @ViewBuilder
    private var phaseContent: some View {
        if phase == .recording {
            VStack(spacing: 16) {
                VoiceWaveform(color: q.color)
                    .frame(height: 44)
                    .padding(.horizontal, 40)
                HStack(spacing: 8) {
                    Circle().fill(AppColors.stuckCoral).frame(width: 10, height: 10)
                    Text("Recording…")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.stuckCoral)
                    Text(timeString)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.label)
                }
            }
        } else if phase == .recorded {
            VStack(spacing: 10) {
                TrainingTextView(text: $draft, placeholder: "Your words appear here. You can edit them.")
                    .frame(height: 150)
                    .padding(.horizontal, 16)
                Button(action: reRecord) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise").font(.system(size: 13))
                        Text("Re-record").font(.system(size: 16, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(AppColors.secondaryLabel)
                }
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var bottomButton: some View {
        switch phase {
        case .idle:
            bigButton("Tap to Record", icon: "mic.fill", color: q.color, action: startRecording)
        case .recording:
            bigButton("Done", icon: "stop.fill", color: AppColors.stuckCoral, action: finishRecording)
        case .recorded:
            bigButton(index < questions.count - 1 ? "Next" : "Done", icon: nil, color: AppColors.indigo, action: next)
        }
    }

    private func bigButton(_ title: String, icon: String?, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon { Image(systemName: icon).font(.system(size: 18)) }
                Text(title).font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(RoundedRectangle(cornerRadius: 16).fill(color))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var timeString: String { String(format: "%d:%02d", elapsed / 60, elapsed % 60) }

    private func bindingValue() -> String { index == 0 ? worked : (index == 1 ? stuck : tryNext) }
    private func setBindingValue(_ v: String) { if index == 0 { worked = v } else if index == 1 { stuck = v } else { tryNext = v } }

    private func startRecording() {
        recognizer.requestAuthorization { granted in
            if !granted { statusMessage = "Mic/speech access is off — you can still type your answer." }
            recognizer.start()
            elapsed = 0
            phase = .recording
            startTimer()
        }
    }

    private func finishRecording() {
        stopRecording()
        phase = .recorded
    }

    private func reRecord() {
        draft = ""
        startRecording()
    }

    private func skip() { goNext() }

    private func next() {
        setBindingValue(draft)
        goNext()
    }

    private func goNext() {
        stopRecording()
        if index < questions.count - 1 {
            index += 1
            draft = bindingValue()
            phase = draft.nilIfBlank != nil ? .recorded : .idle
            statusMessage = nil
        } else {
            onClose()
        }
    }

    private func handleBack() {
        stopRecording()
        if phase == .recorded { setBindingValue(draft) }
        if index > 0 {
            index -= 1
            draft = bindingValue()
            phase = draft.nilIfBlank != nil ? .recorded : .idle
            statusMessage = nil
        } else {
            onClose()
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in elapsed += 1 }
    }

    private func stopRecording() {
        timer?.invalidate()
        timer = nil
        recognizer.stop()
    }
}

struct VoiceWaveform: View {
    let color: Color
    @State private var heights: [CGFloat] = Array(repeating: 6, count: 26)
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<heights.count, id: \.self) { i in
                Capsule().fill(color).frame(width: 4, height: heights[i])
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.12)) {
                    heights = (0..<heights.count).map { idx in
                        // Taller toward the right, like a live meter.
                        let bias = CGFloat(idx) / CGFloat(heights.count)
                        return CGFloat.random(in: 6...(10 + bias * 34))
                    }
                }
            }
        }
        .onDisappear { timer?.invalidate() }
    }
}

struct ReflectDoneStep: View {
    @ObservedObject var store: NotebookStore
    var sessionId: String?
    var mood: Mood?
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 38, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 82, height: 82)
                .background(AppColors.mint)
                .clipShape(Circle())
            Text("Reflection logged.")
                .font(.title)
                .fontWeight(.medium)
            Text("Small notes compound. Keep showing up.")
                .font(.subheadline)
                .foregroundColor(AppColors.label)
                .multilineTextAlignment(.center)
            if let session = session {
                DashedPanel {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.date.trainingDayString).fieldLabel()
                        Text(store.goal(id: session.goalId)?.name ?? "Goal")
                            .font(.headline)
                        let names = session.taskIds.compactMap { store.task(id: $0)?.name }
                        if !names.isEmpty {
                            Text(names.joined(separator: " · "))
                                .font(.caption)
                                .foregroundColor(AppColors.label)
                        }
                        if let mood = mood {
                            Text("\(mood.glyph) \(mood.label)")
                                .font(.caption)
                                .foregroundColor(AppColors.label)
                        }
                    }
                }
                .padding(.horizontal)
            }
            Spacer()
            Button("Done", action: onDone)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 30)
        }
    }

    private var session: PlannedSession? {
        guard let sessionId = sessionId else { return nil }
        return store.notebook.sessions.first { $0.id == sessionId }
    }
}

// MARK: - Preview
