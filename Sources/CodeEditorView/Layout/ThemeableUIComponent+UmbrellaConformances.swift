// Empty-extension conformance declarations for umbrella-resident view
// types (GutterView, AppKitMinimapView, UIKitMinimapView). The protocol
// `ThemeableUIComponent` is defined in CodeEditorLayout's
// BaseUIComponents.swift; the carry-set conformances live in
// Sources/CodeEditorLayout/ThemeableUIComponent+LayoutConformances.swift.
// Split during §6.2.11 (CodeEditorLayout extraction).

import CodeEditorLayout
import Foundation

extension GutterView: ThemeableUIComponent {}

#if canImport(AppKit)
extension AppKitMinimapView: ThemeableUIComponent {}
#elseif canImport(UIKit)
extension UIKitMinimapView: ThemeableUIComponent {}
#endif
