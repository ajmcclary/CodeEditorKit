# Configuration System Diagram

This diagram illustrates the configuration system used throughout the CodeEditorPlugin framework, including nested configuration sections, presets, and SwiftUI environment integration.

```mermaid
classDiagram
    direction LR

    %% Root Configuration
    class EditorConfiguration {
        &lt;&lt;configuration root&gt;&gt; Codable, Sendable
        +display Display
        +layout Layout
        +behavior Behavior
        +performance Performance
        +eventSystem UnifiedEventSystem?
        +actorCoordinator ActorCoordinator?
        +workspaceRoot URL?
        +platformCapabilities PlatformCapabilities?
        +unifiedPerformanceSystem UnifiedPerformanceSystem?
        +paragraphStyleCache ParagraphStyleCache?
        +languageMetadataRegistry LanguageMetadataRegistry?
        +platformServiceLayer PlatformServiceLayer?
        +validate() [ValidationError]
        +validateAndThrow()
        +with(layout:) Self
        +with(display:) Self
        +with(behavior:) Self
        +with(performance:) Self
        +with(eventSystem:) Self
        +apply(to:)
    }

    %% Nested Configuration Sections
    class EditorConfigurationDisplay {
        &lt;&lt;display settings&gt;&gt; Equatable, Sendable
        +isSyntaxHighlightingEnabled Bool
        +fontSize CGFloat
        +isLineNumbersEnabled Bool
        +areAnnotationsEnabled Bool
        +isSelectedLineHighlighted Bool
        +selectedLineHighlightColor PlatformColor
        +visibleLines Int
        +areInvisibleCharactersVisible Bool
        +isCodeFoldingEnabled Bool
        +areFoldingControlsVisible Bool
        +minimumFoldableLines Int
        +isMinimapVisible Bool
    }

    class EditorConfigurationLayout {
        &lt;&lt;layout settings&gt;&gt; Equatable, Sendable
        +tabWidth Int
        +insertSpacesForTabs Bool
        +wrapLines Bool
        +gutterWidth CGFloat
        +lineNumberPadding CGFloat
        +textContainerInset EdgeInsets
        +lineHeightMultiple CGFloat
        +characterSpacing CGFloat
        +textContainerWidthFraction CGFloat
        +annotationBadgeSize CGFloat
        +minimapWidth CGFloat
        +foldingControlSize CGFloat
        +foldingControlPadding CGFloat
    }

    class EditorConfigurationBehavior {
        &lt;&lt;editing behavior&gt;&gt; Equatable, Sendable
        +isEditable Bool
        +isSelectable Bool
        +isAutoIndentEnabled Bool
        +isCodeCompletionEnabled Bool
        +isAutomaticLinkDetectionEnabled Bool
        +isAutomaticQuoteSubstitutionEnabled Bool
        +isAutomaticDashSubstitutionEnabled Bool
        +autoCloseBrackets Bool
        +autoCloseQuotes Bool
        +isContinuousSpellCheckingEnabled Bool
        +isGrammarCheckingEnabled Bool
        +isAutomaticTextReplacementEnabled Bool
        +isAutomaticSpellingCorrectionEnabled Bool
        +isAutomaticTextCompletionEnabled Bool
        +showInlineCompletionSuggestions Bool
        +completionTriggerCharacters Set~Character~
        +autoScrollToCursor Bool
    }

    class EditorConfigurationPerformance {
        &lt;&lt;performance tuning&gt;&gt; Sendable
        +maxSyntaxHighlightingLength Int
        +usesRangeBasedHighlighting Bool
        +useHardwareAcceleration Bool
        +renderingUpdateStrategy RenderingUpdateStrategy
        +maxVisibleLines Int
        +maxFileSize Int
        +highlightingDebounceInterval Duration
        +smoothScrolling Bool
        +textChangeDebounceInterval Duration
        +animateCodeFolding Bool
        +maxEventsPerSecond Int
        +enableIOSOptimizations Bool
        +iOSLargeFileThreshold Int
        +iOSMaxHighlightingChunk Int
        +memoryMonitor MemoryMonitor?
    }

    class RenderingUpdateStrategy {
        &lt;&lt;enumeration&gt;&gt; String, Codable, Sendable
        immediate
        batched
        adaptive
    }

    %% Syntax Highlighting
    class SyntaxColorScheme {
        &lt;&lt;syntax coloring&gt;&gt; Sendable
        +keyword PlatformColor
        +identifier PlatformColor
        +string PlatformColor
        +number PlatformColor
        +comment PlatformColor
        +type PlatformColor
        +function PlatformColor
        +property PlatformColor
        +operator PlatformColor
        +punctuation PlatformColor
        +preprocessor PlatformColor
        +error PlatformColor
        +plain PlatformColor
    }

    %% SwiftUI Environment
    class CodeEditorEnvironment {
        &lt;&lt;consolidated environment&gt;&gt; Sendable
        +language Language
        +theme Theme
        +configuration EditorConfiguration
        +becomeFirstResponder Bool
        +memoryMonitor MemoryMonitor?
        +eventSystem UnifiedEventSystem?
        +with() Self
    }

    class CodeEditorEnvironmentKey {
        &lt;&lt;EnvironmentKey&gt;&gt;
        +defaultValue CodeEditorEnvironment
    }

    class ConfigurationEnvironmentKey {
        &lt;&lt;EnvironmentKey&gt;&gt;
        +defaultValue EditorConfiguration
    }

    %% Presets (via EditorConfiguration extension)
    class Presets {
        &lt;&lt;static presets&gt;&gt;
        +default EditorConfiguration
        +minimal EditorConfiguration
        +readOnly EditorConfiguration
        +markdown EditorConfiguration
        +presentation EditorConfiguration
        +iOS EditorConfiguration
        +catalyst EditorConfiguration
        +macOS EditorConfiguration
        +platformOptimized EditorConfiguration
    }

    %% Relationships
    EditorConfiguration *-- EditorConfigurationDisplay : contains
    EditorConfiguration *-- EditorConfigurationLayout : contains
    EditorConfiguration *-- EditorConfigurationBehavior : contains
    EditorConfiguration *-- EditorConfigurationPerformance : contains

    EditorConfigurationPerformance *-- RenderingUpdateStrategy : contains

    CodeEditorEnvironment --> EditorConfiguration : wraps
    CodeEditorEnvironmentKey --> CodeEditorEnvironment : provides
    ConfigurationEnvironmentKey --> EditorConfiguration : provides

    Presets --> EditorConfiguration : creates

    %% Styling - Light/Dark mode compatible colors
    classDef main fill:#007AFF20,stroke:#007AFF,stroke-width:3px,color:#1D1D1F
    classDef section fill:#AF52DE20,stroke:#AF52DE,stroke-width:2px,color:#1D1D1F
    classDef theme fill:#34C75920,stroke:#34C759,stroke-width:2px,color:#1D1D1F
    classDef enum fill:#007AFF20,stroke:#007AFF,stroke-width:2px,color:#1D1D1F
    classDef util fill:#FF950020,stroke:#FF9500,stroke-width:2px,color:#1D1D1F
    classDef swiftui fill:#34C75920,stroke:#34C759,stroke-width:2px,color:#1D1D1F

    class EditorConfiguration main
    class EditorConfigurationDisplay section
    class EditorConfigurationLayout section
    class EditorConfigurationBehavior section
    class EditorConfigurationPerformance section
    class SyntaxColorScheme theme
    class RenderingUpdateStrategy enum
    class Presets util
    class CodeEditorEnvironment swiftui
    class CodeEditorEnvironmentKey swiftui
    class ConfigurationEnvironmentKey swiftui
```

