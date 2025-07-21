# UI Component Hierarchy

This diagram shows the visual component hierarchy and layout structure of the CodeEditorPlugin.

```mermaid
classDiagram
    %% Container Views
    class CodeEditorContainerView {
        +frame: CGRect
        +configuration: EditorConfiguration
        +codeEditorView: CodeEditorView
        +gutterView: GutterView?
        +minimapView: MinimapView?
        +scrollView: NSScrollView
        +layoutSubviews()
        +updateConfiguration(EditorConfiguration)
    }

    %% Main Editor View
    class CodeEditorView {
        +textContainer: NSTextContainer
        +layoutManager: CodeEditorLayoutManager
        +textStorage: NSTextStorage
        +selectionView: SelectionView
        +cursorView: CursorView
        +overlayViews: [OverlayView]
    }

    %% Gutter Components
    class GutterView {
        +width: CGFloat
        +backgroundColor: PlatformColor
        +lineNumberView: LineNumberView
        +breakpointView: BreakpointView
        +foldingView: FoldingView
        +drawRect(CGRect)
    }

    class LineNumberView {
        +font: PlatformFont
        +textColor: PlatformColor
        +currentLineHighlight: Bool
        +drawLineNumbers(in: CGRect, for: NSRange)
    }

    class BreakpointView {
        +breakpoints: Set~Int~
        +breakpointColor: PlatformColor
        +addBreakpoint(at: Int)
        +removeBreakpoint(at: Int)
        +drawBreakpoints(in: CGRect)
    }

    class FoldingView {
        +foldedRanges: [NSRange]
        +foldingIndicatorColor: PlatformColor
        +toggleFolding(at: Int)
        +drawFoldingIndicators(in: CGRect)
    }

    %% Minimap Components
    class MinimapView {
        +width: CGFloat
        +scale: CGFloat
        +visibleRect: CGRect
        +textRepresentation: NSAttributedString
        +viewportIndicator: ViewportIndicator
        +drawMinimap()
    }

    class ViewportIndicator {
        +rect: CGRect
        +color: PlatformColor
        +alpha: CGFloat
        +drawIndicator()
    }

    %% Editor Overlays
    class SelectionView {
        +selections: [NSRange]
        +selectionColor: PlatformColor
        +drawSelections()
    }

    class CursorView {
        +position: CGPoint
        +width: CGFloat
        +color: PlatformColor
        +blinkRate: TimeInterval
        +startBlinking()
        +stopBlinking()
    }

    class BracketMatchingView {
        +matchedBrackets: [(NSRange, NSRange)]
        +highlightColor: PlatformColor
        +drawMatches()
    }

    class SearchHighlightView {
        +searchResults: [NSRange]
        +currentResult: Int?
        +highlightColor: PlatformColor
        +currentHighlightColor: PlatformColor
    }

    %% Scroll Management
    class EditorScrollView {
        +contentView: NSClipView
        +verticalScroller: NSScroller
        +horizontalScroller: NSScroller
        +hasVerticalScroller: Bool
        +hasHorizontalScroller: Bool
        +synchronizedScrollViews: [NSScrollView]
    }

    %% Annotation System
    class AnnotationContainerView {
        +annotations: [CodeAnnotation]
        +annotationViews: [AnnotationView]
        +addAnnotation(CodeAnnotation)
        +removeAnnotation(CodeAnnotation)
        +layoutAnnotations()
    }

    class AnnotationView {
        +annotation: CodeAnnotation
        +backgroundColor: PlatformColor
        +borderColor: PlatformColor
        +drawAnnotation()
    }

    %% Status Bar
    class StatusBarView {
        +height: CGFloat
        +backgroundColor: PlatformColor
        +lineColumnLabel: NSTextField
        +languageLabel: NSTextField
        +encodingLabel: NSTextField
        +updateStatus()
    }

    %% Layout Constraints
    class LayoutConstraints {
        +gutterWidth: CGFloat
        +minimapWidth: CGFloat
        +statusBarHeight: CGFloat
        +contentInsets: EdgeInsets
        +calculateEditorFrame() CGRect
        +calculateGutterFrame() CGRect
        +calculateMinimapFrame() CGRect
    }

    %% Relationships - Hierarchy
    CodeEditorContainerView *-- CodeEditorView : contains
    CodeEditorContainerView *-- GutterView : contains
    CodeEditorContainerView *-- MinimapView : contains
    CodeEditorContainerView *-- EditorScrollView : contains
    CodeEditorContainerView *-- StatusBarView : contains
    
    GutterView *-- LineNumberView : contains
    GutterView *-- BreakpointView : contains
    GutterView *-- FoldingView : contains
    
    MinimapView *-- ViewportIndicator : contains
    
    CodeEditorView *-- SelectionView : contains
    CodeEditorView *-- CursorView : contains
    CodeEditorView *-- BracketMatchingView : overlay
    CodeEditorView *-- SearchHighlightView : overlay
    CodeEditorView *-- AnnotationContainerView : overlay
    
    AnnotationContainerView *-- AnnotationView : manages
    
    EditorScrollView --> CodeEditorView : scrolls
    EditorScrollView --> MinimapView : synchronizes
    
    CodeEditorContainerView --> LayoutConstraints : uses

    %% Styling - Dark mode friendly colors
    classDef container fill:#6366f120,stroke:#6366f1,stroke-width:3px,color:#fff
    classDef editor fill:#8b5cf620,stroke:#8b5cf6,stroke-width:2px,color:#fff
    classDef gutter fill:#10b98120,stroke:#10b981,stroke-width:2px,color:#fff
    classDef minimap fill:#3b82f620,stroke:#3b82f6,stroke-width:2px,color:#fff
    classDef overlay fill:#ec489920,stroke:#ec4899,stroke-width:2px,color:#fff
    classDef support fill:#6b728020,stroke:#6b7280,stroke-width:2px,color:#fff
    
    class CodeEditorContainerView container
    class CodeEditorView editor
    class GutterView gutter
    class LineNumberView gutter
    class BreakpointView gutter
    class FoldingView gutter
    class MinimapView minimap
    class ViewportIndicator minimap
    class SelectionView overlay
    class CursorView overlay
    class BracketMatchingView overlay
    class SearchHighlightView overlay
    class AnnotationContainerView overlay
    class AnnotationView overlay
    class EditorScrollView support
    class StatusBarView support
    class LayoutConstraints support
```

