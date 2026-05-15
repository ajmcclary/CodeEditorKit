import CodeEditorPlugin
import SwiftUI

struct BehaviorKnobsSection: View {
    @Bindable var configuration: ConfigurationModel
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
        ToggleRow(label: "isEditable", value: $configuration.current.behavior.isEditable)
        ToggleRow(label: "isSelectable", value: $configuration.current.behavior.isSelectable)
        ToggleRow(label: "isAutoIndentEnabled", value: $configuration.current.behavior.isAutoIndentEnabled)
        ToggleRow(label: "autoScrollToCursor", value: $configuration.current.behavior.autoScrollToCursor)
    }

    @ViewBuilder
    private var autoSubstitutionSection: some View {
        KnobSubsection(title: "Auto-Substitution")
        ToggleRow(
            label: "isAutomaticLinkDetectionEnabled",
            value: $configuration.current.behavior.isAutomaticLinkDetectionEnabled
        )
        ToggleRow(
            label: "isAutomaticQuoteSubstitutionEnabled",
            value: $configuration.current.behavior.isAutomaticQuoteSubstitutionEnabled
        )
        ToggleRow(
            label: "isAutomaticDashSubstitutionEnabled",
            value: $configuration.current.behavior.isAutomaticDashSubstitutionEnabled
        )
        ToggleRow(label: "autoCloseBrackets", value: $configuration.current.behavior.autoCloseBrackets)
        ToggleRow(label: "autoCloseQuotes", value: $configuration.current.behavior.autoCloseQuotes)
    }

    @ViewBuilder
    private var spellCheckSection: some View {
        KnobSubsection(title: "Spell-Check")
        ToggleRow(
            label: "isContinuousSpellCheckingEnabled",
            value: $configuration.current.behavior.isContinuousSpellCheckingEnabled
        )
        ToggleRow(
            label: "isGrammarCheckingEnabled",
            value: $configuration.current.behavior.isGrammarCheckingEnabled
        )
        ToggleRow(
            label: "isAutomaticTextReplacementEnabled",
            value: $configuration.current.behavior.isAutomaticTextReplacementEnabled
        )
        ToggleRow(
            label: "isAutomaticSpellingCorrectionEnabled",
            value: $configuration.current.behavior.isAutomaticSpellingCorrectionEnabled
        )
    }

    @ViewBuilder
    private var completionSection: some View {
        KnobSubsection(title: "Completion")
        ToggleRow(label: "isCodeCompletionEnabled", value: $configuration.current.behavior.isCodeCompletionEnabled)
        ToggleRow(
            label: "isAutomaticTextCompletionEnabled",
            value: $configuration.current.behavior.isAutomaticTextCompletionEnabled
        )
        ToggleRow(
            label: "showInlineCompletionSuggestions",
            value: $configuration.current.behavior.showInlineCompletionSuggestions
        )
        CharSetRow(
            label: "completionTriggerCharacters",
            value: $configuration.current.behavior.completionTriggerCharacters
        )
    }
}