## Configuration Usage Patterns

### Direct Property Access
```swift
config.display.isLineNumbersEnabled = true
config.layout.tabWidth = 4
config.behavior.isAutoIndentEnabled = true
config.performance.maxSyntaxHighlightingLength = 500_000
```

### Immutable Updates via with()
```swift
let config = EditorConfiguration()
let updated = config
    .with(display: modifiedDisplay)
    .with(layout: modifiedLayout)
    .with(behavior: modifiedBehavior)
```

### Presets
```swift
let defaultConfig = EditorConfiguration.default
let minimalConfig = EditorConfiguration.minimal
let readOnlyConfig = EditorConfiguration.readOnly
let markdownConfig = EditorConfiguration.markdown
let presentationConfig = EditorConfiguration.presentation
let platformConfig = EditorConfiguration.platformOptimized

// Platform-specific presets
let iOSConfig = EditorConfiguration.iOS
let catalystConfig = EditorConfiguration.catalyst
let macOSConfig = EditorConfiguration.macOS
```

### Environment Integration
```swift
CodeEditor(text: $code)
    .codeEditorEnvironment(
        language: .swift,
        theme: .default,
        configuration: customConfig
    )

// Or set the full environment directly
CodeEditor(text: $code)
    .environment(\.codeEditorEnvironment, CodeEditorEnvironment(
        language: .swift,
        theme: .dark,
        configuration: myConfig
    ))
```