## Layout Structure

```mermaid
graph TB
    subgraph "Window/View Controller"
        subgraph "CodeEditorContainerView"
            subgraph "Left: Gutter"
                LN[Line Numbers]
                BP[Breakpoints]
                FOLD[Folding Controls]
            end
            
            subgraph "Center: ScrollView"
                subgraph "CodeEditorView"
                    TEXT[Text Content]
                    SEL[Selection Overlay]
                    CURSOR[Cursor Overlay]
                    MATCH[Bracket Matching]
                    SEARCH[Search Highlights]
                    ANN[Annotations]
                end
            end
            
            subgraph "Right: Minimap"
                MINI[Minimap Content]
                VP[Viewport Indicator]
            end
            
            subgraph "Bottom: Status Bar"
                POS[Line:Column]
                LANG[Language]
                ENC[Encoding]
            end
        end
    end

    %% Styling - Dark mode friendly colors
    classDef container fill:#6366f120,stroke:#6366f1,color:#fff
    classDef gutter fill:#10b98120,stroke:#10b981,color:#fff
    classDef editor fill:#8b5cf620,stroke:#8b5cf6,color:#fff
    classDef minimap fill:#3b82f620,stroke:#3b82f6,color:#fff
    classDef status fill:#6b728020,stroke:#6b7280,color:#fff
```

## Component Responsibilities

1. **Container View**: Manages overall layout and coordinates subviews
2. **Gutter View**: Displays line numbers, breakpoints, and folding controls
3. **Editor View**: Main text editing area with TextKit2 integration
4. **Minimap View**: Provides document overview and navigation
5. **Overlay Views**: Handle selections, cursor, and visual feedback
6. **Scroll View**: Manages scrolling and viewport synchronization
7. **Status Bar**: Shows current editor state and file information