import CodeEditorPlugin
import SwiftUI

struct PerformanceKnobsSection: View {
    @Binding var configuration: EditorConfiguration
    @State private var expanded: Bool = false

    var body: some View {
        DisclosureGroup("Performance", isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                limitRows
                strategyRows
                debounceRows
            }
            .padding(.vertical, 4)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var limitRows: some View {
        StepperRow(
            label: "maxSyntaxHighlightingLength",
            value: $configuration.performance.maxSyntaxHighlightingLength,
            range: 1_024...10_485_760,
            step: 1_024
        )
        StepperRow(
            label: "maxVisibleLines",
            value: $configuration.performance.maxVisibleLines,
            range: 1...100_000,
            step: 100
        )
        StepperRow(
            label: "maxFileSize",
            value: $configuration.performance.maxFileSize,
            range: 0...100_000_000,
            step: 1_024
        )
        StepperRow(
            label: "maxEventsPerSecond",
            value: $configuration.performance.maxEventsPerSecond,
            range: 1...240
        )
    }

    @ViewBuilder
    private var strategyRows: some View {
        ToggleRow(
            label: "useHardwareAcceleration",
            value: $configuration.performance.useHardwareAcceleration
        )
        ToggleRow(
            label: "smoothScrolling",
            value: $configuration.performance.smoothScrolling
        )
        ToggleRow(
            label: "animateCodeFolding (perf)",
            value: $configuration.performance.animateCodeFolding
        )
        PickerRow(
            label: "renderingUpdateStrategy",
            value: $configuration.performance.renderingUpdateStrategy,
            cases: [.adaptive, .immediate, .batched]
        ) {
            String(describing: $0)
        }
    }

    @ViewBuilder
    private var debounceRows: some View {
        DurationRow(
            label: "highlightingDebounceInterval",
            value: $configuration.performance.highlightingDebounceInterval,
            rangeMS: 0...1_000
        )
        DurationRow(
            label: "textChangeDebounceInterval",
            value: $configuration.performance.textChangeDebounceInterval,
            rangeMS: 0...1_000
        )
    }
}
