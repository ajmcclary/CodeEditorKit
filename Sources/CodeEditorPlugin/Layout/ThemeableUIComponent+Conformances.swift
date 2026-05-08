// Empty-extension conformance declarations for the views that already
// expose `appliedTheme` + `apply(theme:)`. Keeping the conformances in a
// dedicated file lets each view's primary file stay focused on its own
// concerns; the shape of the protocol is defined in BaseUIComponents.swift.

import Foundation

extension GutterView: ThemeableUIComponent {}

extension LineHighlightView: ThemeableUIComponent {}

extension InsertionPointView: ThemeableUIComponent {}

extension AnnotationsContentView: ThemeableUIComponent {}

extension AnnotationView: ThemeableUIComponent {}

#if canImport(AppKit)
extension AppKitMinimapView: ThemeableUIComponent {}
#elseif canImport(UIKit)
extension UIKitMinimapView: ThemeableUIComponent {}
#endif
