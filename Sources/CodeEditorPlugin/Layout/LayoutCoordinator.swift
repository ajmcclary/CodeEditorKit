import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - LayoutCoordinator

/// Coordinates layout operations to prevent recursive layout cycles
@MainActor
public final class LayoutCoordinator {
    deinit {}
    // MARK: - Properties
    
    private var isPerformingLayout = false
    private var pendingLayoutOperations: [() -> Void] = []
    private weak var view: PlatformView?
    
    // MARK: - Initialization
    
    public init(view: PlatformView? = nil) {
        self.view = view
    }
    
    // MARK: - Public Methods
    
    /// Perform a layout operation safely, preventing recursive calls
    public func performLayout(_ operation: @escaping () -> Void) {
        guard !isPerformingLayout else {
            // Queue the operation for later
            pendingLayoutOperations.append(operation)
            return
        }
        
        isPerformingLayout = true
        defer {
            isPerformingLayout = false
            processPendingOperations()
        }
        
        operation()
    }
    
    /// Perform layout with animation
    public func performAnimatedLayout(
        duration: TimeInterval = 0.25,
        options: AnimationOptions = .default,
        _ operation: @escaping () -> Void,
        completion: (@Sendable (Bool) -> Void)? = nil
    ) {
        performLayout {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                operation()
            }, completionHandler: {
                completion?(true)
            })
            #else
            UIView.animate(
                withDuration: duration,
                delay: 0,
                options: options.uiKitOptions,
                animations: operation,
                completion: completion
            )
            #endif
        }
    }
    
    /// Invalidate layout for the associated view
    public func invalidateLayout() {
        guard let view else { return }
        
        performLayout {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            view.needsLayout = true
            view.needsDisplay = true
            #else
            view.setNeedsLayout()
            view.setNeedsDisplay()
            #endif
        }
    }
    
    /// Check if currently performing layout
    public var isLayoutInProgress: Bool {
        isPerformingLayout
    }
    
    // MARK: - Private Methods
    
    private func processPendingOperations() {
        guard !pendingLayoutOperations.isEmpty else { return }
        
        let operations = pendingLayoutOperations
        pendingLayoutOperations.removeAll()
        
        // Process pending operations
        for operation in operations {
            performLayout(operation)
        }
    }
}

// MARK: - AnimationOptions

/// Cross-platform animation options
public struct AnimationOptions: OptionSet, Sendable {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let curveEaseIn = Self(rawValue: 1 << 0)
    public static let curveEaseOut = Self(rawValue: 1 << 1)
    public static let curveEaseInOut = Self(rawValue: 1 << 2)
    public static let curveLinear = Self(rawValue: 1 << 3)
    public static let allowUserInteraction = Self(rawValue: 1 << 4)
    
    public static let `default`: AnimationOptions = .curveEaseInOut
    
    #if canImport(UIKit)
    var uiKitOptions: UIView.AnimationOptions {
        var options: UIView.AnimationOptions = []
        
        if contains(.curveEaseIn) {
            options.insert(.curveEaseIn)
        }
        if contains(.curveEaseOut) {
            options.insert(.curveEaseOut)
        }
        if contains(.curveEaseInOut) {
            options.insert(.curveEaseInOut)
        }
        if contains(.curveLinear) {
            options.insert(.curveLinear)
        }
        if contains(.allowUserInteraction) {
            options.insert(.allowUserInteraction)
        }
        
        return options
    }
    #endif
}

// MARK: - LayoutContext

/// Context information for layout operations
public struct LayoutContext {
    public let bounds: CGRect
    public let safeAreaInsets: EdgeInsets
    public let configuration: EditorConfiguration
    public let isRTL: Bool
    
    #if canImport(UIKit)
    public typealias EdgeInsets = UIEdgeInsets
    #else
    public typealias EdgeInsets = NSEdgeInsets
    #endif
    
    public init(
        bounds: CGRect,
        safeAreaInsets: EdgeInsets = .zero,
        configuration: EditorConfiguration = .default,
        isRTL: Bool = false
    ) {
        self.bounds = bounds
        self.safeAreaInsets = safeAreaInsets
        self.configuration = configuration
        self.isRTL = isRTL
    }
    
    /// Available content bounds after accounting for safe area
    public var contentBounds: CGRect {
        CGRect(
            x: bounds.origin.x + safeAreaInsets.left,
            y: bounds.origin.y + safeAreaInsets.top,
            width: bounds.width - safeAreaInsets.left - safeAreaInsets.right,
            height: bounds.height - safeAreaInsets.top - safeAreaInsets.bottom
        )
    }
}

// MARK: - EdgeInsets Extension

#if canImport(UIKit)
extension UIEdgeInsets {
    static let zero = UIEdgeInsets.zero
}
#else
extension NSEdgeInsets {
    public static let zero = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
}
#endif
