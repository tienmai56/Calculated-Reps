import SwiftUI

struct BountyFlowView: View {
    @ObservedObject var store: NotebookStore
    var onClose: () -> Void

    @State private var step = 0
    @State private var kind: BountyKind?
    @State private var selectedTaskId: String?
    @State private var count = 5
    @State private var partner = ""

    private var eligible: [(task: TrainingTask, goal: TrainingGoal, sessionCount: Int)] {
        store.bountyEligibleTasks()
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch step {
                    case 0: pickChallengeStep
                    case 1: pickTechniqueStep
                    default: setTargetStep
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            footer
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }

    private var header: some View {
        HStack {
            Button(action: { if step == 0 { onClose() } else { step -= 1 } }) {
                HStack(spacing: 3) {
                    Image(systemName: step == 0 ? "xmark" : "chevron.left")
                    Text(step == 0 ? "Cancel" : "Back")
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(step == 0 ? AppColors.secondaryLabel : AppColors.indigo)
            }
            Spacer()
            Text("New Bounty")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.label)
            Spacer()
            Color.clear.frame(width: 56, height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    // Step 1
    private var pickChallengeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Pick your challenge")
                .font(.system(size: 27, weight: .heavy, design: .rounded))
                .foregroundColor(AppColors.label)
            Text("What do you want to hunt?")
                .font(.matMindBody(size: 14))
                .foregroundColor(AppColors.secondaryLabel)
                .padding(.top, 8)
            VStack(spacing: 14) {
                ForEach(BountyKind.allCases) { k in
                    bountyChoiceCard(k)
                }
            }
            .padding(.top, 20)
        }
    }

    private func bountyChoiceCard(_ k: BountyKind) -> some View {
        let selected = kind == k
        return Button(action: { kind = k }) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.coral.opacity(selected ? 0.22 : 0.14))
                            .frame(width: 40, height: 40)
                        Image(systemName: k.symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppColors.coralDeep)
                    }
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(AppColors.coralDeep)
                    }
                }
                Text(k.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.label)
                    .padding(.top, 12)
                Text(k.blurb)
                    .font(.matMindBody(size: 13))
                    .foregroundColor(AppColors.secondaryLabel)
                    .padding(.top, 3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(selected ? AppColors.coral.opacity(0.08) : AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(selected ? AppColors.coral : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // Step 2
    private var pickTechniqueStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Which technique?")
                .font(.system(size: 27, weight: .heavy, design: .rounded))
                .foregroundColor(AppColors.label)
            Text("Tasks from goals you've trained for 2+ weeks.")
                .font(.matMindBody(size: 14))
                .foregroundColor(AppColors.secondaryLabel)
                .padding(.top, 8)
            if eligible.isEmpty {
                Text("No eligible techniques yet. Keep training a goal for two weeks to unlock the hunt.")
                    .font(.matMindBody(size: 14))
                    .foregroundColor(AppColors.secondaryLabel)
                    .padding(.top, 20)
            } else {
                VStack(spacing: 11) {
                    ForEach(eligible, id: \.task.id) { item in
                        techniqueRow(item)
                    }
                }
                .padding(.top, 16)
            }
        }
    }

    private func techniqueRow(_ item: (task: TrainingTask, goal: TrainingGoal, sessionCount: Int)) -> some View {
        let selected = selectedTaskId == item.task.id
        return Button(action: { selectedTaskId = item.task.id }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.task.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.label)
                    Text(item.goal.name)
                        .font(.matMindBody(size: 12.5))
                        .foregroundColor(AppColors.secondaryLabel)
                }
                Spacer()
                Text("\(item.sessionCount) \(item.sessionCount == 1 ? "session" : "sessions")")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.tertiaryLabel)
            }
            .padding(.horizontal, 15).padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? AppColors.coral.opacity(0.08) : AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? AppColors.coral : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // Step 3
    private var setTargetStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Set the target")
                .font(.system(size: 27, weight: .heavy, design: .rounded))
                .foregroundColor(AppColors.label)
            Text("How many, and on who? Leave blank for either.")
                .font(.matMindBody(size: 14))
                .foregroundColor(AppColors.secondaryLabel)
                .padding(.top, 8)

            Text("HIT IT · HOW MANY TIMES")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(0.6)
                .foregroundColor(AppColors.secondaryLabel)
                .padding(.top, 24).padding(.bottom, 10)
            HStack {
                stepperButton("minus") { if count > 1 { count -= 1 } }
                Spacer()
                VStack(spacing: 2) {
                    Text("\(count)")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundColor(AppColors.label)
                    Text("TIMES")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(AppColors.secondaryLabel)
                }
                Spacer()
                stepperButton("plus") { count += 1 }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.cardBackground))

            HStack {
                Text("WHO ARE YOU HUNTING?")
                Spacer()
                Text(kind == .hitCount ? "OPTIONAL" : "REQUIRED").foregroundColor(AppColors.tertiaryLabel)
            }
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundColor(AppColors.secondaryLabel)
            .padding(.top, 22).padding(.bottom, 10)
            TextField("Name a partner", text: $partner)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.label)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.cardBackground))

            VStack(alignment: .leading, spacing: 6) {
                Text("PREVIEW")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .foregroundColor(AppColors.coralDeep)
                Text(previewText())
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.label)
                    .fixedSize(horizontal: false, vertical: true)
                Text("No deadline. Hunt at your own pace.")
                    .font(.matMindBody(size: 12.5))
                    .foregroundColor(AppColors.secondaryLabel)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16).fill(AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.coral)
                    .frame(width: 4)
                    .frame(maxWidth: .infinity, alignment: .leading),
                alignment: .leading
            )
            .padding(.top, 20)
        }
    }

    private func stepperButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppColors.label)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.secondaryBackground))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func previewText() -> String {
        let name = store.task(id: selectedTaskId ?? "")?.name ?? "it"
        var s = "Hit \(name)"
        if let p = partner.nilIfBlank { s += " on \(p)" }
        if count > 1 { s += ", \(count)×" }
        return s + "."
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Button(action: advance) {
                Text(step == 2 ? "Start Bounty" : "Next")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 16).fill(step == 2 ? AppColors.coralDeep : AppColors.indigo))
                    .opacity(canAdvance ? 1 : 0.4)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canAdvance)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 24)
        .background(AppColors.background)
    }

    private var canAdvance: Bool {
        switch step {
        case 0: return kind != nil
        case 1: return selectedTaskId != nil
        default:
            // Hit count doesn't need a partner; targeting a partner does.
            return kind == .hitCount || partner.nilIfBlank != nil
        }
    }

    private func advance() {
        guard canAdvance else { return }
        if step < 2 {
            step += 1
        } else if let taskId = selectedTaskId, let kind = kind {
            store.createBounty(taskId: taskId, kind: kind, targetCount: count, targetPartner: partner)
            onClose()
        }
    }
}

