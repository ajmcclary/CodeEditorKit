import CodeEditorPlugin
import SwiftUI

struct PerformanceKnobsSection: View {
    @Binding var configuration: EditorConfiguration
    @State private var expanded: Bool = false
    var expansion: KnobSectionExpansion = .toggleable

    var body: some View {
        KnobSection(
            title: "Performance",
            icon: "gauge.with.dots.needle.bottom.50percent",
            accentIndex: 3,
            expanded: $expanded,
            expansion: expansion
        ) {
            VStack(alignment: .leading, spacing: 0) {
                limitsSection
                strategySection
                debounceSection
            }
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var limitsSection: some View {
        KnobSubsection(title: "Limits")
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
    private var strategySection: some View {
        KnobSubsection(title: "Strategy")
        ToggleRow(
            label: "useHardwareAcceleration",
            value: $configuration.performance.useHardwareAcceleration
        )
        ToggleRow(label: "smoothScrolling", value: $configuration.performance.smoothScrolling)
        ToggleRow(
            label: "animateCodeFolding (perf)",
            value: $configuration.performance.animateCodeFolding
        )
        PickerRow(
            label: "renderingUpdateStrategy",
            value: $configuration.performance.renderingUpdateStrategy,
            cases: [.adaptive, .immediate, .batched]
        ) {
            String(describing: $0).capitalized
        }
    }

    @ViewBuilder
    private var debounceSection: some View {
        KnobSubsection(title: "Debounce")
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
