# Core Components Class Diagram

This diagram details the main classes and protocols that form the core of the CodeEditorPlugin framework.

```mermaid
classDiagram
    direction LR
    
    %% Top Row - Core Protocols
    class CodeEditorAPI {
        &lt;&lt;protocol&gt;&gt;
        +language LanguageConfig?
        +text String
        +configuration EditorConfiguration
        +setLanguage()
        +invalidateLayout()
    }

    class CodeEditorViewDelegate {
        &lt;&lt;protocol&gt;&gt;
        +didChangeText()
        +shouldChangeText()
        +didChangeSelection()
    }

    %% Second Row - Main Components
    class CodeEditorView {
        &lt;&lt;main text view&gt;&gt;
        +delegate CodeEditorViewDelegate?
        +language LanguageConfig?
        +eventSystem UnifiedEventSystem
        +serviceRegistry BusinessLogicServiceRegistry
        +performTextEdit()
    }

    class CodeEditorContainerView {
        &lt;&lt;layout container&gt;&gt;
        +codeEditorView CodeEditorView
        +gutterView GutterView?
        +minimapView MinimapView?
        +configuration EditorConfiguration
    }

    %% Third Row - SwiftUI & Configuration
    class CodeEditor {
        &lt;&lt;SwiftUI wrapper&gt;&gt;
        @Binding text String
        +configuration EditorConfiguration
        +language LanguageConfig?
        +makeNSView()
        +makeUIView()
    }

    class EditorConfiguration {
        &lt;&lt;configuration&gt;&gt;
        +display DisplayConfiguration
        +layout LayoutConfiguration
        +behavior BehaviorConfiguration
        +validate()
    }

    class LanguageConfig {
        &lt;&lt;language definition&gt;&gt;
        +identifier String
        +name String
        +fileExtensions [String]
        +supportsCompletion Bool
    }

    %% Fourth Row - Event System
    class UnifiedEventSystem {
        &lt;&lt;singleton&gt;&gt;
        +shared UnifiedEventSystem
        +register()
        +emit()
        +addFilter()
    }

    class Event {
        &lt;&lt;data structure&gt;&gt;
        +type EventType
        +source Any
        +timestamp Date
    }

    class EventType {
        &lt;&lt;enumeration&gt;&gt;
        textChanged
        selectionChanged
        configurationChanged
        languageChanged
    }

    %% Fifth Row - Service Registry
    class BusinessLogicServiceRegistry {
        &lt;&lt;dependency injection&gt;&gt;
        +textEditingService TextEditingService
        +syntaxHighlightingService SyntaxHighlightingService
        +languageDetectionService LanguageDetectionService
        +completionManager CompletionManager
        +register()
        +resolve()
    }

    class TextEditingService {
        &lt;&lt;text operations&gt;&gt;
        +performEdit()
        +undoManager UndoManager
        +undo()
        +redo()
    }

    class SyntaxHighlightingService {
        &lt;&lt;syntax coloring&gt;&gt;
        +highlightText()
        +highlightRange()
        +clearHighlighting()
    }

    %% Sixth Row - More Services & Layout
    class LanguageDetectionService {
        &lt;&lt;language recognition&gt;&gt;
        +detectLanguage()
        +supportedLanguages [LanguageConfig]
        +registerLanguage()
    }

    class CompletionManager {
        &lt;&lt;code completion&gt;&gt;
        +provideCompletions()
        +registerProvider()
        +triggerCompletion()
    }

    class CodeEditorLayoutManager {
        &lt;&lt;NSLayoutManager&gt;&gt;
        +lineHeight CGFloat
        +characterWidth CGFloat
        +tabWidth Int
        +drawBackground()
        +drawGlyphs()
    }

    %% Seventh Row - UI & Performance
    class LineIndexCache {
        &lt;&lt;performance&gt;&gt;
        +invalidate()
        +lineInfo()
        +updateLine()
    }

    class GutterView {
        &lt;&lt;line numbers&gt;&gt;
        +showLineNumbers Bool
        +width CGFloat
        +drawLineNumbers()
        +handleClick()
    }

    class MinimapView {
        &lt;&lt;code overview&gt;&gt;
        +isVisible Bool
        +scale CGFloat
        +updateContent()
        +syncWithEditor()
    }

    %% Bottom Row - Supporting Data Types
    class LineInfo {
        &lt;&lt;line metadata&gt;&gt;
        +lineNumber Int
        +startIndex Int
        +endIndex Int
    }

    class TextChange {
        &lt;&lt;change record&gt;&gt;
        +range NSRange
        +replacementText String
        +timestamp Date
    }

    class CompletionContext {
        &lt;&lt;completion state&gt;&gt;
        +position NSRange
        +language LanguageConfig?
        +text String
    }

    class CompletionItem {
        &lt;&lt;completion suggestion&gt;&gt;
        +title String
        +detail String?
        +insertText String
    }

    %% Relationships
    CodeEditorView ..|> CodeEditorAPI : implements
    CodeEditorView --> CodeEditorViewDelegate : delegates to
    CodeEditorView --> UnifiedEventSystem : uses
    CodeEditorView --> BusinessLogicServiceRegistry : uses
    CodeEditorView --> CodeEditorLayoutManager : uses
    CodeEditorView --> LineIndexCache : maintains
    CodeEditorView --> EditorConfiguration : configured by
    CodeEditorView --> LanguageConfig : uses
    
    CodeEditorContainerView --> CodeEditorView : contains
    CodeEditorContainerView --> GutterView : contains
    CodeEditorContainerView --> MinimapView : contains
    CodeEditorContainerView --> EditorConfiguration : configured by
    
    CodeEditor --> CodeEditorContainerView : creates
    CodeEditor --> CodeEditorView : configures
    CodeEditor --> EditorConfiguration : uses
    CodeEditor --> LanguageConfig : uses
    
    UnifiedEventSystem --> Event : processes
    UnifiedEventSystem --> EventType : categorizes
    UnifiedEventSystem --> EventHandler : uses
    UnifiedEventSystem --> EventFilter : applies
    
    BusinessLogicServiceRegistry --> TextEditingService : manages
    BusinessLogicServiceRegistry --> SyntaxHighlightingService : manages
    BusinessLogicServiceRegistry --> LanguageDetectionService : manages
    BusinessLogicServiceRegistry --> CompletionManager : manages
    BusinessLogicServiceRegistry --> MemoryMonitor : manages
    
    Event --> EventType : categorized by
    Event --> TextChange : may contain
    
    LineIndexCache --> LineInfo : stores
    
    TextEditingService --> TextChange : creates
    SyntaxHighlightingService --> LanguageConfig : uses
    LanguageDetectionService --> LanguageConfig : provides
    CompletionManager --> CompletionContext : uses
    CompletionManager --> CompletionItem : provides
    
    CodeEditorLayoutManager --> NSLayoutManager : inherits

    %% Styling - Dark mode friendly colors
    classDef protocol fill:#10b98120,stroke:#10b981,stroke-width:2px,color:#fff
    classDef core fill:#6366f120,stroke:#6366f1,stroke-width:2px,color:#fff
    classDef swiftui fill:#10b98120,stroke:#10b981,stroke-width:2px,color:#fff
    classDef event fill:#f59e0b20,stroke:#f59e0b,stroke-width:2px,color:#fff
    classDef service fill:#8b5cf620,stroke:#8b5cf6,stroke-width:2px,color:#fff
    classDef layout fill:#3b82f620,stroke:#3b82f6,stroke-width:2px,color:#fff
    classDef ui fill:#ec489920,stroke:#ec4899,stroke-width:2px,color:#fff
    classDef config fill:#06b6d420,stroke:#06b6d4,stroke-width:2px,color:#fff
    classDef support fill:#6b728020,stroke:#6b7280,stroke-width:2px,color:#fff
    classDef enum fill:#6b728020,stroke:#6b7280,stroke-width:2px,color:#fff
    
    class CodeEditorAPI protocol
    class CodeEditorViewDelegate protocol
    class CodeEditorView core
    class CodeEditorContainerView core
    class CodeEditor swiftui
    class UnifiedEventSystem event
    class Event event
    class EventHandler event
    class EventFilter event
    class BusinessLogicServiceRegistry service
    class TextEditingService service
    class SyntaxHighlightingService service
    class LanguageDetectionService service
    class CompletionManager service
    class MemoryMonitor service
    class CodeEditorLayoutManager layout
    class LineIndexCache layout
    class GutterView ui
    class MinimapView ui
    class EditorConfiguration config
    class LanguageConfig config
    class LineInfo support
    class TextChange support
    class CompletionContext support
    class CompletionItem support
    class EventType enum
```

## Key Design Patterns

1. **Protocol-Oriented Design**: Core functionality exposed through `CodeEditorAPI` protocol
2. **Delegation Pattern**: `CodeEditorViewDelegate` for customizable behavior
3. **Service Locator**: `BusinessLogicServiceRegistry` manages all services
4. **Observer Pattern**: `UnifiedEventSystem` for decoupled event handling
5. **Composite Pattern**: `CodeEditorContainerView` composes multiple views
6. **Bridge Pattern**: `CodeEditor` SwiftUI wrapper bridges to AppKit/UIKit
7. **Cache Pattern**: `LineIndexCache` for performance optimization
