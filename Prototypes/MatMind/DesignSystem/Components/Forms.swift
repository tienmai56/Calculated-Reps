import SwiftUI

// MARK: - Label

/// Field label: display 14 bold. Required fields carry a danger-red asterisk.
struct MMFieldLabel: View {
    let text: String
    var required = false

    init(_ text: String, required: Bool = false) {
        self.text = text
        self.required = required
    }

    var body: some View {
        HStack(spacing: 3) {
            Text(text).foregroundStyle(MMColor.textPrimary)
            if required { Text("*").foregroundStyle(MMColor.danger500).accessibilityHidden(true) }
        }
        .mmFont(.display, 14, .bold, tracking: 0, lineHeight: 1.2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(required ? "\(text), required" : text)
    }
}

// MARK: - Input

/// Min height 50, radius 14, 1.5pt border; focus = coral border + 4pt accent-tint ring.
struct MMTextField: View {
    var label: String?
    var required = false
    var placeholder: String = ""
    @Binding var text: String
    var hint: String?
    var error: String?
    var iconLeft: String?
    var multiline = false
    var rows = 3
    var autoFocus = false
    var onSubmit: (() -> Void)?
    var onFocusChange: ((Bool) -> Void)?

    @FocusState private var focused: Bool

    init(
        label: String? = nil,
        required: Bool = false,
        placeholder: String = "",
        text: Binding<String>,
        hint: String? = nil,
        error: String? = nil,
        iconLeft: String? = nil,
        multiline: Bool = false,
        rows: Int = 3,
        autoFocus: Bool = false,
        onSubmit: (() -> Void)? = nil,
        onFocusChange: ((Bool) -> Void)? = nil
    ) {
        self.label = label
        self.required = required
        self.placeholder = placeholder
        self._text = text
        self.hint = hint
        self.error = error
        self.iconLeft = iconLeft
        self.multiline = multiline
        self.rows = rows
        self.autoFocus = autoFocus
        self.onSubmit = onSubmit
        self.onFocusChange = onFocusChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label { MMFieldLabel(label, required: required) }
            HStack(alignment: multiline ? .top : .center, spacing: 10) {
                if let iconLeft {
                    MMIcon(iconLeft, size: 18, color: MMColor.textTertiary).padding(.top, multiline ? 2 : 0)
                }
                field
                    .focused($focused)
                    .font(MMFont.body(16))
                    .foregroundStyle(MMColor.textPrimary)
                    .tint(MMColor.accent)
                    .onSubmit { onSubmit?() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, multiline ? 14 : 0)
            .frame(minHeight: 50)
            .background {
                let shape = RoundedRectangle(cornerRadius: MMRadius.md, style: .continuous)
                ZStack {
                    RoundedRectangle(cornerRadius: MMRadius.md + 4, style: .continuous)
                        .fill(MMColor.accentTint)
                        .padding(-4)
                        .opacity(focused && error == nil ? 1 : 0)
                    shape.fill(MMColor.surfaceInput)
                    shape.strokeBorder(borderColor, lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
            .animation(MMMotion.easeOut(MMMotion.fast), value: focused)
            if let message = error ?? hint {
                Text(message)
                    .mmFont(.body, 13, .medium, lineHeight: 1.3)
                    .foregroundStyle(error == nil ? MMColor.textTertiary : MMColor.danger500)
            }
        }
        .task {
            guard autoFocus else { return }
            try? await Task.sleep(for: .seconds(0.45))
            focused = true
        }
        .onChange(of: focused) { _, active in onFocusChange?(active) }
    }

    @ViewBuilder
    private var field: some View {
        if multiline {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(rows, reservesSpace: true)
        } else {
            TextField(placeholder, text: $text)
        }
    }

    private var borderColor: Color {
        if error != nil { return MMColor.danger500 }
        return focused ? MMColor.borderFocus : MMColor.borderDefault
    }
}

// MARK: - Select

/// 50pt, radius 14. A native menu dressed as an input.
struct MMSelect: View {
    var label: String?
    var options: [String]
    @Binding var selection: String
    var display: (String) -> String = { $0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label {
                Text(label).mmFont(.display, 14, .bold, tracking: 0, lineHeight: 1.2).foregroundStyle(MMColor.textPrimary)
            }
            Menu {
                Picker(label ?? "", selection: $selection) {
                    ForEach(options, id: \.self) { Text(display($0)).tag($0) }
                }
            } label: {
                HStack {
                    Text(display(selection)).mmFont(.body, 16, .medium, lineHeight: 1)
                    Spacer(minLength: 8)
                    MMIcon("chevron-down", size: 18, color: MMColor.textTertiary)
                }
                .foregroundStyle(MMColor.textPrimary)
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: MMRadius.md, style: .continuous).fill(MMColor.surfaceInput))
                .mmOutline(radius: MMRadius.md)
            }
        }
    }
}

// MARK: - Checkbox

/// 24pt, radius 8. Checked = coral with a 2pt pressable edge.
struct MMCheckbox: View {
    @Binding var isOn: Bool
    var label: String?
    var description: String?

