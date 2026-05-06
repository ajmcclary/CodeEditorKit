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
                ToggleRow(label: "enableSyntaxHighlighting", value: $configuration.display.enableSyntaxHighlighting)
                ToggleRow(label: "isLineNumbersEnabled", value: $configuration.display.isLineNumbersEnabled)
                ToggleRow(label: "enableAnnotations", value: $configuration.display.enableAnnotations)
                ToggleRow(label: "highlightSelectedLine", value: $configuration.display.highlightSelectedLine)
                ColorRow(label: "selectedLineHighlightColor", value: $configuration.display.selectedLineHighlightColor)
                ToggleRow(label: "showInvisibleCharacters", value: $configuration.display.showInvisibleCharacters)
                ToggleRow(label: "enableCodeFolding", value: $configuration.display.enableCodeFolding)
                ToggleRow(label: "showFoldingControls", value: $configuration.display.showFoldingControls)
                StepperRow(
                    label: "minimumFoldableLines",
                    value: $configuration.display.minimumFoldableLines,
                    range: 1...100
                )
                ToggleRow(label: "showMinimap", value: $configuration.display.showMinimap)
            }
            .padding(.vertical, 4)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 12)
    }
}
