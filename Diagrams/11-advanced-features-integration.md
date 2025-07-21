# Advanced Features Integration Architecture

This diagram shows the advanced features system that extends the core CodeEditorPlugin functionality with debugging, search/replace, smart editing, code folding, and symbol navigation capabilities.

```mermaid
classDiagram
    %% Core Feature Integration
    class AdvancedFeaturesCoordinator {
        +debuggerIntegration: DebuggerIntegrationCore
        +searchEngine: SearchReplaceEngine
        +smartEditing: SmartEditingEngine
        +codeFolding: CodeFoldingEngine
        +symbolNavigator: SymbolNavigator
        +initialize(codeEditorView: CodeEditorView)
        +enableFeature(FeatureType)
        +disableFeature(FeatureType)
    }

    class FeatureType {
        &lt;&lt;enumeration&gt;&gt;
        debugger
        search
        smartEditing
        codeFolding
        symbolNavigation
    }

    %% Debugger Integration System
    class DebuggerIntegrationCore {
        +adapter: DebugAdapter
        +models: DebuggerModels
        +breakpointManager: BreakpointManager
        +evaluationEngine: DebuggerEvaluation
        +executionController: DebuggerExecution
        +startDebugging(config: DebugConfiguration)
        +stopDebugging()
        +handleDebugEvent(DebugEvent)
    }

    class DebugAdapter {
        +protocol: DebugProtocol
        +transport: DebugTransport
        +connect(endpoint: String)
        +sendRequest(DebugRequest)
        +handleResponse(DebugResponse)
    }

    class DebuggerModels {
        +session: DebugSession
        +threads: [DebugThread]
        +stackFrames: [StackFrame]
        +variables: [Variable]
        +sources: [DebugSource]
    }

    class BreakpointManager {
        +breakpoints: [Breakpoint]
        +pendingBreakpoints: [PendingBreakpoint]
        +addBreakpoint(line: Int, file: String)
        +removeBreakpoint(id: String)
        +validateBreakpoints()
        +syncWithDebugger()
    }

    class DebuggerEvaluation {
        +evaluateExpression(expression: String) DebugValue
        +evaluateHover(position: TextPosition) HoverInfo?
        +getVariableDetails(variableRef: Int) [Variable]
        +setVariableValue(variableRef: Int, value: String)
    }

    class DebuggerExecution {
        +continue()
        +stepOver()
        +stepInto()
        +stepOut()
        +pause()
        +restart()
        +terminate()
    }

    %% Search & Replace Engine
    class SearchReplaceEngine {
        +searchProvider: SearchProvider
        +replaceProvider: ReplaceProvider
        +regexEngine: RegexEngine
        +searchHistory: SearchHistory
        +currentSearch: SearchContext?
        +search(query: SearchQuery) [SearchResult]
        +replace(query: ReplaceQuery) ReplaceResult
        +replaceAll(query: ReplaceQuery) ReplaceAllResult
    }

    class SearchProvider {
        +textualSearch(query: String, options: SearchOptions) [TextMatch]
        +regexSearch(pattern: String, options: SearchOptions) [RegexMatch]
        +symbolSearch(query: String) [SymbolMatch]
        +fileSearch(query: String) [FileMatch]
    }

    class ReplaceProvider {
        +performReplace(match: SearchResult, replacement: String) ReplaceResult
        +performReplaceAll(matches: [SearchResult], replacement: String) ReplaceAllResult
        +undoReplace(operation: ReplaceOperation)
        +redoReplace(operation: ReplaceOperation)
    }

    class SearchContext {
        +query: SearchQuery
        +results: [SearchResult]
        +currentIndex: Int
        +searchScope: SearchScope
        +options: SearchOptions
    }

    %% Smart Editing Engine
    class SmartEditingEngine {
        +autoCompletionEnhancer: AutoCompletionEnhancer
        +smartIndentationEngine: SmartIndentationEngine
        +bracketCompletionHandler: BracketCompletionHandler
        +codeActionProvider: CodeActionProvider
        +refactoringEngine: RefactoringEngine
        +enhanceCompletion(context: CompletionContext)
        +performSmartIndent(range: NSRange)
        +handleBracketInput(character: String)
    }

    class AutoCompletionEnhancer {
        +contextAnalyzer: ContextAnalyzer
        +priorityCalculator: PriorityCalculator
        +enhanceCompletions(completions: [CompletionItem]) [EnhancedCompletionItem]
        +analyzeContext(position: TextPosition) CompletionContext
        +calculatePriority(item: CompletionItem, context: CompletionContext) Double
    }

    class SmartIndentationEngine {
        +indentationRules: [IndentationRule]
        +languageSpecificRules: [String: [IndentationRule]]
        +calculateIndentation(line: Int, language: LanguageConfig) IndentationLevel
        +adjustIndentationForContext(range: NSRange)
        +handleElectricCharacters(character: String)
    }

    class CodeActionProvider {
        +availableActions: [CodeAction]
        +getActionsForRange(range: NSRange) [CodeAction]
        +executeAction(action: CodeAction)
        +registerAction(action: CodeAction)
    }

    %% Code Folding Engine
    class CodeFoldingEngine {
        +foldingProviders: [FoldingProvider]
        +foldingRegions: [FoldingRegion]
        +foldingRenderer: FoldingRenderer
        +detectFoldingRegions(text: String, language: LanguageConfig) [FoldingRegion]
        +foldRegion(region: FoldingRegion)
        +unfoldRegion(region: FoldingRegion)
        +toggleFolding(line: Int)
    }

    class FoldingProvider {
        &lt;&lt;protocol&gt;&gt;
        +languageId: String
        +provideFolding(document: TextDocument) [FoldingRange]
        +supportsFoldingType(type: FoldingType) Bool
    }

    class BraceFoldingProvider {
        +detectBraceRegions(text: String) [FoldingRange]
        +matchBraces(text: String) [(Int, Int)]
        +validateBraceStructure(ranges: [FoldingRange]) [FoldingRange]
    }

    class IndentationFoldingProvider {
        +detectIndentationRegions(text: String) [FoldingRange]
        +analyzeIndentationLevel(line: String) Int
        +groupByIndentation(lines: [String]) [FoldingRange]
    }

    class CommentFoldingProvider {
        +detectCommentBlocks(text: String, language: LanguageConfig) [FoldingRange]
        +identifyCommentStyles(language: LanguageConfig) [CommentStyle]
    }

    %% Symbol Navigation (Basic Overview - Detailed in separate diagram)
    class SymbolNavigator {
        +symbolProviders: [SymbolProvider]
        +symbolCache: SymbolCache
        +breadcrumbProvider: BreadcrumbProvider
        +outlineProvider: OutlineProvider
        +navigateToSymbol(symbol: DocumentSymbol)
        +findSymbolReferences(symbol: DocumentSymbol) [SymbolReference]
        +getDocumentOutline() DocumentOutline
    }

    %% Relationships
    AdvancedFeaturesCoordinator --> DebuggerIntegrationCore : manages
    AdvancedFeaturesCoordinator --> SearchReplaceEngine : manages
    AdvancedFeaturesCoordinator --> SmartEditingEngine : manages
    AdvancedFeaturesCoordinator --> CodeFoldingEngine : manages
    AdvancedFeaturesCoordinator --> SymbolNavigator : manages
    AdvancedFeaturesCoordinator --> FeatureType : uses

    DebuggerIntegrationCore --> DebugAdapter : uses
    DebuggerIntegrationCore --> DebuggerModels : manages
    DebuggerIntegrationCore --> BreakpointManager : uses
    DebuggerIntegrationCore --> DebuggerEvaluation : uses
    DebuggerIntegrationCore --> DebuggerExecution : uses

    SearchReplaceEngine --> SearchProvider : uses
    SearchReplaceEngine --> ReplaceProvider : uses
    SearchReplaceEngine --> SearchContext : manages

    SmartEditingEngine --> AutoCompletionEnhancer : uses
    SmartEditingEngine --> SmartIndentationEngine : uses
    SmartEditingEngine --> CodeActionProvider : uses

    CodeFoldingEngine --> FoldingProvider : uses
    FoldingProvider <|-- BraceFoldingProvider : implements
    FoldingProvider <|-- IndentationFoldingProvider : implements
    FoldingProvider <|-- CommentFoldingProvider : implements

    %% Styling - Dark mode friendly colors
    classDef coordinator fill:#6366f120,stroke:#6366f1,stroke-width:3px,color:#fff
    classDef debugger fill:#ec489920,stroke:#ec4899,stroke-width:2px,color:#fff
    classDef search fill:#8b5cf620,stroke:#8b5cf6,stroke-width:2px,color:#fff
    classDef smart fill:#10b98120,stroke:#10b981,stroke-width:2px,color:#fff
    classDef folding fill:#f59e0b20,stroke:#f59e0b,stroke-width:2px,color:#fff
    classDef symbol fill:#3b82f620,stroke:#3b82f6,stroke-width:2px,color:#fff
    classDef provider fill:#06b6d420,stroke:#06b6d4,stroke-width:2px,color:#fff
    classDef enum fill:#6b728020,stroke:#6b7280,stroke-width:2px,color:#fff

    class AdvancedFeaturesCoordinator coordinator
    class DebuggerIntegrationCore,DebugAdapter,DebuggerModels,BreakpointManager,DebuggerEvaluation,DebuggerExecution debugger
    class SearchReplaceEngine,SearchProvider,ReplaceProvider,SearchContext search
    class SmartEditingEngine,AutoCompletionEnhancer,SmartIndentationEngine,CodeActionProvider smart
    class CodeFoldingEngine,BraceFoldingProvider,IndentationFoldingProvider,CommentFoldingProvider folding
    class SymbolNavigator symbol
    class FoldingProvider provider
    class FeatureType enum
```

