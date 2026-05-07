import CodeEditorPlugin
import SwiftUI

struct DisplayKnobsSection: View {
    @Environment(\.codeEditorTheme) private var theme
    @Binding var configuration: EditorConfiguration
    @State private var expanded: Bool = true

    var body: some View {
        DisclosureGroup(
            isExpanded: $expanded,
            content: {
            VStack(alignment: .leading, spacing: 0) {
                CGFloatSliderRow(
                    label: "fontSize",
                    value: $configuration.display.fontSize,
                    range: 9...32,
                    step: 1,
                    format: .number.precision(.fractionLength(0))
                )
                KnobRowSeparator()
                ToggleRow(label: "isSyntaxHighlightingEnabled", value: $configuration.display.isSyntaxHighlightingEnabled)
                KnobRowSeparator()
                ToggleRow(label: "isLineNumbersEnabled", value: $configuration.display.isLineNumbersEnabled)
                KnobRowSeparator()
                ToggleRow(label: "areAnnotationsEnabled", value: $configuration.display.areAnnotationsEnabled)
                KnobRowSeparator()
                ToggleRow(label: "isSelectedLineHighlighted", value: $configuration.display.isSelectedLineHighlighted)
                KnobRowSeparator()
                ColorRow(label: "selectedLineHighlightColor", value: $configuration.display.selectedLineHighlightColor)
                KnobRowSeparator()
                ToggleRow(label: "areInvisibleCharactersVisible", value: $configuration.display.areInvisibleCharactersVisible)
                KnobRowSeparator()
                ToggleRow(label: "isCodeFoldingEnabled", value: $configuration.display.isCodeFoldingEnabled)
                KnobRowSeparator()
                ToggleRow(label: "areFoldingControlsVisible", value: $configuration.display.areFoldingControlsVisible)
                KnobRowSeparator()
                StepperRow(
                    label: "minimumFoldableLines",
                    value: $configuration.display.minimumFoldableLines,
                    range: 1...100
                )
                KnobRowSeparator()
                ToggleRow(label: "isMinimapVisible", value: $configuration.display.isMinimapVisible)
            }
            .padding(.vertical, 4)
            },
            label: {
                Text("Display")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(tokens: theme.style.text.base))
            }
        )
        .padding(.horizontal, 12)
    }
}
