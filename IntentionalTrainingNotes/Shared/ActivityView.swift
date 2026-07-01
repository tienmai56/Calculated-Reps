import SwiftUI
import UIKit

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum ShareSnapshot {
    /// Renders a SwiftUI view to a UIImage (iOS 13-safe; no ImageRenderer).
    static func image<V: View>(of view: V, width: CGFloat) -> UIImage {
        let controller = UIHostingController(rootView: view.frame(width: width))
        let target = controller.view
        target?.backgroundColor = .clear
        let fitting = target?.systemLayoutSizeFitting(
            CGSize(width: width, height: 0),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ) ?? CGSize(width: width, height: 480)
        let size = CGSize(width: width, height: max(fitting.height, 200))
        target?.frame = CGRect(origin: .zero, size: size)

        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }), let target = target {
            window.addSubview(target)
            target.setNeedsLayout()
            target.layoutIfNeeded()
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { _ in
                target.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
            }
            target.removeFromSuperview()
            return image
        }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(red: 240/255, green: 237/255, blue: 235/255, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
