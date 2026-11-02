import SwiftUI

// MARK: - Tabs

struct MMTabItem: Identifiable, Hashable {
    var id: String
    var label: String
    var count: Int?

    init(_ id: String, _ label: String? = nil, count: Int? = nil) {
        self.id = id
        self.label = label ?? id
        self.count = count
    }
}

/// Segmented (paper-2 track, white thumb) or underline (coral bar) tabs.
struct MMTabs: View {
    enum Variant { case segmented, underline }

    var items: [MMTabItem]
    @Binding var selection: String
    var variant: Variant = .segmented

    @Namespace private var thumb

    init(items: [MMTabItem], selection: Binding<String>, variant: Variant = .segmented) {
        self.items = items
        self._selection = selection
        self.variant = variant
    }

    init(_ labels: [String], selection: Binding<String>, variant: Variant = .segmented) {
        self.init(items: labels.map { MMTabItem($0) }, selection: selection, variant: variant)
    }

    var body: some View {
        switch variant {
        case .segmented:
            HStack(spacing: 2) {
                ForEach(items) { item in tab(item) }
            }
            .padding(4)
            .background(Capsule().fill(MMColor.paper2))
        case .underline:
            HStack(spacing: 22) {
                ForEach(items) { item in tab(item) }
            }
        }
    }

    private func tab(_ item: MMTabItem) -> some View {
        let on = item.id == selection
        let segmented = variant == .segmented
        return Button {
            withAnimation(MMMotion.easeOut(MMMotion.base)) { selection = item.id }
        } label: {
            HStack(spacing: 6) {
                Text(item.label)
                    .mmFont(.display, 15, on ? .extraBold : .semibold, tracking: -0.01, lineHeight: 1)
                if let count = item.count {
                    Text("\(count)")
                        .mmFont(.body, 11, .bold, lineHeight: 1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Capsule().fill(MMColor.accent))
                }
            }
            .lineLimit(1)
            .foregroundStyle(on ? MMColor.textPrimary : MMColor.textTertiary)
            .padding(.horizontal, segmented ? 14 : 0)
            .frame(maxWidth: segmented ? .infinity : nil)
            .frame(height: segmented ? 38 : 40)
            .background {
                if segmented && on {
                    Capsule().fill(MMColor.white)
                        .shadow(color: MMColor.ink900.opacity(0.12), radius: 1.5, x: 0, y: 1)
                        .matchedGeometryEffect(id: "thumb", in: thumb)
                }
            }
            .overlay(alignment: .bottom) {
                if !segmented && on {
                    GeometryReader { g in
                        Capsule().fill(MMColor.accent)
                            .frame(width: g.size.width * 0.6, height: 4)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - TabBar

struct MMTabBarItem: Identifiable {
    var id: String
    var label: String
    var icon: String
    var badge = false
}

/// 86pt bar: white 90% over a blur, with the coral "Plan a session" pill in the middle.
struct MMTabBar: View {
    var items: [MMTabBarItem]
    @Binding var selection: String
    var centerIcon = "plus"
    var centerLabel = "Plan a session"
    var centerAction: (() -> Void)?

    var body: some View {
        let half = (items.count + 1) / 2
        HStack(alignment: .top, spacing: 0) {
            ForEach(items.prefix(centerAction == nil ? items.count : half)) { item in tab(item) }
            if let centerAction {
                Button(action: centerAction) {
                    MMIcon(centerIcon, size: 26, weight: .bold, color: .white)
                        .frame(width: 56, height: 46)
                        .background {
                            ZStack {
                                Capsule().fill(MMColor.accentShade).offset(y: 3)
                                Capsule().fill(MMColor.accent)
                            }
                        }
                }
                .buttonStyle(MMPressStyle(scale: 0.92, bounce: true))
                .accessibilityLabel(centerLabel)
                .padding(.top, 8)
                .frame(maxWidth: .infinity)
                ForEach(items.suffix(from: half)) { item in tab(item) }
            }
        }
        .padding(.horizontal, 6)
        .frame(height: MMLayout.tabBarHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color.white.opacity(0.9)
            }
            .overlay(alignment: .top) { Rectangle().fill(MMColor.borderSubtle).frame(height: 1) }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tab(_ item: MMTabBarItem) -> some View {
        let on = item.id == selection
        return Button {
            selection = item.id
        } label: {
            VStack(spacing: 4) {
                MMIcon(item.icon, size: 24, weight: on ? .bold : .regular)
                    .overlay(alignment: .topTrailing) {
                        if item.badge {
                            Circle().fill(MMColor.accent).frame(width: 9, height: 9)
                                .background(Circle().fill(Color.white).padding(-2))
                                .offset(x: 4, y: -2)
                        }
                    }
                    .offset(y: on ? -1 : 0)
                    .animation(MMMotion.bounce(MMMotion.base), value: on)
                Text(item.label).mmFont(.display, 11, on ? .extraBold : .semibold, tracking: 0, lineHeight: 1)
            }
            .foregroundStyle(on ? MMColor.textPrimary : MMColor.ink400)
            .padding(.top, 10)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
