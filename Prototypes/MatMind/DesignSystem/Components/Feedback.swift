import SwiftUI

// MARK: - Toast

enum MMToastVariant {
    case neutral, success, danger, streak, friend

    var icon: String? {
        switch self {
        case .neutral: nil
        case .success: "circle-check"
        case .danger: "triangle-alert"
        case .streak: "flame"
        case .friend: "handshake"
        }
    }

    var iconColor: Color {
        switch self {
        case .neutral: MMColor.paper
        case .success: MMColor.mint500
        case .danger: Color(mmHex: 0xFF7B7D)
        case .streak: MMColor.flame500
        case .friend: MMColor.sun400
        }
    }
}

struct MMToastData: Identifiable, Equatable {
    let id = UUID()
    var message: String
    var variant: MMToastVariant = .neutral
    /// Shown next to the control that caused it (Activity's week card) instead of at the top of the screen.
    var inline = false
}

/// Ink pill that drops from the top. Auto-dismiss (2.6s) is the host's job.
struct MMToast: View {
    var message: String
    var variant: MMToastVariant = .neutral
    var actionLabel: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            if let icon = variant.icon {
                MMIcon(icon, size: 20, filled: variant == .streak, color: variant.iconColor)
            }
            Text(message)
                .mmFont(.body, 15, .semibold, lineHeight: 1.3)
                .foregroundStyle(MMColor.paper)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let actionLabel, let action {
                Button(action: action) {
                    Text(actionLabel)
                        .mmFont(.display, 14, .bold, lineHeight: 1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .frame(minHeight: 52)
        .background(Capsule().fill(MMColor.ink900).mmShadowFloat())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Dialog

/// The shared body of a sheet or modal: title, description, close, content, actions.
struct MMDialogBody<Content: View, Actions: View>: View {
    var title: String?
    var description: String?
    var onClose: (() -> Void)?
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if title != nil || onClose != nil {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let title {
                            Text(title).mmFont(.display, 22, tracking: -0.02, lineHeight: 1.15).foregroundStyle(MMColor.textPrimary)
                        }
                        if let description {
                            Text(description).mmFont(.body, 15, lineHeight: 1.45).foregroundStyle(MMColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                    if let onClose {
                        MMIconButton("x", variant: .filled, size: 36, label: "Close", action: onClose)
                    }
                }
            }
            if Content.self != EmptyView.self {
                content.padding(.top, title == nil && onClose == nil ? 0 : 16)
            }
            if Actions.self != EmptyView.self {
                HStack(spacing: 10) { actions }.padding(.top, 20)
            }
        }
    }
}

private struct MMSheetHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Content-sized bottom sheet. Long forms scroll within the system's maximum
/// detent instead of forcing their title and actions outside the visible sheet.
private struct MMSheetModifier<SheetContent: View, Actions: View>: ViewModifier {
    @Binding var isPresented: Bool
    var title: String?
    var description: String?
    var sheetContent: () -> SheetContent
    var actions: () -> Actions

    @State private var height: CGFloat = 320

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            ScrollView {
                MMDialogBody(title: title, description: description, onClose: { isPresented = false }) {
                    sheetContent()
                } actions: {
                    actions()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 26)
                .padding(.bottom, 20)
                .background {
                    // Measure the full content, not the capped scroll viewport,
                    // so compact sheets keep their natural height.
                    GeometryReader { g in Color.clear.preference(key: MMSheetHeightKey.self, value: g.size.height) }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .onPreferenceChange(MMSheetHeightKey.self) { value in
                if value > 0 { height = value }
            }
            .presentationDetents([.height(height)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(MMRadius.xl)
            .presentationBackground(MMColor.white)
        }
    }
}

/// Centered modal: white, 28pt radius, float shadow, ink 48% overlay.
private struct MMModalModifier<Actions: View>: ViewModifier {
    @Binding var isPresented: Bool
    var title: String
    var description: String?
    var actions: () -> Actions

    func body(content: Content) -> some View {
        content.overlay {
            ZStack {
                if isPresented {
                    MMColor.surfaceOverlay
                        .ignoresSafeArea()
                        .onTapGesture { isPresented = false }
                        .transition(.opacity)
                    MMDialogBody(title: title, description: description, onClose: { isPresented = false }) {
                        EmptyView()
                    } actions: {
                        actions()
                    }
                    .padding(22)
                    .frame(maxWidth: 340)
                    .background(RoundedRectangle(cornerRadius: MMRadius.xl, style: .continuous).fill(MMColor.white).mmShadowFloat())
                    .padding(24)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
            .animation(MMMotion.bounce(MMMotion.base), value: isPresented)
        }
    }
}

extension View {
    func mmSheet<SheetContent: View, Actions: View>(
        isPresented: Binding<Bool>,
        title: String? = nil,
        description: String? = nil,
        @ViewBuilder content: @escaping () -> SheetContent,
        @ViewBuilder actions: @escaping () -> Actions
    ) -> some View {
        modifier(MMSheetModifier(isPresented: isPresented, title: title, description: description, sheetContent: content, actions: actions))
    }

    func mmSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        title: String? = nil,
        description: String? = nil,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        modifier(MMSheetModifier(isPresented: isPresented, title: title, description: description, sheetContent: content, actions: { EmptyView() }))
    }

    func mmModal<Actions: View>(
        isPresented: Binding<Bool>,
        title: String,
        description: String? = nil,
        @ViewBuilder actions: @escaping () -> Actions
    ) -> some View {
        modifier(MMModalModifier(isPresented: isPresented, title: title, description: description, actions: actions))
    }
}

// MARK: - Tooltip

/// Ink-900 bubble, radius 10, shown above (or below) its anchor.
private struct MMTooltipModifier: ViewModifier {
    var text: String
    var isPresented: Bool
    var above: Bool

    func body(content: Content) -> some View {
        content.overlay(alignment: above ? .top : .bottom) {
            Text(text)
                .mmFont(.body, 13, .semibold, lineHeight: 1.2)
                .foregroundStyle(MMColor.paper)
                .fixedSize()
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(MMColor.ink900))
                .alignmentGuide(above ? .top : .bottom) { d in above ? d[.bottom] + 8 : d[.top] - 8 }
                .opacity(isPresented ? 1 : 0)
                .offset(y: isPresented ? 0 : (above ? 4 : -4))
                .animation(MMMotion.easeOut(MMMotion.fast), value: isPresented)
                .allowsHitTesting(false)
        }
    }
}

extension View {
    func mmTooltip(_ text: String, isPresented: Bool, above: Bool = true) -> some View {
        modifier(MMTooltipModifier(text: text, isPresented: isPresented, above: above))
    }
}
