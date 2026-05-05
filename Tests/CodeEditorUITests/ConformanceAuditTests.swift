import CodeEditorUI
import Foundation
import SwiftUI
import Testing

/// Compile-time conformance asserts. If any chrome primitive loses
/// `View`, `ViewModifier`, `Sendable`, `Hashable`, or its declared style
/// protocol conformance, this file stops compiling — surfacing the
/// regression before any runtime assertion ever runs.
@Suite("CodeEditorUI conformance audit")
struct ConformanceAuditTests {
    private static func requireView<V: View>(_ type: V.Type) {
        _ = String(describing: type)
    }

    private static func requireViewModifier<M: ViewModifier>(_ type: M.Type) {
        _ = String(describing: type)
    }

    private static func requireSendable<T: Sendable>(_ type: T.Type) {
        _ = String(describing: type)
    }

    private static func requireValueModel<T>(_ type: T.Type)
    where T: Hashable & Sendable {
        _ = String(describing: type)
    }

    private static func requireIdentifiableValueModel<T>(_ type: T.Type)
    where T: Hashable & Identifiable & Sendable {
        _ = String(describing: type)
    }

    private static func requireTabStripStyle<S: EditorTabStripStyle>(_ type: S.Type) {
        _ = String(describing: type)
    }

    private static func requireCommandPaletteStyle<S: EditorCommandPaletteStyle>(_ type: S.Type) {
        _ = String(describing: type)
    }

    @Test("public chrome views conform to View")
    func auditChromeViews() {
        Self.requireView(EditorBreadcrumbView.self)
        Self.requireView(EditorStatusBar<EmptyView>.self)
        Self.requireView(EditorTab.self)
        Self.requireView(EditorTabStrip.self)
        Self.requireView(EditorCommandPalette.self)
        Self.requireView(EditorCommandPaletteRow.self)
        #if canImport(AppKit)
        Self.requireView(EditorTrafficLights.self)
        Self.requireView(EditorTitleBar<EmptyView>.self)
        Self.requireView(EditorSidebarShell<EmptyView, EmptyView, EmptyView>.self)
        #endif
    }

    @Test("PlatformGlassSurface conforms to ViewModifier")
    func auditViewModifiers() {
        Self.requireViewModifier(PlatformGlassSurface.self)
    }

    @Test("public value models carry the expected conformances")
    func auditValueModels() {
        Self.requireIdentifiableValueModel(CommandPaletteItem.self)
        Self.requireValueModel(CommandPaletteItem.Kind.self)
        Self.requireValueModel(PlatformGlassSurface.Role.self)
        #if canImport(AppKit)
        Self.requireSendable(TrafficLightsConfiguration.self)
        #endif
    }

    @Test("style protocol implementers conform to their style protocol")
    func auditStyleConformances() {
        Self.requireTabStripStyle(DefaultEditorTabStripStyle.self)
        Self.requireTabStripStyle(CompactEditorTabStripStyle.self)
        Self.requireCommandPaletteStyle(DefaultEditorCommandPaletteStyle.self)
    }
}
