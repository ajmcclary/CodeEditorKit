# Service Architecture Diagram

Runtime infrastructure is replaceable without recreating feature owners. `MemoryManagementCoordinator` rebinds monitor-aware components, and `EditorSession` owns attach/detach order.

```mermaid
flowchart LR
    HOST[Host / SwiftUI Environment] --> RUNTIME[EditorRuntimeDependencies]
    RUNTIME --> BUS[EditorEventBus]
    RUNTIME --> MONITOR[MemoryMonitor]
    RUNTIME --> WORKSPACE[Workspace Root]
    RUNTIME --> POLICY[MemoryManagementPolicy]

    VIEW[CodeEditorView] --> SESSION[EditorSession]
    VIEW --> RUNTIME
    VIEW --> MEMORY[MemoryManagementCoordinator]
    MEMORY --> MONITOR
    MEMORY --> HIGHLIGHT[AsyncSyntaxHighlighter]
    MEMORY --> COMPLETION[CompletionManager]
    MEMORY --> LSP[LSPManager]

    SESSION --> HC[HighlightingController]
    SESSION --> CC[EditorCompletionController]
    SESSION --> FC[EditorFoldingController]
    SESSION --> LC[LSPDocumentController]

    RUNTIME -. rebind .-> MEMORY
    MEMORY -. setMemoryMonitor .-> HIGHLIGHT
    MEMORY -. setMemoryMonitor .-> COMPLETION
    MEMORY -. setMemoryMonitor .-> LSP
```
