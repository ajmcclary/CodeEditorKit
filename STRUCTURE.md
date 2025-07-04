### Proposed Directory Structure (with Files)

```
Sources/CodeEditorPlugin/
├── CodeEditorPlugin.swift
├── Info.plist
│
├── Core/
│   ├── Engine/
│   │   ├── CodeEditorAPI.swift
│   │   ├── CodeEditorError.swift
│   │   ├── CodeEditorView.swift
│   │   ├── CodeEditorView+CodeEditorAPI.swift
│   │   ├── CodeEditorViewDelegate.swift
│   │   ├── CodeEditorViewDelegateProxy.swift
│   │   ├── CodeEditorViewProtocol.swift
│   │   └── TextSystemInterface.swift
│   │
│   └── TextSystem/
│       ├── ModernTextKit2Bridge.swift
│       ├── ModernTextKitHelper.swift
│       ├── TextKit2PerformanceHelper.swift
│       ├── TextKit2RenderingOptimizer.swift
│       ├── TextKitBridge.swift
│       ├── TextKitLineNumberHelper.swift
│       ├── TextLayoutFragment.swift
│       ├── TextLayoutFragmentView.swift
│       ├── TextLayoutManager.swift
│       ├── TextLocation.swift
│       ├── TextLocationRange.swift
│       ├── TextSelectionRect.swift
│       ├── AsyncTextProcessor.swift
│       ├── AwaitableQueue.swift
│       ├── BackgroundProcessor.swift
│       ├── HybridSyncAsyncValueProvider.swift
│       ├── HybridSyncAsyncVersionedResource.swift
│       ├── RangeProcessor.swift
│       ├── TextSystemStyler.swift
│       ├── ThreePhaseTextSystemStyler.swift
│       └── RangeValidation/
│           ├── RangeInvalidationBuffer.swift
│           ├── RangeTarget.swift
│           ├── RangeValidator.swift
│           ├── SinglePhaseRangeValidator.swift
│           ├── ThreePhaseRangeValidator.swift
│           ├── TokenSystemValidator.swift
│           ├── ValidationContext.swift
│           └── VersionedRange.swift
│
├── Features/
│   ├── Annotations/
│   │   ├── Annotation.swift
│   │   ├── AnnotationsContentView.swift
│   │   ├── AnnotationsDataSource.swift
│   │   ├── AnnotationView.swift
│   │   ├── CodeEditorViewAnnotation.swift
│   │   ├── LineAnnotation.swift
│   │   └── MessageLineAnnotation.swift
│   │
│   ├── CodeCompletion/
│   │   ├── Core/
│   │   │   ├── CompletionDebouncer.swift
│   │   │   ├── CompletionItem.swift
│   │   │   ├── CompletionItemModel.swift
│   │   │   ├── FuzzyMatcher.swift
│   │   │   └── SmartCompletionEngine.swift
│   │   └── UI/
│   │       ├── CompletionCellConfigurator.swift
│   │       ├── CompletionViewController.swift
│   │       ├── CompletionViewControllerBase.swift
│   │       ├── CompletionViewControllerDelegate.swift
│   │       └── CompletionViewControllerProtocol.swift
│   │
│   ├── CodeFolding/
│   │   └── CodeFoldingEngine.swift
│   │
│   ├── Debugging/
│   │   ├── DebugAdapter.swift
│   │   └── DebuggerIntegration.swift
│   │
│   ├── LSP/
│   │   ├── LSPClient.swift
│   │   ├── LSPCompletionProvider.swift
│   │   ├── LSPManager.swift
│   │   ├── LSPMessageHandler.swift
│   │   ├── LSPProtocol.swift
│   │   └── LSPTypes.swift
│   │
│   ├── Search/
│   │   └── SearchReplaceEngine.swift
│   │
│   ├── SmartEditing/
│   │   └── SmartEditingEngine.swift
│   │
│   ├── SymbolNavigation/
│   │   └── SymbolNavigator.swift
│   │
│   └── SyntaxHighlighting/
│       ├── AdaptiveColorSystem.swift
│       ├── AsyncSyntaxHighlighter.swift
│       ├── BackgroundSyntaxHighlighter.swift
│       ├── LanguageRegistry.swift
│       ├── RegexSyntaxHighlighter.swift
│       ├── SwiftSyntaxHighlighter.swift
│       ├── SyntaxHighlightingCoordinator.swift
│       ├── Theme.swift
│       ├── TokenName.swift
│       └── ViewportSyntaxCoordinator.swift
│
├── UI/
│   ├── Components/
│   │   ├── CodeEditorContainerView.swift
│   │   ├── CodeEditorContainerView+AppKit.swift
│   │   ├── CodeEditorContainerView+UIKit.swift
│   │   ├── ContainerViewHelper.swift
│   │   ├── ContentView.swift
│   │   ├── GutterCoordinator.swift
│   │   ├── GutterView.swift
│   │   ├── GutterViewRenderer.swift
│   │   ├── InsertionPointIndicatorProtocol.swift
│   │   ├── InsertionPointView.swift
│   │   ├── KeyboardCoordinator.swift
│   │   ├── LayoutCoordinator.swift
│   │   ├── LineHighlightView.swift
│   │   ├── MinimapCoordinator.swift
│   │   ├── MinimapView.swift
│   │   └── ScrollCoordinator.swift
│   │
│   └── SwiftUI/
│       ├── CodeEditor.swift
│       ├── CodeEditorBaseCoordinator.swift
│       └── CodeEditorTheme.swift
│
├── Configuration/
│   ├── ConfigurationHotReload.swift
│   ├── ConfigurationValidator.swift
│   ├── EditorConfiguration.swift
│   └── EditorConfigurationBuilder.swift
│
├── Platform/
│   ├── ContextMenuAction.swift
│   ├── CrossPlatformCoordinator.swift
│   ├── CrossPlatformCoordinator+AppKit.swift
│   ├── CrossPlatformCoordinator+UIKit.swift
│   ├── module.swift
│   ├── PlatformCapabilities.swift
│   ├── PlatformImports.swift
│   ├── README.md
│   ├── TextInputFeatures.swift
│   └── UnifiedDrawingCoordinator.swift
│
├── Shared/
│   ├── Events/
│   │   ├── EditorEvent.swift
│   │   └── UnifiedEventSystem.swift
│   │
│   ├── Extensions/
│   │   ├── CoreGraphics/
│   │   │   ├── CGPoint+Extensions.swift
│   │   │   ├── CGRect+Extensions.swift
│   │   │   └── EdgeInsets+Extensions.swift
│   │   ├── Foundation/
│   │   │   ├── Bundle+Extensions.swift
│   │   │   ├── IndexSet+Extensions.swift
│   │   │   └── String+Extensions.swift
│   │   ├── TextKit/
│   │   │   ├── NSParagraphStyle+Extensions.swift
│   │   │   ├── NSRange+Extensions.swift
│   │   │   ├── NSTextContentManager+Extensions.swift
│   │   │   ├── NSTextLayoutFragment+Extensions.swift
│   │   │   ├── NSTextLayoutManager+Extensions.swift
│   │   │   ├── NSTextLineFragment+Extensions.swift
│   │   │   ├── NSTextLocation+Extensions.swift
│   │   │   ├── NSTextRange+Extensions.swift
│   │   │   └── NSTextView+Extensions.swift
│   │   └── UI/
│   │       ├── CodeEditorView+Extensions.swift
│   │       ├── CodeEditorView+SelectionHandling.swift
│   │       ├── PlatformColor+Extensions.swift
│   │       ├── TextView+UnifiedExtensions.swift
│   │       └── View+OnChange.swift
│   │
│   ├── Languages/
│   │   ├── C/
│   │   ├── CSS/
│   │   ├── Go/
│   │   ├── HTML/
│   │   ├── Java/
│   │   ├── JavaScript/
│   │   ├── JSON/
│   │   ├── Markdown/
│   │   ├── PHP/
│   │   ├── Python/
│   │   ├── Ruby/
│   │   ├── Rust/
│   │   ├── Shell/
│   │   ├── SQL/
│   │   ├── Swift/
│   │   ├── XML/
│   │   └── YAML/
│   │
│   ├── Models/
│   │   ├── AttributedTextElement.swift
│   │   ├── MarkedText.swift
│   │   ├── NSTextSegmentType.swift
│   │   ├── RangeMutation.swift
│   │   ├── Token.swift
│   │   ├── Versioned.swift
│   │   └── VersionedContent.swift
│   │
│   └── Utilities/
│       ├── AsyncOperationManager.swift
│       ├── CoordinateSystemHelper.swift
│       ├── LRUCache.swift
│       ├── MemoryMonitor.swift
│       ├── PerformanceInsights.swift
│       ├── PerformanceMonitor.swift
│       ├── RangeUtilities.swift
│       ├── TextMetricsCalculator.swift
│       ├── UnifiedPerformanceSystem.swift
│       └── ViewportManager.swift
│
└── Documentation.docc/
    └── (all existing documentation files)
```
