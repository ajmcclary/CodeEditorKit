#if canImport(AppKit)
import Foundation
import Observation

/// Holds the live state of the hover popover. Owned by the
/// `LSPSampleCoordinator`; `WindowBody` binds its `.popover(item:)` to
/// `displayed`. Setting `displayed` to `nil` dismisses the popover.
@MainActor
@Observable
final class HoverSession {
    struct Display: Identifiable, Equatable {
        let id = UUID()
        let markdown: String
    }

    var displayed: Display?

    func show(markdown: String) {
        displayed = Display(markdown: markdown)
    }

    func dismiss() {
        displayed = nil
    }
}
#endif
