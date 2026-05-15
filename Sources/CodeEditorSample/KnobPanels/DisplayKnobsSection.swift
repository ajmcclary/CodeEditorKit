import CodeEditorPlugin
import SwiftUI

struct DisplayKnobsSection: View {
    @Bindable var configuration: ConfigurationModel
    @State private var expanded: Bool = true
    var expansion: KnobSectionExpansion = .toggleable

    var body: some View {
        KnobSection(
            title: "Display",
            icon: "square.grid.2x2",
            accentIndex: 0,
            expanded: $expanded,
            expansion: expansion
        ) {
            VStack(alignment: .leading, spacing: 0) {
                KnobSubsection(title: "Typography")
                CGFloatSliderRow(
                    label: "fontSize",
                    value: $configuration.current.display.fontSize,
                    range: 9...32,
                    step: 1,
                    format: .number.precision(.fractionLength(0))
                )

                KnobSubsection(title: "Highlighting")
                ToggleRow(label: "isSyntaxHighlightingEnabled", value: $configuration.current.display.isSyntaxHighlightingEnabled)
                ToggleRow(label: "isLineNumbersEnabled", value: $configuration.current.display.isLineNumbersEnabled)
                ToggleRow(label: "areAnnotationsEnabled", value: $configuration.current.display.areAnnotationsEnabled)
                ToggleRow(label: "isSelectedLineHighlighted", value: $configuration.current.display.isSelectedLineHighlighted)
                ColorRow(label: "selectedLineHighlightColor", value: $configuration.current.display.selectedLineHighlightColor)
                ToggleRow(label: "areInvisibleCharactersVisible", value: $configuration.current.display.areInvisibleCharactersVisible)
                ToggleRow(label: "useRangeStoreHighlighting", value: $configuration.current.display.useRangeStoreHighlighting)

                KnobSubsection(title: "Code Folding")
                ToggleRow(label: "isCodeFoldingEnabled", value: $configuration.current.display.isCodeFoldingEnabled)
                ToggleRow(label: "areFoldingControlsVisible", value: $configuration.current.display.areFoldingControlsVisible)
                StepperRow(
                    label: "minimumFoldableLines",
                    value: $configuration.current.display.minimumFoldableLines,
                    range: 1...100
                )

                KnobSubsection(title: "Minimap")
                ToggleRow(label: "isMinimapVisible", value: $configuration.current.display.isMinimapVisible)

                KnobSubsection(title: "Viewport")
                StepperRow(
                    label: "visibleLines",
                    value: $configuration.current.display.visibleLines,
                    range: 1...500,
                    step: 1
                )
            }
        }
        .padding(.horizontal, 12)
    }
}
