# Configuration System Diagram

This diagram illustrates the comprehensive configuration system used throughout the CodeEditorPlugin framework.

```mermaid
classDiagram
    direction LR
    
    %% Top Row - Root Configuration
    class EditorConfiguration {
        &lt;&lt;configuration root&gt;&gt;
        +display DisplayConfiguration
        +layout LayoutConfiguration
        +behavior BehaviorConfiguration
        +performance PerformanceConfiguration
        +validate()
        +copy()
    }

    class ConfigurationPresets {
        &lt;&lt;preset factory&gt;&gt;
        +minimal()
        +standard()
        +performance()
        +accessibility()
        +custom()
    }

    class ConfigurationValidator {
        &lt;&lt;validation logic&gt;&gt;
        +validate()
        +validateFontSize()
        +validateTabWidth()
        +validateCacheSize()
    }

    %% Second Row - Core Configuration Sections
    class DisplayConfiguration {
        &lt;&lt;visual settings&gt;&gt;
        +fontSize CGFloat
        +fontName String?
        +showLineNumbers Bool
        +showInvisibles Bool
        +showMinimap Bool
        +theme ThemeConfiguration
    }

    class LayoutConfiguration {
        &lt;&lt;layout settings&gt;&gt;
        +tabWidth Int
        +indentStyle IndentStyle
        +lineWrapping LineWrappingMode
        +gutterWidth CGFloat?
        +minimapWidth CGFloat
        +lineSpacing CGFloat
    }

    class BehaviorConfiguration {
        &lt;&lt;editing behavior&gt;&gt;
        +autoIndent Bool
        +autoCloseBrackets Bool
        +highlightMatchingBrackets Bool
        +enableCompletions Bool
        +tabKeyBehavior TabKeyBehavior
    }

    %% Third Row - Performance & Themes
    class PerformanceConfiguration {
        &lt;&lt;performance tuning&gt;&gt;
        +asyncHighlighting Bool
        +highlightingDebounce TimeInterval
        +maxHighlightingLength Int
        +enableLineCache Bool
        +cacheSize Int
        +virtualScrolling Bool
    }

    class ThemeConfiguration {
        &lt;&lt;color theme&gt;&gt;
        +backgroundColor Color
        +textColor Color
        +lineNumberColor Color
        +selectionColor Color
        +cursorColor Color
        +syntaxColors SyntaxColorScheme
    }

    class SyntaxColorScheme {
        &lt;&lt;syntax coloring&gt;&gt;
        +keyword Color
        +string Color
        +comment Color
        +number Color
        +function Color
        +type Color
    }

    %% Fourth Row - Enumerations
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

    class TabKeyBehavior {
        &lt;&lt;enumeration&gt;&gt;
        insertTab
        insertSpaces
        triggerCompletion
    }

    %% Fifth Row - SwiftUI Integration & Persistence
    class AppState {
        &lt;&lt;ObservableObject&gt;&gt;
        @Published configuration EditorConfiguration
        +updateConfiguration()
        +resetToDefault()
        +loadFromUserDefaults()
        +saveToUserDefaults()
    }

    class ConfigurationEnvironmentKey {
        &lt;&lt;EnvironmentKey&gt;&gt;
        +defaultValue EditorConfiguration
    }

    class ConfigurationPersistence {
        &lt;&lt;data persistence&gt;&gt;
        +save() throws
        +load() throws
        +encodeJSON() throws
        +decodeJSON() throws
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
    
    %% Styling - Dark mode friendly colors
    classDef main fill:#6366f120,stroke:#6366f1,stroke-width:3px,color:#fff
    classDef section fill:#8b5cf620,stroke:#8b5cf6,stroke-width:2px,color:#fff
    classDef theme fill:#10b98120,stroke:#10b981,stroke-width:2px,color:#fff
    classDef enum fill:#06b6d420,stroke:#06b6d4,stroke-width:2px,color:#fff
    classDef util fill:#f59e0b20,stroke:#f59e0b,stroke-width:2px,color:#fff
    classDef swiftui fill:#10b98120,stroke:#10b981,stroke-width:2px,color:#fff
    
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