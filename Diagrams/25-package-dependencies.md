# Package Dependencies - CodeEditorPlugin

This diagram shows the package dependencies for the main CodeEditorPlugin framework.

## Default View (Products Only)

```mermaid
flowchart LR
    CodeEditorPlugin-->SwiftParser[[SwiftParser]]
    CodeEditorPlugin-->SwiftSyntax[[SwiftSyntax]]
```

## Complete View (Including Test Targets)

```mermaid
flowchart LR
    CodeEditorPlugin
    CodeEditorPluginTests{{CodeEditorPluginTests}}-->CodeEditorPlugin
```

## Horizontal Layout

```mermaid
flowchart LR
    CodeEditorPlugin-->SwiftParser[[SwiftParser]]
    CodeEditorPlugin-->SwiftSyntax[[SwiftSyntax]]
```
