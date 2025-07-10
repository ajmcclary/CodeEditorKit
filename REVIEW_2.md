# REVIEW 2

## Code Review

### 1. `EditorEventPublisher` Concurrency

**File:** `Sources/CodeEditorPlugin/Core/EditorEvent.swift`  
Lines 296–364 define `EditorEventPublisher` using `NSLock` and `@unchecked Sendable`:

    302  public final class EditorEventPublisher: @unchecked Sendable {
    303      private let lock = NSLock()
    304      private var handlers: [ObjectIdentifier: WeakHandler] = [:]
    ...
    343      public func publish(_ event: EditorEvent) {
    344          lock.lock()
    345          let activeHandlers = handlers.values.compactMap { $0.value }
    346          lock.unlock()
    347
    348          // Publish to all active handlers
    349          for handler in activeHandlers {
    350              Task { @MainActor in
    351                  handler.handle(event)
    352              }
    353          }
    354      }


    **Issue:** Using locks with @unchecked Sendable can lead to subtle race conditions. An actor-based publisher would provide stronger safety and cleaner concurrency.

    Suggested taskRefactor EditorEventPublisher as an actor

    Start task

    ### 2. Duplicate SwiftUI Representations

    **Files:**
    Sources/CodeEditorPlugin/SwiftUI/CodeEditor+AppKit.swift
    Sources/CodeEditorPlugin/SwiftUI/CodeEditor+UIKit.swift

    Both files declare nearly identical CodeEditorRepresentable structs (lines 8–108 in each file) for AppKit and UIKit

    **Issue:** The duplicated logic makes maintenance harder.

    Suggested taskUnify CodeEditorRepresentable implementations

    Start task

    ### 3. becomeFirstResponder() API Flexibility

    **File:** Sources/CodeEditorPlugin/SwiftUI/CodeEditor+Modifiers.swift
    Lines 396–413 expose a modifier with no parameter:


    411  public func becomeFirstResponder() -> some View {
    412      environment(\.codeEditorBecomeFirstResponder, true)
    413  }


    **Issue:** Callers cannot easily toggle or reset this state.

    Suggested taskAllow boolean parameter for focus modifier

    Start task

    ### 4. CodeEditorView Class Openness

    **File:** Sources/CodeEditorPlugin/Core/CodeEditorView.swift
    The class is declared open (line 118):


    118  open class CodeEditorView: PlatformTextView, NSTextLayoutManagerDelegate, ...


    **Issue:** If subclassing is not explicitly supported, exposing open increases API surface and maintenance burden.

    Suggested taskEvaluate final vs. open for CodeEditorView

    Start task

    ### 5. Testing Environment Injection

    Existing tests focus on configuration and performance but do not cover injecting MemoryMonitor or custom UnifiedEventSystem via the SwiftUI environment.

    **Issue:** Lack of integration tests for these environment-based features may hide regressions.

    Suggested taskAdd tests for environment-based configuration

    Start task

    ### 6. Clarify Theme Builder Behavior

    **File:** Sources/CodeEditorPlugin/Configuration/EditorConfigurationBuilder+Convenience.swift
    Lines 10–36 implement theme(_:) but only adjust other flags:


    14    public func theme(_ theme: CodeEditorSwiftUITheme) -> Self {
    ...
    21      if theme.name == "dark" {
    22        builder = builder
    23          .highlightSelectedLine(true)
    24          .enableSyntaxHighlighting(true)


    **Issue:** This method does not actually apply colors and may confuse users.

    Suggested taskDocument or enhance theme() builder method

    Start task

    * * *

    ## Summary

    These changes aim to improve concurrency safety, reduce duplication, clarify API usage, restrict the public surface, and strengthen test coverage. Implementing them will further polish the already well‑structured CodeEditorPlugin project.
