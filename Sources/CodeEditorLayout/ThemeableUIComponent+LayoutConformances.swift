// Empty-extension conformance declarations for CodeEditorLayout-resident
// view types (LineHighlightView, InsertionPointView) and CodeEditorAnnotations
// view types (AnnotationsContentView, AnnotationView). The protocol's shape
// is defined in BaseUIComponents.swift in this target. Conformances for
// umbrella-resident view types (GutterView, AppKitMinimapView,
// UIKitMinimapView) live in
// Sources/CodeEditorPlugin/Core/Layout/ThemeableUIComponent+UmbrellaConformances.swift.
// Split during §6.2.11 (CodeEditorLayout extraction).

import CodeEditorAnnotations
import Foundation

extension LineHighlightView: ThemeableUIComponent {}

extension InsertionPointView: ThemeableUIComponent {}

extension AnnotationsContentView: ThemeableUIComponent {}

extension AnnotationView: ThemeableUIComponent {}
