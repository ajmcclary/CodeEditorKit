| Configuration | AppKit | SwiftUI | Comments | Analysis |
| :--- | :---: | :---: | :--- | :--- |
| **Layout** | | | | |
| `tabWidth` | ✅ | ✅ | The number of spaces to use for a tab. | Fully supported. No action needed. |
| `insertSpacesForTabs` | ✅ | ✅ | If true, inserts spaces instead of tab characters. | Fully supported. No action needed. |
| `lineSpacing` | ✅ | ✅ | The line spacing multiplier. | Fully supported. No action needed. |
| `wrapLines` | ✅ | ✅ | If true, long lines will be wrapped. | Fully supported. No action needed. |
| `gutterWidth` | ✅ | ✅ | The width of the gutter for line numbers. | Fully supported. No action needed. |
| `lineNumberPadding` | ✅ | ✅ | The padding for line numbers within the gutter. | Fully supported. No action needed. |
| `annotationBadgeSize` | ✅ | ✅ | The size of annotation badges. | Fully supported. No action needed. |
| `annotationBadgePadding`| ✅ | ✅ | The padding around annotation badges. | Fully supported. No action needed. |
| **Display** | | | | |
| `showLineNumbers` | ✅ | ✅ | If true, line numbers will be shown in the gutter. | Fully supported. No action needed. |
| `highlightSelectedLine` | ✅ | ✅ | If true, the current line will be highlighted. | Fully supported. No action needed. |
| `showInvisibleCharacters`| ✅ | ✅ | If true, invisible characters (spaces, tabs, newlines) will be shown. | Fully supported. No action needed. |
| `fontSize` | ✅ | ✅ | The font size for the editor text. | Fully supported. No action needed. |
| `enableSyntaxHighlighting`| ✅ | ✅ | If true, syntax highlighting will be enabled. | Fully supported. No action needed. |
| `enableAnnotations` | ✅ | ✅ | If true, the annotation system will be enabled. | Fully supported. No action needed. |
| `showMinimap` | ❌ | ❌ | This feature is not yet implemented. | Implement a minimap view that can be displayed alongside the editor. This will likely require a separate view that renders a scaled-down version of the code. |
| `showIndentGuides` | ✅ | ✅ | If true, indent guides will be shown. | Fully supported. No action needed. |
| **Behavior** | | | | |
| `isEditable` | ✅ | ✅ | If true, the editor will be editable. | Fully supported. No action needed. |
| `isSelectable` | ✅ | ✅ | If true, text will be selectable. | Fully supported. No action needed. |
| `autoIndent` | ✅ | ✅ | If true, new lines will be auto-indented. | Fully supported. No action needed. |
| `autoCloseBrackets` | ✅ | ✅ | If true, brackets will be automatically closed. | Fully supported. No action needed. |
| `autoCloseQuotes` | ✅ | ✅ | If true, quotes will be automatically closed. | Fully supported. No action needed. |
| `enableCodeCompletion` | ✅ | ✅ | If true, code completion will be enabled. | Fully supported. No action needed. |
| `isContinuousSpellCheckingEnabled`| ✅ | ⚠️ | This is supported in AppKit, but not directly in SwiftUI. | For SwiftUI, this requires a custom implementation or the use of a `UIViewRepresentable` that wraps a `UITextView` with spell checking enabled. |
| `isGrammarCheckingEnabled`| ✅ | ❌ | This is only supported in AppKit. | For SwiftUI, this would require a custom implementation, likely leveraging a third-party grammar checking library. |
| `isAutomaticQuoteSubstitutionEnabled`| ✅ | ⚠️ | This is supported in AppKit, but not directly in SwiftUI. | For SwiftUI, this requires a custom implementation or the use of a `UIViewRepresentable` that wraps a `UITextView` with smart quotes enabled. |
| `isAutomaticDashSubstitutionEnabled`| ✅ | ⚠️ | This is supported in AppKit, but not directly in SwiftUI. | For SwiftUI, this requires a custom implementation or the use of a `UIViewRepresentable` that wraps a `UITextView` with smart dashes enabled. |
| `isAutomaticTextReplacementEnabled`| ✅ | ❌ | This is only supported in AppKit. | For SwiftUI, this would require a custom implementation to manage text replacements. |
| `isAutomaticSpellingCorrectionEnabled`| ✅ | ⚠️ | This is supported in AppKit, but not directly in SwiftUI. | For SwiftUI, this requires a custom implementation or the use of a `UIViewRepresentable` that wraps a `UITextView` with autocorrection enabled. |
| `isAutomaticTextCompletionEnabled`| ✅ | ❌ | This is only supported in AppKit. | For SwiftUI, this would require a custom implementation for text completion. |
| **Performance** | | | | |
| `maxSyntaxHighlightingLength`| ✅ | ✅ | The maximum file size for syntax highlighting (in bytes). | Fully supported. No action needed. |
| `useHardwareAcceleration`| ✅ | ✅ | If true, hardware acceleration will be used. | Fully supported. No action needed. |
| `smoothScrolling` | ✅ | ✅ | If true, smooth scrolling will be enabled. | Fully supported. No action needed. |
| `textChangeDebounceInterval`| ✅ | ✅ | The debounce interval for text changes (in seconds). | Fully supported. No action needed. |
| **Plugin Management** | | | Configurations related to managing language plugins. | These features are specific to the SwiftUI implementation and are not available in the AppKit version of the plugin. To support these features in AppKit, a custom UI would need to be built. |
| `Enable/Disable Plugins` | ❌ | ✅ | Allows enabling or disabling individual language plugins through the UI. | To support this in AppKit, a UI would need to be created to manage plugins. |
| `Plugin-Specific Settings` | ❌ | ✅ | The UI provides a view for details of each plugin, implying plugin-specific settings can be configured. | To support this in AppKit, a UI would need to be created to display and configure plugin-specific settings. |
| `Export/Import Config` | ❌ | ✅ | The UI provides actions to export and import the overall plugin configuration. | To support this in AppKit, a mechanism for exporting and importing the plugin configuration would need to be implemented. |
| `Reset All Settings` | ❌ | ✅ | The UI provides an action to reset all plugin settings to their defaults. | To support this in AppKit, a mechanism for resetting all plugin settings would need to be implemented. |
| `Performance Statistics` | ❌ | ✅ | The UI can display performance statistics for each plugin. | To support this in AppKit, a UI would need to be created to display performance statistics for each plugin. |