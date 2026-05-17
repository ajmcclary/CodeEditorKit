import CodeEditorPlatform
import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Gates hardware-accelerated (layer-backed) rendering on a platform view.
///
/// AppKit: sets `wantsLayer = enabled`. UIKit: no-op — `UIView` instances are
/// always layer-backed by definition. Returns the effective value (the input
/// on AppKit, `true` on UIKit). Callers use the return value to record what
/// was actually applied (see `EditorState.hardwareAccelerationActive`).
@MainActor
enum HardwareAcceleration {
    @discardableResult
    static func apply(_ enabled: Bool, to view: PlatformView) -> Bool {
        #if canImport(AppKit)
        view.wantsLayer = enabled
        return enabled
        #else
        _ = (enabled, view)
        return true
        #endif
    }
}
