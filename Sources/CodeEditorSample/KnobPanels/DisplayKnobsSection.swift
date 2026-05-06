import CodeEditorPlugin
import SwiftUI

struct DisplayKnobsSection: View {
    @Binding var configuration: EditorConfiguration
    @State private var expanded: Bool = true

    var body: some View {
        DisclosureGroup("Display", isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                CGFloatSliderRow(
                    label: "fontSize",
                    value: $configuration.display.fontSize,
                    range: 9...32,
                    step: 1,
                    format: .number.precision(.fractionLength(0))
                )
                ToggleRow(label: "isSyntaxHighlightingEnabled", value: $configuration.display.isSyntaxHighlightingEnabled)
                ToggleRow(label: "isLineNumbersEnabled", value: $configuration.display.isLineNumbersEnabled)
                ToggleRow(label: "areAnnotationsEnabled", value: $configuration.display.areAnnotationsEnabled)
                ToggleRow(label: "isSelectedLineHighlighted", value: $configuration.display.isSelectedLineHighlighted)
                ColorRow(label: "selectedLineHighlightColor", value: $configuration.display.selectedLineHighlightColor)
                ToggleRow(label: "areInvisibleCharactersVisible", value: $configuration.display.areInvisibleCharactersVisible)
                ToggleRow(label: "isCodeFoldingEnabled", value: $configuration.display.isCodeFoldingEnabled)
                ToggleRow(label: "areFoldingControlsVisible", value: $configuration.display.areFoldingControlsVisible)
                StepperRow(
                    label: "minimumFoldableLines",
                    value: $configuration.display.minimumFoldableLines,
                    range: 1...100
                )
                ToggleRow(label: "isMinimapVisible", value: $configuration.display.isMinimapVisible)
            }
            .padding(.vertical, 4)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 12)
    }
}
