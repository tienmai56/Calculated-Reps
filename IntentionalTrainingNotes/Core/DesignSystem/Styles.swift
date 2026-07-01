import SwiftUI
import UIKit

// MARK: - Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(AppColors.indigo.opacity(configuration.isPressed ? 0.8 : 1))
            .cornerRadius(24)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(AppColors.indigo)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(AppColors.background.opacity(configuration.isPressed ? 0.7 : 1))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color(.systemGray3), lineWidth: 1))
            .cornerRadius(24)
    }
}

struct SmallPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isEnabled ? AppColors.indigo : Color(.systemGray3))
            .cornerRadius(20)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct SmallSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.medium))
            .foregroundColor(AppColors.secondaryLabel)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

struct TrainingTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(11)
            .background(AppColors.background)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray3), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }
}

extension View {
    func cardBackground(stronger: Bool = false) -> some View {
        self
            .background(AppColors.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
    }

    func dashedCircle() -> some View {
        self
            .background(Circle().fill(Color(.systemGray6)))
    }
}

extension Text {
    func fieldLabel() -> some View {
        font(.caption)
            .fontWeight(.medium)
            .foregroundColor(AppColors.label)
            .uppercaseTracking()
    }

    func uppercaseTracking() -> some View {
        tracking(0.8)
    }
}
