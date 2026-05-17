import CodeEditorPlatform
import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// A single style run for minimap rendering — a character range with a color.
///
/// Fields are `let` so the value is genuinely immutable after init —
/// required for the `@unchecked Sendable` conformance over a
/// `PlatformColor` reference field to be sound.
public struct MinimapStyleRun: Equatable, @unchecked Sendable {
    public let range: NSRange
    public let color: PlatformColor

    public init(range: NSRange, color: PlatformColor) {
        self.range = range
        self.color = color
    }
}

/// Provides style runs to the minimap for syntax-colored structure rendering.
@MainActor
public protocol MinimapStyleDataSource: AnyObject {
    /// Return style runs for the given character range.
    func styleRuns(in range: NSRange) -> [MinimapStyleRun]
}

// MARK: - No-op data source (default)

/// Returns no style runs — the minimap falls back to raw text rendering.
@MainActor
internal final class NoOpMinimapStyleDataSource: MinimapStyleDataSource {
    func styleRuns(in _: NSRange) -> [MinimapStyleRun] { [] }
}

// MARK: - Styled data source (backed by StyledRangeContainer)

/// Converts `StyledRangeContainer` merged runs into minimap style runs,
/// mapping capture names to platform colors via the theme's token lookup.
@MainActor
internal final class StyledMinimapStyleDataSource: MinimapStyleDataSource {
    private weak var container: StyledRangeContainer?
    private let colorLookup: (String) -> PlatformColor

    init(
        container: StyledRangeContainer,
        colorLookup: @escaping (String) -> PlatformColor = { _ in PlatformColors.label }
    ) {
        self.container = container
        self.colorLookup = colorLookup
    }

    func styleRuns(in range: NSRange) -> [MinimapStyleRun] {
        guard let container else { return [] }
        let merged = container.mergedRuns(in: range)

        var result: [MinimapStyleRun] = []
        var cursor = range.location

        for run in merged {
            defer { cursor += run.length }
            guard let value = run.value, let capture = value.capture else { continue }
            let color = colorLookup(capture)
            result.append(MinimapStyleRun(
                range: NSRange(location: cursor, length: run.length),
                color: color
            ))
        }
        return result
    }
}
