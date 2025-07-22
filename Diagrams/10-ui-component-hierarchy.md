# UI Component Hierarchy

This diagram shows the visual component hierarchy and layout structure of the CodeEditorPlugin.

```mermaid
classDiagram
    direction LR
        
    %% Top Row - Container & Main Editor
    class CodeEditorContainerView {
        &lt;&lt;main container&gt;&gt;
        +frame CGRect
        +configuration EditorConfiguration
        +codeEditorView CodeEditorView
        +gutterView GutterView?
        +minimapView MinimapView?
        +scrollView NSScrollView
        +layoutSubviews()
        +updateConfiguration()
    }

    class CodeEditorView {
        &lt;&lt;text editor&gt;&gt;
        +textContainer NSTextContainer
        +layoutManager CodeEditorLayoutManager
        +textStorage NSTextStorage
        +selectionView SelectionView
        +cursorView CursorView
        +overlayViews [OverlayView]
    }

    class EditorScrollView {
        &lt;&lt;scroll management&gt;&gt;
        +contentView NSClipView
        +verticalScroller NSScroller
        +horizontalScroller NSScroller
        +hasVerticalScroller Bool
        +hasHorizontalScroller Bool
        +synchronizedScrollViews [NSScrollView]
    }

    %% Second Row - Gutter Components
    class GutterView {
        &lt;&lt;gutter container&gt;&gt;
        +width CGFloat
        +backgroundColor PlatformColor
        +lineNumberView LineNumberView
        +breakpointView BreakpointView
        +foldingView FoldingView
        +drawRect()
    }

    class LineNumberView {
        &lt;&lt;line numbers&gt;&gt;
        +font PlatformFont
        +textColor PlatformColor
        +currentLineHighlight Bool
        +drawLineNumbers()
    }

    class BreakpointView {
        &lt;&lt;breakpoints&gt;&gt;
        +breakpoints Set
        +breakpointColor PlatformColor
        +addBreakpoint()
        +removeBreakpoint()
        +drawBreakpoints()
    }

    %% Third Row - Minimap & Folding
    class MinimapView {
        &lt;&lt;minimap&gt;&gt;
        +width CGFloat
        +scale CGFloat
        +visibleRect CGRect
        +textRepresentation NSAttributedString
        +viewportIndicator ViewportIndicator
        +drawMinimap()
    }

    class ViewportIndicator {
        &lt;&lt;viewport indicator&gt;&gt;
        +rect CGRect
        +color PlatformColor
        +alpha CGFloat
        +drawIndicator()
    }

    class FoldingView {
        &lt;&lt;code folding&gt;&gt;
        +foldedRanges [NSRange]
        +foldingIndicatorColor PlatformColor
        +toggleFolding()
        +drawFoldingIndicators()
    }

    %% Fourth Row - Editor Overlays
    class SelectionView {
        &lt;&lt;selection overlay&gt;&gt;
        +selections [NSRange]
        +selectionColor PlatformColor
        +drawSelections()
    }

    class CursorView {
        &lt;&lt;cursor overlay&gt;&gt;
        +position CGPoint
        +width CGFloat
        +color PlatformColor
        +blinkRate TimeInterval
        +startBlinking()
        +stopBlinking()
    }

    class BracketMatchingView {
        &lt;&lt;bracket matching&gt;&gt;
        +matchedBrackets [Range]
        +highlightColor PlatformColor
        +drawMatches()
    }

    %% Fifth Row - Search & Annotations
    class SearchHighlightView {
        &lt;&lt;search highlights&gt;&gt;
        +searchResults [NSRange]
        +currentResult Int?
        +highlightColor PlatformColor
        +currentHighlightColor PlatformColor
    }

    class AnnotationContainerView {
        &lt;&lt;annotation container&gt;&gt;
        +annotations [CodeAnnotation]
        +annotationViews [AnnotationView]
        +addAnnotation()
        +removeAnnotation()
        +layoutAnnotations()
    }

    class AnnotationView {
        &lt;&lt;annotation&gt;&gt;
        +annotation CodeAnnotation
        +backgroundColor PlatformColor
        +borderColor PlatformColor
        +drawAnnotation()
    }

    %% Bottom Row - Status & Layout
    class StatusBarView {
        &lt;&lt;status bar&gt;&gt;
        +height CGFloat
        +backgroundColor PlatformColor
        +lineColumnLabel NSTextField
        +languageLabel NSTextField
        +encodingLabel NSTextField
        +updateStatus()
    }

    class LayoutConstraints {
        &lt;&lt;layout helper&gt;&gt;
        +gutterWidth CGFloat
        +minimapWidth CGFloat
        +statusBarHeight CGFloat
        +contentInsets EdgeInsets
        +calculateEditorFrame()
        +calculateGutterFrame()
        +calculateMinimapFrame()
    }

    %% Key Relationships - Hierarchy
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
    classDef container fill:#007AFF20,stroke:#007AFF,stroke-width:3px,color:#1D1D1F
    classDef editor fill:#AF52DE20,stroke:#AF52DE,stroke-width:2px,color:#1D1D1F
    classDef gutter fill:#34C75920,stroke:#34C759,stroke-width:2px,color:#1D1D1F
    classDef minimap fill:#007AFF20,stroke:#007AFF,stroke-width:2px,color:#1D1D1F
    classDef overlay fill:#FF3B3020,stroke:#FF3B30,stroke-width:2px,color:#1D1D1F
    classDef support fill:#8E8E9320,stroke:#8E8E93,stroke-width:2px,color:#1D1D1F
    
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
    classDef container fill:#007AFF20,stroke:#007AFF,color:#1D1D1F
    classDef gutter fill:#34C75920,stroke:#34C759,color:#1D1D1F
    classDef editor fill:#AF52DE20,stroke:#AF52DE,color:#1D1D1F
    classDef minimap fill:#007AFF20,stroke:#007AFF,color:#1D1D1F
    classDef status fill:#8E8E9320,stroke:#8E8E93,color:#1D1D1F
```

## Component Responsibilities

1. **Container View**: Manages overall layout and coordinates subviews
2. **Gutter View**: Displays line numbers, breakpoints, and folding controls
3. **Editor View**: Main text editing area with TextKit2 integration
4. **Minimap View**: Provides document overview and navigation
5. **Overlay Views**: Handle selections, cursor, and visual feedback
6. **Scroll View**: Manages scrolling and viewport synchronization
7. **Status Bar**: Shows current editor state and file information