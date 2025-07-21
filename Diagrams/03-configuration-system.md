# Configuration System Diagram

This diagram illustrates the comprehensive configuration system used throughout the CodeEditorPlugin framework.

```mermaid
classDiagram
    %% Main Configuration
    class EditorConfiguration {
        +display: DisplayConfiguration
        +layout: LayoutConfiguration
        +behavior: BehaviorConfiguration
        +performance: PerformanceConfiguration
        +static defaultConfiguration: EditorConfiguration
        +static minimalConfiguration: EditorConfiguration
        +static performanceConfiguration: EditorConfiguration
        +validate() throws
        +copy(with: (inout EditorConfiguration) -> Void) EditorConfiguration
    }

    %% Display Configuration
    class DisplayConfiguration {
        +fontSize: CGFloat
        +fontName: String?
        +showLineNumbers: Bool
        +showInvisibles: Bool
        +showMinimap: Bool
        +theme: ThemeConfiguration
        +cursorStyle: CursorStyle
        +selectionStyle: SelectionStyle
    }

    class ThemeConfiguration {
        +backgroundColor: Color
        +textColor: Color
        +lineNumberColor: Color
        +gutterBackgroundColor: Color
        +selectionColor: Color
        +cursorColor: Color
        +syntaxColors: SyntaxColorScheme
    }

    class SyntaxColorScheme {
        +keyword: Color
        +string: Color
        +comment: Color
        +number: Color
        +function: Color
        +type: Color
        +variable: Color
        +operator: Color
    }

    %% Layout Configuration
    class LayoutConfiguration {
        +tabWidth: Int
        +indentStyle: IndentStyle
        +lineWrapping: LineWrappingMode
        +gutterWidth: CGFloat?
        +minimapWidth: CGFloat
        +lineSpacing: CGFloat
        +contentInsets: EdgeInsets
    }

    class IndentStyle {
        &lt;&lt;enumeration&gt;&gt;
        spaces(Int)
        tabs
    }

    class LineWrappingMode {
        &lt;&lt;enumeration&gt;&gt;
        none
        word
        character
    }

    %% Behavior Configuration
    class BehaviorConfiguration {
        +autoIndent: Bool
        +autoCloseBrackets: Bool
        +highlightMatchingBrackets: Bool
        +enableCompletions: Bool
        +completionTriggerCharacters: Set~String~
        +tabKeyBehavior: TabKeyBehavior
        +pasteFormatting: PasteFormatting
    }

    class TabKeyBehavior {
        &lt;&lt;enumeration&gt;&gt;
        insertTab
        insertSpaces
        triggerCompletion
    }

    %% Performance Configuration
    class PerformanceConfiguration {
        +asyncHighlighting: Bool
        +highlightingDebounce: TimeInterval
        +maxHighlightingLength: Int
        +enableLineCache: Bool
        +cacheSize: Int
        +virtualScrolling: Bool
        +memoryWarningThreshold: Double
    }

    %% Configuration Management
    class ConfigurationValidator {
        +validate(EditorConfiguration) throws
        +validateFontSize(CGFloat) throws
        +validateTabWidth(Int) throws
        +validateCacheSize(Int) throws
    }

    class ConfigurationPresets {
        +minimal() EditorConfiguration
        +standard() EditorConfiguration
        +performance() EditorConfiguration
        +accessibility() EditorConfiguration
        +custom(builder) EditorConfiguration
    }

    %% SwiftUI Integration
    class ConfigurationEnvironmentKey {
        &lt;&lt;EnvironmentKey&gt;&gt;
        +defaultValue: EditorConfiguration
    }

    class AppState {
        &lt;&lt;ObservableObject&gt;&gt;
        @Published configuration: EditorConfiguration
        +updateConfiguration((inout EditorConfiguration) -> Void)
        +resetToDefault()
        +loadFromUserDefaults()
        +saveToUserDefaults()
    }

    %% Configuration Storage
    class ConfigurationPersistence {
        +save(EditorConfiguration, to: URL) throws
        +load(from: URL) EditorConfiguration throws
        +encodeJSON(EditorConfiguration) Data throws
        +decodeJSON(Data) EditorConfiguration throws
    }

    %% Relationships
    EditorConfiguration *-- DisplayConfiguration : contains
    EditorConfiguration *-- LayoutConfiguration : contains
    EditorConfiguration *-- BehaviorConfiguration : contains
    EditorConfiguration *-- PerformanceConfiguration : contains
    
    DisplayConfiguration *-- ThemeConfiguration : contains
    ThemeConfiguration *-- SyntaxColorScheme : contains
    
    LayoutConfiguration --> IndentStyle : uses
    LayoutConfiguration --> LineWrappingMode : uses
    
    BehaviorConfiguration --> TabKeyBehavior : uses
    
    ConfigurationValidator --> EditorConfiguration : validates
    ConfigurationPresets --> EditorConfiguration : creates
    
    AppState --> EditorConfiguration : manages
    AppState --> ConfigurationPersistence : uses
    
    ConfigurationEnvironmentKey --> EditorConfiguration : provides
    
    %% Styling
    classDef main fill:#e3f2fd,stroke:#2196f3,stroke-width:3px
    classDef section fill:#fff3e0,stroke:#ff9800,stroke-width:2px
    classDef theme fill:#e8f5e9,stroke:#4caf50,stroke-width:2px
    classDef enum fill:#f3e5f5,stroke:#9c27b0,stroke-width:2px
    classDef util fill:#fce4ec,stroke:#e91e63,stroke-width:2px
    classDef swiftui fill:#e1f5e1,stroke:#4caf50,stroke-width:2px
    
    class EditorConfiguration main
    class DisplayConfiguration section
    class LayoutConfiguration section
    class BehaviorConfiguration section
    class PerformanceConfiguration section
    class ThemeConfiguration theme
    class SyntaxColorScheme theme
    class IndentStyle enum
    class LineWrappingMode enum
    class TabKeyBehavior enum
    class ConfigurationValidator util
    class ConfigurationPresets util
    class ConfigurationPersistence util
    class ConfigurationEnvironmentKey swiftui
    class AppState swiftui
```

## Configuration Usage Patterns

### Direct Property Access
```swift
config.display.showLineNumbers = true
config.layout.tabWidth = 4
```

### Batch Updates
```swift
appState.updateConfiguration { config in
    config.display.fontSize = 16
    config.behavior.autoIndent = true
}
```

### Environment Integration
```swift
CodeEditor(text: $code)
    .environment(\.codeEditorConfiguration, customConfig)
```

### Presets
```swift
let minimalConfig = EditorConfiguration.minimal
let performanceConfig = EditorConfiguration.performance
```