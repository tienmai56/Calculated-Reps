#if DEBUG || MAT_MIND_PROTOTYPE
import SwiftUI

/// Every design-system component and token group on one scrolling page,
/// for checking against `guidelines/*.html` and `design-system/components/*.card.html`.
struct ComponentGallery: View {
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var checked = true
    @State private var radio = "gi"
    @State private var switchOn = true
    @State private var segment = "Upcoming"
    @State private var underline = "Week"
    @State private var tab = "activity"
    @State private var select = "purple"
    @State private var tag = "Tidewater BJJ"
    @State private var showSheet = false
    @State private var showModal = false
    @State private var tooltip = false

    var body: some View {
        MMScreen {
            MMHeader(title: "Components", leading: {
                MMIconButton("chevron-left", label: "Back") { dismiss() }
            })
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                group("Color") {
                    swatches([("paper", MMColor.paper), ("paper-2", MMColor.paper2), ("paper-3", MMColor.paper3), ("ink-900", MMColor.ink900),
                              ("ink-500", MMColor.ink500), ("coral-500", MMColor.coral500), ("flame-500", MMColor.flame500)])
                    swatches(FriendHue.allCases.map { ($0.rawValue, $0.base) })
                    swatches(FriendHue.allCases.map { ($0.rawValue + "-100", $0.tint) })
                }
                group("Type") {
                    ForEach([MMTextStyle.displayXL, .displayL, .displayM, .titleL, .titleM, .titleS, .bodyL, .body, .bodyS, .caption], id: \.size) { style in
                        Text("Roll together by Sunday").mmText(style).foregroundStyle(MMColor.textPrimary).lineLimit(1)
                    }
                    Text("matmonkeys.app/s/k3x9q").mmFont(.mono, 14, .semibold).foregroundStyle(MMColor.textPrimary)
                }
                group("Button") {
                    MMButton("Plan a session", iconLeft: "plus") {}
                    HStack { MMButton("Secondary", variant: .secondary) {}; MMButton("Soft", variant: .soft) {} }
                    HStack { MMButton("Ghost", variant: .ghost) {}; MMButton("Inverse", variant: .inverse) {}; MMButton("Danger", variant: .danger) {} }
                    HStack { MMButton("Small", size: .sm) {}; MMButton("Large", size: .lg) {} }
                    MMButton("Disabled", fullWidth: true) {}.disabled(true)
                }
                group("IconButton") {
                    HStack {
                        MMIconButton("bell", badge: .count(3), label: "Ghost") {}
                        MMIconButton("qr-code", variant: .filled, label: "Filled") {}
                        MMIconButton("send", variant: .accent, label: "Accent") {}
                        MMIconButton("x", variant: .inverse, label: "Inverse") {}
                        MMIconButton("heart", active: true, filledWhenActive: true, label: "Liked") {}
                    }
                }
                group("Forms") {
                    MMTextField(label: "Name", placeholder: "Your name", text: $text, hint: "Shown to friends only")
                    MMTextField(label: "Email", text: .constant("dani@"), error: "That email doesn't look right", iconLeft: "mail")
                    MMSelect(label: "Belt", options: BeltRank.adultRanks.map(\.rawValue), selection: $select)
                    MMCheckbox(isOn: $checked, label: "Remind me", description: "The night before")
                    MMRadio(isSelected: radio == "gi", label: "Gi") { radio = "gi" }
                    MMRadio(isSelected: radio == "nogi", label: "No-gi") { radio = "nogi" }
                    MMSwitch(isOn: $switchOn, label: "Training completed", description: "Counts toward weekly streaks.")
                }
                group("Display") {
                    MMCard { Text("Default card").mmFont(.body, 15) }
                    MMCard(variant: .sunken) { Text("Sunken card").mmFont(.body, 15) }
                    MMCard(variant: .outline) { Text("Outline card").mmFont(.body, 15) }
                    MMFlowLayout {
                        ForEach([MMBadgeVariant.neutral, .accent, .soft, .success, .warning, .danger, .info, .flame], id: \.self) { v in
                            MMBadge("\(v)".capitalized, variant: v)
                        }
                    }
                    MMFlowLayout {
                        ForEach(SeedData.gyms, id: \.self) { g in MMTag(g, selected: tag == g, size: .sm) { tag = g } }
                        MMTag("Removable", icon: "map-pin", onRemove: {})
                    }
                    HStack(spacing: 10) {
                        MMAvatar(name: "Dani Alves", photo: "portrait-gi", size: 60, belt: .purple)
                        MMAvatar(name: "Sarah Lee", size: 52, belt: .blue, online: true)
                        MMAvatar(name: "Alex Moreno", size: 44, belt: .white)
                        MMAvatar(name: "Kenji Ito", size: 34)
                        MMAvatarStack(people: ["Sarah Lee", "Alex Moreno", "Kenji Ito", "Priya Nair", "Lena Park"].map { MMAvatarPerson(name: $0) },
                                      size: 30, label: "5 going")
                    }
                    ForEach([BeltRank.white, .blue, .purple, .brown, .black], id: \.self) { r in
                        MMBelt(rank: r, stripes: 2, size: .md, showLabel: true)
                    }
                    MMStreakBelt(weeks: [false, true, true, true, true, true, true, true, true], thisWeek: .pending, hue: .sky)
                    MMStreakBelt(weeks: [true, false, false, false, false, false, true, true, true], thisWeek: .done, hue: .mint)
                    MMStreakBelt(weeks: [true, true, true, true, true, true, false, false, false], thisWeek: .pending, hue: .plum)
                }
                group("Navigation") {
                    MMTabs(["Upcoming", "Past"], selection: $segment)
                    MMTabs(["Week", "Month", "Year"], selection: $underline, variant: .underline)
                    MMTabBar(items: [
                        MMTabBarItem(id: "activity", label: "Activity", icon: "house"),
                        MMTabBarItem(id: "training", label: "Training", icon: "calendar"),
                        MMTabBarItem(id: "friends", label: "Friends", icon: "users", badge: true),
                        MMTabBarItem(id: "profile", label: "Profile", icon: "user"),
                    ], selection: $tab, centerAction: {})
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                group("Feedback") {
                    MMToast(message: "You're in. See you on the mat.", variant: .success)
                    MMToast(message: "8 weeks with Sarah", variant: .streak)
                    MMToast(message: "Lena joined Saturday open mat", variant: .friend, actionLabel: "View") {}
                    HStack {
                        MMButton("Open sheet", variant: .secondary, size: .sm) { showSheet = true }
                        MMButton("Open modal", variant: .secondary, size: .sm) { showModal = true }
                        MMIconButton("info", variant: .filled, label: "Tooltip") { tooltip.toggle() }
                            .mmTooltip("Weeks run Mon–Sun", isPresented: tooltip)
                    }
                    .padding(.top, 30)
                }
                group("Patterns") {
                    MMPhotoTile(photo: "roll-gi", height: 200, radius: 20) {
                        MMTapeLabel(text: "Tidewater BJJ")
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                            .padding(12)
                    }
                    MMPairAvatars(a: MMAvatarPerson(name: "Dani Alves", photo: "portrait-gi"), b: MMAvatarPerson(name: "Sarah Lee"), hue: .sky)
                    MMHatch(color: MMColor.coral100).frame(height: 40).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Color.clear.frame(height: 40)
            }
            .padding(.horizontal, 16)
        }
        .mmSheet(isPresented: $showSheet, title: "Add people", description: "They're added straight to the session.") {
            Text("Sheet content").mmFont(.body, 15)
        } actions: {
            MMButton("Add 2", fullWidth: true) { showSheet = false }
        }
        .mmModal(isPresented: $showModal, title: "Delete this post?", description: "It disappears from all 4 profiles.") {
            MMButton("Keep it", variant: .secondary, fullWidth: true) { showModal = false }
            MMButton("Delete", variant: .danger, fullWidth: true) { showModal = false }
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).mmFont(.display, 18).foregroundStyle(MMColor.ink900)
            content()
        }
        .padding(.top, 24)
    }

    private func swatches(_ items: [(String, Color)]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.0) { name, color in
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(color)
                            .frame(width: 64, height: 44)
                            .mmOutline(radius: 10, color: MMColor.borderSubtle, width: 1)
                        Text(name).mmFont(.body, 11, .semibold).foregroundStyle(MMColor.textSecondary)
                    }
                }
            }
        }
    }
}

#endif
