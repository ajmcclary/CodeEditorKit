# Core Components Class Diagram

This diagram details the main classes and protocols that form the core of the CodeEditorPlugin framework.

```mermaid
classDiagram
    %% Protocols
    class CodeEditorAPI {
        &lt;&lt;protocol&gt;&gt;
        +language: LanguageConfig?
        +text: String
        +textStorage: NSTextStorage
        +configuration: EditorConfiguration
        +setLanguage(LanguageConfig?)
        +setLanguage(fileExtension: String)
        +invalidateLayout()
        +ensureLayout()
        +scrollToLine(Int)
    }

    class CodeEditorViewDelegate {
        &lt;&lt;protocol&gt;&gt;
        +codeEditorViewDidChangeText(CodeEditorView)
        +codeEditorView(CodeEditorView, shouldChangeTextIn: NSRange, replacementString: String) Bool
        +codeEditorViewDidChangeSelection(CodeEditorView)
    }

    %% Core Classes
    class CodeEditorView {
        +delegate: CodeEditorViewDelegate?
        +language: LanguageConfig?
        +eventSystem: UnifiedEventSystem
        +serviceRegistry: BusinessLogicServiceRegistry
        +textContainer: NSTextContainer
        +layoutManager: CodeEditorLayoutManager
        +lineIndexCache: LineIndexCache
        -setupTextSystem()
        -setupServices()
        -registerEventHandlers()
        +performTextEdit(TextEditingService.EditAction)
    }

    class CodeEditorContainerView {
        +codeEditorView: CodeEditorView
        +gutterView: GutterView?
        +minimapView: MinimapView?
        +configuration: EditorConfiguration
        -setupSubviews()
        -updateLayout()
        -configureGutter()
        -configureMinimap()
    }

    class CodeEditor {
        &lt;&lt;SwiftUI View&gt;&gt;
        @Binding text: String
        +configuration: EditorConfiguration
        +language: LanguageConfig?
        +onTextChange: ((String) -> Void)?
        +makeNSView(context) NSView
        +makeUIView(context) UIView
        +updateNSView(NSView, context)
        +updateUIView(UIView, context)
    }

    %% Event System
    class UnifiedEventSystem {
        -eventHandlers: [EventType: [EventHandler]]
        -eventFilters: [EventFilter]
        +shared: UnifiedEventSystem
        +register(EventType, priority: Int, handler)
        +emit(Event)
        +addFilter(EventFilter)
        +removeFilter(EventFilter)
    }

    class Event {
        +type: EventType
        +source: Any
        +timestamp: Date
        +data: [String: Any]
    }

    %% Service Registry
    class BusinessLogicServiceRegistry {
        -services: [String: Any]
        +textEditingService: TextEditingService
        +syntaxHighlightingService: SyntaxHighlightingService
        +languageDetectionService: LanguageDetectionService
        +completionManager: CompletionManager
        +memoryMonitor: MemoryMonitor
        +register(T.Type, service: T)
        +resolve(T.Type) T?
    }

    %% Layout Management
    class CodeEditorLayoutManager {
        +lineHeight: CGFloat
        +characterWidth: CGFloat
        +tabWidth: Int
        +showInvisibles: Bool
        -calculateLineHeight()
        -calculateCharacterWidth()
        +drawBackground(forGlyphRange, at)
        +drawGlyphs(forGlyphRange, at)
    }

    %% Performance
    class LineIndexCache {
        -cache: [Int: LineInfo]
        -version: Int
        +invalidate()
        +lineInfo(at: Int) LineInfo?
        +updateLine(Int, info: LineInfo)
        +batchUpdate(updates)
    }

    %% Relationships
    CodeEditorView ..|> CodeEditorAPI : implements
    CodeEditorView --> CodeEditorViewDelegate : delegates to
    CodeEditorView --> UnifiedEventSystem : uses
    CodeEditorView --> BusinessLogicServiceRegistry : uses
    CodeEditorView --> CodeEditorLayoutManager : uses
    CodeEditorView --> LineIndexCache : maintains
    
    CodeEditorContainerView --> CodeEditorView : contains
    CodeEditorContainerView --> GutterView : contains
    CodeEditorContainerView --> MinimapView : contains
    
    CodeEditor --> CodeEditorContainerView : creates
    CodeEditor --> CodeEditorView : configures
    
    UnifiedEventSystem --> Event : processes
    BusinessLogicServiceRegistry --> TextEditingService : manages
    BusinessLogicServiceRegistry --> SyntaxHighlightingService : manages
    BusinessLogicServiceRegistry --> LanguageDetectionService : manages
    BusinessLogicServiceRegistry --> CompletionManager : manages
    BusinessLogicServiceRegistry --> MemoryMonitor : manages
    
    CodeEditorLayoutManager --> NSLayoutManager : inherits

    %% Styling
    classDef protocol fill:#e8f5e9,stroke:#4caf50,stroke-width:2px
    classDef core fill:#e3f2fd,stroke:#2196f3,stroke-width:2px
    classDef swiftui fill:#e1f5e1,stroke:#4caf50,stroke-width:2px
    classDef event fill:#fff3e0,stroke:#ff9800,stroke-width:2px
    classDef service fill:#fce4ec,stroke:#e91e63,stroke-width:2px
    classDef layout fill:#f3e5f5,stroke:#9c27b0,stroke-width:2px
    
    class CodeEditorAPI protocol
    class CodeEditorViewDelegate protocol
    class CodeEditorView core
    class CodeEditorContainerView core
    class CodeEditor swiftui
    class UnifiedEventSystem event
    class Event event
    class BusinessLogicServiceRegistry service
    class CodeEditorLayoutManager layout
    class LineIndexCache layout
```

## Key Design Patterns

1. **Protocol-Oriented Design**: Core functionality exposed through `CodeEditorAPI` protocol
2. **Delegation Pattern**: `CodeEditorViewDelegate` for customizable behavior
3. **Service Locator**: `BusinessLogicServiceRegistry` manages all services
4. **Observer Pattern**: `UnifiedEventSystem` for decoupled event handling
5. **Composite Pattern**: `CodeEditorContainerView` composes multiple views
6. **Bridge Pattern**: `CodeEditor` SwiftUI wrapper bridges to AppKit/UIKit
7. **Cache Pattern**: `LineIndexCache` for performance optimization