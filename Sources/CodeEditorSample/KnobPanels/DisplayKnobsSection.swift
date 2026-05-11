import CodeEditorPlugin
import SwiftUI

struct DisplayKnobsSection: View {
    @Binding var configuration: EditorConfiguration
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
                    value: $configuration.display.fontSize,
                    range: 9...32,
                    step: 1,
                    format: .number.precision(.fractionLength(0))
                )

                KnobSubsection(title: "Highlighting")
                ToggleRow(label: "isSyntaxHighlightingEnabled", value: $configuration.display.isSyntaxHighlightingEnabled)
                ToggleRow(label: "isLineNumbersEnabled", value: $configuration.display.isLineNumbersEnabled)
                ToggleRow(label: "areAnnotationsEnabled", value: $configuration.display.areAnnotationsEnabled)
                ToggleRow(label: "isSelectedLineHighlighted", value: $configuration.display.isSelectedLineHighlighted)
                ColorRow(label: "selectedLineHighlightColor", value: $configuration.display.selectedLineHighlightColor)
                ToggleRow(label: "areInvisibleCharactersVisible", value: $configuration.display.areInvisibleCharactersVisible)

                KnobSubsection(title: "Code Folding")
                ToggleRow(label: "isCodeFoldingEnabled", value: $configuration.display.isCodeFoldingEnabled)
                ToggleRow(label: "areFoldingControlsVisible", value: $configuration.display.areFoldingControlsVisible)
                StepperRow(
                    label: "minimumFoldableLines",
                    value: $configuration.display.minimumFoldableLines,
                    range: 1...100
                )

                KnobSubsection(title: "Minimap")
                ToggleRow(label: "isMinimapVisible", value: $configuration.display.isMinimapVisible)

                KnobSubsection(title: "Viewport")
                StepperRow(
                    label: "visibleLines",
                    value: $configuration.display.visibleLines,
                    range: 1...500,
                    step: 1
                )
            }
        }
        .padding(.horizontal, 12)
    }
}
