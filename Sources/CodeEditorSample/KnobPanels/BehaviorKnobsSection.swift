import CodeEditorPlugin
import SwiftUI

struct BehaviorKnobsSection: View {
    @Binding var configuration: EditorConfiguration
    @State private var expanded: Bool = false
    var expansion: KnobSectionExpansion = .toggleable

    var body: some View {
        KnobSection(
            title: "Behavior",
            icon: "wand.and.stars",
            accentIndex: 2,
            expanded: $expanded,
            expansion: expansion
        ) {
            VStack(alignment: .leading, spacing: 0) {
                editingSection
                autoSubstitutionSection
                spellCheckSection
                completionSection
            }
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var editingSection: some View {
        KnobSubsection(title: "Editing")
        ToggleRow(label: "isEditable", value: $configuration.behavior.isEditable)
        ToggleRow(label: "isSelectable", value: $configuration.behavior.isSelectable)
        ToggleRow(label: "isAutoIndentEnabled", value: $configuration.behavior.isAutoIndentEnabled)
        ToggleRow(label: "autoScrollToCursor", value: $configuration.behavior.autoScrollToCursor)
    }

    @ViewBuilder
    private var autoSubstitutionSection: some View {
        KnobSubsection(title: "Auto-Substitution")
        ToggleRow(
            label: "isAutomaticLinkDetectionEnabled",
            value: $configuration.behavior.isAutomaticLinkDetectionEnabled
        )
        ToggleRow(
            label: "isAutomaticQuoteSubstitutionEnabled",
            value: $configuration.behavior.isAutomaticQuoteSubstitutionEnabled
        )
        ToggleRow(
            label: "isAutomaticDashSubstitutionEnabled",
            value: $configuration.behavior.isAutomaticDashSubstitutionEnabled
        )
        ToggleRow(label: "autoCloseBrackets", value: $configuration.behavior.autoCloseBrackets)
        ToggleRow(label: "autoCloseQuotes", value: $configuration.behavior.autoCloseQuotes)
    }

    @ViewBuilder
    private var spellCheckSection: some View {
        KnobSubsection(title: "Spell-Check")
        ToggleRow(
            label: "isContinuousSpellCheckingEnabled",
            value: $configuration.behavior.isContinuousSpellCheckingEnabled
        )
        ToggleRow(
            label: "isGrammarCheckingEnabled",
            value: $configuration.behavior.isGrammarCheckingEnabled
        )
        ToggleRow(
            label: "isAutomaticTextReplacementEnabled",
            value: $configuration.behavior.isAutomaticTextReplacementEnabled
        )
        ToggleRow(
            label: "isAutomaticSpellingCorrectionEnabled",
            value: $configuration.behavior.isAutomaticSpellingCorrectionEnabled
        )
    }

    @ViewBuilder
    private var completionSection: some View {
        KnobSubsection(title: "Completion")
        ToggleRow(label: "isCodeCompletionEnabled", value: $configuration.behavior.isCodeCompletionEnabled)
        ToggleRow(
            label: "isAutomaticTextCompletionEnabled",
            value: $configuration.behavior.isAutomaticTextCompletionEnabled
        )
        ToggleRow(
            label: "showInlineCompletionSuggestions",
            value: $configuration.behavior.showInlineCompletionSuggestions
        )
        CharSetRow(
            label: "completionTriggerCharacters",
            value: $configuration.behavior.completionTriggerCharacters
        )
    }
}
