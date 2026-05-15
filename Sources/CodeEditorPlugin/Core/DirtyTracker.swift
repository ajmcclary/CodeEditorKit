import Foundation

/// View-local dirty tracker. The framework's coordinator owns one instance per
/// editor and asks it after every text-mutation sync whether the current
/// content differs from the baseline.
///
/// Baseline is set on initial text install (`setupContainer`), on host-driven
/// binding swap (`updateContainer` with `text != storage`), and on explicit
/// `markClean(currentText:)`. Returns `false` when no baseline has been set
/// (pre-mount initial state).
struct DirtyTracker: Sendable {
    private var baseline: String?

    mutating func setBaseline(_ text: String) {
        baseline = text
    }

    func isDirty(currentText: String) -> Bool {
        guard let baseline else { return false }
        return baseline != currentText
    }

    mutating func markClean(currentText: String) {
        baseline = currentText
    }
}
