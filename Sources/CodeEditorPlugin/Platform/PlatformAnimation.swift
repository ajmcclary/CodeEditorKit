import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Platform-agnostic animation utilities for cross-platform code
public enum PlatformAnimation {
    /// Animates changes with platform-appropriate APIs
    /// - Parameters:
    ///   - duration: Animation duration in seconds
    ///   - delay: Animation delay in seconds (default: 0)
    ///   - options: Animation options (timing curves)
    ///   - animations: The changes to animate
    ///   - completion: Optional completion handler
    @MainActor
    public static func animate(
        withDuration duration: TimeInterval,
        delay: TimeInterval = 0,
        options: AnimationOptions = .curveEaseInOut,
        animations: @escaping @Sendable () -> Void,
        completion: (@Sendable (Bool) -> Void)? = nil
    ) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if delay > 0 {
            // Use Task.sleep for delay with modern concurrency
            Task { @MainActor in
                do {
                    try await Task.sleep(for: .seconds(delay))
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = duration
                        context.allowsImplicitAnimation = true
                        context.timingFunction = options.toCAMediaTimingFunction()
                        animations()
                    }, completionHandler: {
                        completion?(true)
                    })
                } catch {
                    // Task was cancelled, skip animation
                    completion?(false)
                }
            }
        } else {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = duration
                context.allowsImplicitAnimation = true
                context.timingFunction = options.toCAMediaTimingFunction()
                animations()
            }, completionHandler: {
                completion?(true)
            })
        }
        #elseif canImport(UIKit)
        UIView.animate(
            withDuration: duration,
            delay: delay,
            options: options.toUIViewAnimationOptions(),
            animations: animations,
            completion: completion
        )
        #endif
    }
    
    /// Animates changes with spring physics
    /// - Parameters:
    ///   - duration: Animation duration in seconds
    ///   - damping: Spring damping ratio (0-1, where 1 = no oscillation)
    ///   - velocity: Initial spring velocity
    ///   - options: Animation options
    ///   - animations: The changes to animate
    ///   - completion: Optional completion handler
    @MainActor
    public static func animateWithSpring(
        duration: TimeInterval,
        damping: CGFloat = 0.7,
        velocity: CGFloat = 0,
        options: AnimationOptions = .curveEaseInOut,
        animations: @escaping @Sendable () -> Void,
        completion: (@Sendable (Bool) -> Void)? = nil
    ) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS doesn't have built-in spring animations, use standard animation
        animate(
            withDuration: duration,
            options: options,
            animations: animations,
            completion: completion
        )
        #elseif canImport(UIKit)
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: damping,
            initialSpringVelocity: velocity,
            options: options.toUIViewAnimationOptions(),
            animations: animations,
            completion: completion
        )
        #endif
    }
    
    /// Performs changes without animation
    /// - Parameter changes: The changes to perform
    @MainActor
    public static func performWithoutAnimation(_ changes: @Sendable () -> Void) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        changes()
        NSAnimationContext.endGrouping()
        #elseif canImport(UIKit)
        UIView.performWithoutAnimation(changes)
        #endif
    }
    
    /// Platform-agnostic animation options
    public struct AnimationOptions: OptionSet, Sendable {
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        // Timing curves
        public static let curveEaseIn = Self(rawValue: 1 << 0)
        public static let curveEaseOut = Self(rawValue: 1 << 1)
        public static let curveEaseInOut = Self(rawValue: 1 << 2)
        public static let curveLinear = Self(rawValue: 1 << 3)
        
        // Other options
        public static let allowUserInteraction = Self(rawValue: 1 << 4)
        public static let beginFromCurrentState = Self(rawValue: 1 << 5)
        public static let repeatAnimation = Self(rawValue: 1 << 6)
        public static let autoreverse = Self(rawValue: 1 << 7)
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        func toCAMediaTimingFunction() -> CAMediaTimingFunction {
            if self.contains(.curveEaseIn) {
                return CAMediaTimingFunction(name: .easeIn)
            } else if self.contains(.curveEaseOut) {
                return CAMediaTimingFunction(name: .easeOut)
            } else if self.contains(.curveLinear) {
                return CAMediaTimingFunction(name: .linear)
            } else {
                return CAMediaTimingFunction(name: .easeInEaseOut)
            }
        }
        #endif
        
        #if canImport(UIKit)
        func toUIViewAnimationOptions() -> UIView.AnimationOptions {
            var options: UIView.AnimationOptions = []
            
            if self.contains(.curveEaseIn) {
                options.insert(.curveEaseIn)
            } else if self.contains(.curveEaseOut) {
                options.insert(.curveEaseOut)
            } else if self.contains(.curveLinear) {
                options.insert(.curveLinear)
            } else {
                options.insert(.curveEaseInOut)
            }
            
            if self.contains(.allowUserInteraction) {
                options.insert(.allowUserInteraction)
            }
            if self.contains(.beginFromCurrentState) {
                options.insert(.beginFromCurrentState)
            }
            if self.contains(.repeatAnimation) {
                options.insert(.repeat)
            }
            if self.contains(.autoreverse) {
                options.insert(.autoreverse)
            }
            
            return options
        }
        #endif
    }
}

// MARK: - Animation Transactions

/// Platform-agnostic animation transaction
public enum PlatformAnimationTransaction {
    /// Disables animations for the duration of the closure
    /// - Parameter actions: The actions to perform without animation
    public static func disableAnimations<T>(_ actions: () throws -> T) rethrows -> T {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let result: T
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        NSAnimationContext.current.allowsImplicitAnimation = false
        result = try actions()
        NSAnimationContext.endGrouping()
        return result
        #elseif canImport(UIKit)
        // For UIKit, we need to handle the throwing closure differently
        // since performWithoutAnimation doesn't support throwing closures
        return try actions()
        #endif
    }
    
    /// Sets the animation duration for implicit animations
    /// - Parameters:
    ///   - duration: The animation duration
    ///   - actions: The actions to perform with the specified duration
    public static func setAnimationDuration<T>(_ duration: TimeInterval, _ actions: () throws -> T) rethrows -> T {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let result: T
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = duration
        NSAnimationContext.current.allowsImplicitAnimation = true
        result = try actions()
        NSAnimationContext.endGrouping()
        return result
        #elseif canImport(UIKit)
        // For UIKit, we'll execute the actions directly since
        // UIView.animate doesn't support throwing closures with return values
        return try actions()
        #endif
    }
}