## Key Features Integration

### 1. Debugger Integration
- **Full DAP Support**: Debug Adapter Protocol implementation
- **Breakpoint Management**: Visual breakpoints with validation
- **Variable Inspection**: Expression evaluation and variable watching
- **Execution Control**: Step-by-step debugging with full control

### 2. Search & Replace Engine
- **Multi-mode Search**: Text, regex, symbol, and file search
- **Advanced Replace**: Single and batch replace with undo/redo
- **Search History**: Previous searches with quick access
- **Scope Control**: Document, selection, or project-wide search

### 3. Smart Editing Engine
- **Context-aware Completion**: Enhanced completion with priority calculation
- **Intelligent Indentation**: Language-specific smart indentation
- **Auto-completion**: Bracket matching and electric character handling
- **Code Actions**: Quick fixes and refactoring suggestions

### 4. Code Folding System
- **Multi-provider Support**: Brace, indentation, and comment folding
- **Language Agnostic**: Works with any supported language
- **Visual Integration**: Seamless UI integration with gutter
- **Persistent State**: Folding state preserved across sessions

### 5. Symbol Navigation
- **Document Outline**: Hierarchical symbol view
- **Breadcrumb Navigation**: Current scope breadcrumbs
- **Go-to Definition**: Quick symbol navigation
- **Find References**: Symbol usage across codebase

## Architecture Benefits

1. **Modular Design**: Each feature can be enabled/disabled independently
2. **Language Support**: Features work across all supported languages
3. **Performance Optimized**: Lazy loading and efficient caching
4. **Extensible**: Plugin architecture for additional features
5. **Integration Ready**: Seamless integration with LSP and other systems