// MARK: - Bounty Collection

/// Trophy shelf of collected bounties, plus a celebration hero for the most recent.
struct BountyCollectionView: View {
    @ObservedObject var store: NotebookStore
    var onClose: () -> Void

    @State private var showFlow = false

    private var collected: [Bounty] { store.collectedBounties }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let latest = collected.first {
                        celebrationHero(latest)
                        featuredTrophy(latest)
                        if collected.count > 1 {
                            miniGrid(Array(collected.dropFirst()))
                        }
                    } else {
                        emptyState
                    }
                    newBountyButton
                        .padding(.top, 22)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 30)
            }
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
        .sheet(isPresented: $showFlow) {
            BountyFlowView(store: store, onClose: { showFlow = false })
        }
    }

    private var header: some View {
        HStack {
            Button(action: onClose) {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left")
                    Text("Home")
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.indigo)
            }
            Spacer()
            Text("Collection")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.label)
            Spacer()
            Color.clear.frame(width: 56, height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private func celebrationHero(_ bounty: Bounty) -> some View {
        let stats = store.bountyStats(bounty)
        let name = store.task(id: bounty.taskId)?.name ?? "your technique"
        var summary = "\(name.capitalizedFirst), landed \(stats.hits)×"
        if let p = bounty.targetPartner?.nilIfBlank { summary += " on \(p)" }
        summary += " over \(stats.days) \(stats.days == 1 ? "day" : "days")."
        return VStack(spacing: 6) {
            Text("🏆")
                .font(.system(size: 60))
                .padding(.top, 6)
            Text("BOUNTY COLLECTED")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundColor(AppColors.gold)
            Text("You hunted it down.")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundColor(AppColors.label)
                .padding(.top, 4)
            Text(summary)
                .font(.matMindBody(size: 13))
                .foregroundColor(AppColors.secondaryLabel)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
            HStack(spacing: 6) {
                Text("🏆 \(collected.count) \(collected.count == 1 ? "bounty" : "bounties") collected")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.gold)
            }
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(Capsule().fill(AppColors.gold.opacity(0.16)))
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
    }

    private func featuredTrophy(_ bounty: Bounty) -> some View {
        let stats = store.bountyStats(bounty)
        let name = store.task(id: bounty.taskId)?.name ?? "Technique"
        var sub = "\(bounty.hitCount) \(bounty.hitCount == 1 ? "hit" : "hits")"
        if let p = bounty.targetPartner?.nilIfBlank { sub = "on \(p) · " + sub }
        return VStack(alignment: .leading, spacing: 6) {
            Text(collectedMeta(bounty))
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(0.6)
                .foregroundColor(AppColors.gold)
            Text(name)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.label)
            Text(sub)
                .font(.matMindBody(size: 13))
                .foregroundColor(AppColors.secondaryLabel)
            HStack(spacing: 8) {
                statBox("SESSIONS", stats.sessions)
                statBox("DAYS", stats.days)
                statBox("HITS", stats.hits)
            }
            .padding(.top, 6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.cardBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.gold)
                .frame(height: 3)
                .frame(maxWidth: .infinity, alignment: .top),
            alignment: .top
        )
        .padding(.top, 16)
    }

    private func statBox(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.5)
                .foregroundColor(AppColors.secondaryLabel)
            Text("\(value)")
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundColor(AppColors.label)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.secondaryBackground))
    }

    private func miniGrid(_ bounties: [Bounty]) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(stride(from: 0, to: bounties.count, by: 2)), id: \.self) { i in
                HStack(spacing: 10) {
                    miniCard(bounties[i])
                    if i + 1 < bounties.count {
                        miniCard(bounties[i + 1])
                    } else {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.top, 12)
    }

    private func miniCard(_ bounty: Bounty) -> some View {
        let name = store.task(id: bounty.taskId)?.name ?? "Technique"
        var sub = DateFormatter.monthDay.string(from: bounty.collectedAt ?? bounty.createdAt)
        if let p = bounty.targetPartner?.nilIfBlank {
            sub += " · on \(p)"
        } else {
            sub += " · \(bounty.hitCount)×"
        }
        return VStack(alignment: .leading, spacing: 6) {
            Text("🏆").font(.system(size: 20))
            Text(name)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.label)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(sub)
                .font(.matMindBody(size: 11))
                .foregroundColor(AppColors.secondaryLabel)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.cardBackground))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("🏆").font(.system(size: 52)).opacity(0.5)
            Text("No bounties collected yet")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.label)
            Text("Land your first hunt and it'll live here.")
                .font(.matMindBody(size: 13))
                .foregroundColor(AppColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    @ViewBuilder
    private var newBountyButton: some View {
        if store.activeBounty == nil && store.hasBountyEligibleGoal {
            Button(action: { showFlow = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("New bounty")
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.coralDeep))
            }
            .buttonStyle(PlainButtonStyle())
        } else if store.activeBounty != nil {
            Text("Finish your active hunt before starting a new one.")
                .font(.matMindBody(size: 12.5))
                .foregroundColor(AppColors.secondaryLabel)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func collectedMeta(_ bounty: Bounty) -> String {
        let d = bounty.collectedAt ?? bounty.createdAt
        return DateFormatter.monthDayTime.string(from: d).uppercased()
    }
}
