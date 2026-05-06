import Foundation

#if canImport(UIKit)
import UIKit

/// UIKit screen metrics resolved through scene or view context.
@MainActor
enum UIKitScreenMetrics {
    private static var currentSceneScreen: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .screen
    }

    static var scale: CGFloat {
        currentSceneScreen?.scale ?? UITraitCollection.current.displayScale
    }

    static var bounds: CGRect {
        currentSceneScreen?.bounds ?? CGRect(origin: .zero, size: CGSize(width: 390.0, height: 844.0))
    }

    static var maximumFramesPerSecond: Int {
        currentSceneScreen?.maximumFramesPerSecond ?? 60
    }

    static func scale(for view: UIView) -> CGFloat {
        view.window?.windowScene?.screen.scale ?? view.traitCollection.displayScale
    }

    static func bounds(for view: UIView) -> CGRect {
        view.window?.windowScene?.screen.bounds ?? bounds
    }
}
#endif
