// Empty-extension conformance declarations for CodeEditorLayout-resident
// view types (LineHighlightView, InsertionPointView) and CodeEditorAnnotations
// view types (AnnotationsContentView, AnnotationView). The protocol's shape
// is defined in BaseUIComponents.swift in this target. Conformances for
// umbrella-resident view types (GutterView, AppKitMinimapView,
// UIKitMinimapView) live in
// ThemeableUIComponent+UmbrellaConformances.swift, which was then at
// Sources/CodeEditorPlugin/Core/Layout/ (the umbrella's pre-§6.2.12 layout,
// before the package was renamed to CodeEditorKit).
// Split during §6.2.11 (CodeEditorLayout extraction).

import CodeEditorAnnotations
import Foundation

extension LineHighlightView: ThemeableUIComponent {}

extension InsertionPointView: ThemeableUIComponent {}

extension AnnotationsContentView: ThemeableUIComponent {}

extension AnnotationView: ThemeableUIComponent {}
