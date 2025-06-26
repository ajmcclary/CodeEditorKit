# Editor Configuration Comparison

| Configuration | AppKit | SwiftUI | Comments |
| :--- | :---: | :---: | :--- |
| **Layout** | | | |
| `tabWidth` | ✅ | ✅ | The number of spaces to use for a tab. |
| `insertSpacesForTabs` | ✅ | ✅ | If true, inserts spaces instead of tab characters. |
| `lineSpacing` | ✅ | ✅ | The line spacing multiplier. |
| `wrapLines` | ✅ | ✅ | If true, long lines will be wrapped. |
| `gutterWidth` | ✅ | ✅ | Configurable gutter width for line numbers (40-100pt). |
| `lineNumberPadding` | ✅ | ✅ | Configurable padding for line numbers (4-16pt). |
| `annotationBadgeSize` | ✅ | ✅ | Configurable annotation badge size (12-24pt). |
| `annotationBadgePadding`| ✅ | ✅ | Configurable padding around annotation badges (2-8pt). |
| **Display** | | | |
| `showLineNumbers` | ✅ | ✅ | If true, line numbers will be shown in the gutter. |
| `highlightSelectedLine` | ✅ | ✅ | If true, the current line will be highlighted. |
| `showInvisibleCharacters`| ✅ | ✅ | If true, invisible characters will be shown. |
| `fontSize` | ✅ | ✅ | The font size for the editor text. |
| `enableSyntaxHighlighting`| ✅ | ✅ | If true, syntax highlighting will be enabled. |
| `enableAnnotations` | ✅ | ✅ | If true, the annotation system will be enabled. |
| `showMinimap` | ✅ | ✅ | Toggle minimap visibility with visual indicator. |
| `showIndentGuides` | ✅ | ✅ | Toggle indent guides for better code structure visualization. |
| **Behavior** | | | |
| `isEditable` | ✅ | ✅ | If true, the editor will be editable. |
| `isSelectable` | ✅ | ✅ | Toggle text selection capability. |
| `autoIndent` | ✅ | ✅ | If true, new lines will be auto-indented. |
| `autoCloseBrackets` | ✅ | ✅ | Automatically close brackets when typing opening bracket. |
| `autoCloseQuotes` | ✅ | ✅ | Automatically close quotes when typing opening quote. |
| `enableCodeCompletion` | ✅ | ✅ | If true, code completion will be enabled. |
| `isContinuousSpellCheckingEnabled`| ✅ | ✅ | Toggle continuous spell checking. |
| `isGrammarCheckingEnabled`| ✅ | ✅ | Toggle grammar checking. |
| `isAutomaticQuoteSubstitutionEnabled`| ✅ | ✅ | Toggle smart quote substitution. |
| `isAutomaticDashSubstitutionEnabled`| ✅ | ✅ | Toggle smart dash substitution. |
| `isAutomaticTextReplacementEnabled`| ✅ | ✅ | Toggle automatic text replacement. |
| `isAutomaticSpellingCorrectionEnabled`| ✅ | ✅ | Toggle automatic spelling correction. |
| `isAutomaticTextCompletionEnabled`| ✅ | ✅ | Toggle automatic text completion. |
| **Performance** | | | |
| `maxSyntaxHighlightingLength`| ✅ | ✅ | Configurable max file size for syntax highlighting (10KB-1MB). |
| `useHardwareAcceleration`| ✅ | ✅ | If true, hardware acceleration will be used. |
| `smoothScrolling` | ✅ | ✅ | If true, smooth scrolling will be enabled. |
| `textChangeDebounceInterval`| ✅ | ✅ | Configurable debounce interval for text changes (0-1s). |
| **Plugin Management** | | | |
| `Enable/Disable Plugins` | ⚠️ | ⚠️ | Plugin system exists but not exposed in UI. |
| `Plugin-Specific Settings` | ⚠️ | ⚠️ | Plugin infrastructure present but no UI. |
| `Export/Import Config` | ✅ | ✅ | Full JSON export/import functionality implemented. |
| `Reset All Settings` | ✅ | ✅ | Reset button available in configuration view. |
| `Performance Statistics` | ⚠️ | ⚠️ | Performance monitoring exists but not exposed in UI. |

# Platform Feature Comparison

| Feature | macOS | iOS & visionOS | Comments |
| :--- | :---: | :---: | :--- |
| **Core Editor** | ✅ | ✅ | Both platforms provide a fully functional code editor with syntax highlighting, line numbers, and text editing capabilities. |
| **SwiftUI Integration** | ✅ | ✅ | The editor is available as a native SwiftUI view on both platforms, enabling seamless integration into modern app layouts. |
| **Configuration Presets** | ✅ | ✅ | Both platforms now offer full configuration presets (Full Featured, Minimal, Read-Only, Markdown, Presentation) through UnifiedConfigurationView. |
| **Split View Editor** | ❌ | ❌ | Split view comparison removed in favor of live preview in single editor. |
| **Feature Tour** | ✅ | ❌ | A guided feature tour is available on macOS to help users discover key functionalities. |
| **Config Import/Export** | ✅ | ✅ | Both platforms support configuration import/export as JSON (file-based on macOS, share sheet on iOS). |
| **Custom Menu Commands**| ✅ | ❌ | macOS provides custom menu bar commands and keyboard shortcuts for actions like toggling line numbers and resetting the layout. |
| **Status Bar** | ✅ | ✅ | Both platforms now show a unified status bar with line count, character count, and active feature indicators. |
| **Live Configuration** | ✅ | ✅ | All configuration changes update the editor in real-time on both platforms. |
| **Visual Indicators** | ✅ | ✅ | Both platforms show visual badges when features like minimap or annotations are active. |
| **Unified UI** | ✅ | ✅ | Single codebase (UnifiedContentView) provides consistent experience across platforms using NavigationSplitView. |
| **Search Configuration** | ✅ | ✅ | Configuration options are searchable to easily find specific settings among 36+ options. |
| **Expandable Sections** | ✅ | ✅ | Configuration organized into collapsible sections: Display, Layout, Behavior, Text Input, Performance. |
| **Quick Toggles** | ✅ | ✅ | Toolbar provides quick access to frequently used options: line numbers, minimap, invisible characters, editing. |
| **Reset Functionality** | ✅ | ✅ | Both platforms can reset all settings or individual sections to defaults. |