    var body: some View {
        Button {
            withAnimation(MMMotion.bounce(MMMotion.fast)) { isOn.toggle() }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                box
                if label != nil || description != nil {
                    MMControlText(label: label, description: description).padding(.top, 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var box: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return ZStack {
            if isOn {
                shape.fill(MMColor.accentShade).offset(y: 2)
                shape.fill(MMColor.accent)
                MMIcon("check", size: 16, weight: .bold, color: .white)
            } else {
                shape.fill(MMColor.white)
                shape.strokeBorder(MMColor.controlBorder, lineWidth: 2)
            }
        }
        .frame(width: 24, height: 24)
        .scaleEffect(isOn ? 1 : 0.96)
    }
}

// MARK: - Radio

struct MMRadio: View {
    var isSelected: Bool
    var label: String?
    var description: String?
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(MMMotion.bounce(MMMotion.base)) { action() }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(MMColor.white)
                    Circle().strokeBorder(isSelected ? MMColor.accent : MMColor.controlBorder, lineWidth: 2)
                    Circle().fill(MMColor.accent).frame(width: 12, height: 12).scaleEffect(isSelected ? 1 : 0.001)
                }
                .frame(width: 24, height: 24)
                if label != nil || description != nil {
                    MMControlText(label: label, description: description).padding(.top, 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Switch

/// Track 52×32, knob 26; the knob moves with a bounce.
struct MMSwitch: View {
    @Binding var isOn: Bool
    var label: String?
    var description: String?

    var body: some View {
        if label != nil || description != nil {
            Button { toggle() } label: {
                HStack(spacing: 16) {
                    MMControlText(label: label, description: description)
                    Spacer(minLength: 0)
                    track
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isOn ? "On" : "Off")
        } else {
            Button { toggle() } label: { track }
                .buttonStyle(.plain)
                .accessibilityValue(isOn ? "On" : "Off")
        }
    }

    private func toggle() {
        withAnimation(MMMotion.bounce(MMMotion.base)) { isOn.toggle() }
    }

    private var track: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule().fill(isOn ? MMColor.accent : MMColor.controlOff)
            Circle().fill(Color.white)
                .frame(width: 26, height: 26)
                .shadow(color: MMColor.ink900.opacity(0.18), radius: 2, x: 0, y: 2)
                .padding(3)
        }
        .frame(width: 52, height: 32)
    }
}

/// Label + description pair shared by checkbox, radio and switch rows.
struct MMControlText: View {
    var label: String?
    var description: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let label {
                Text(label).mmFont(.body, 16, .medium, lineHeight: 1.3).foregroundStyle(MMColor.textPrimary)
            }
            if let description {
                Text(description).mmFont(.body, 13, lineHeight: 1.4).foregroundStyle(MMColor.textTertiary)
            }
        }
        .multilineTextAlignment(.leading)
    }
}
