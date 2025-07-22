# Package Dependencies - CodeEditorSample

This diagram shows the package dependencies for the CodeEditorSample demonstration app.

## Default View (Executable and Dependencies)

```mermaid
flowchart LR
    CodeEditorSample([CodeEditorSample])
```

## Complete View (Including Test Targets)

```mermaid
flowchart LR
    CodeEditorSample([CodeEditorSample])
    CodeEditorSampleTests{{CodeEditorSampleTests}}-->CodeEditorSample
```

## Horizontal Layout with All Components

```mermaid
flowchart LR
    CodeEditorSample([CodeEditorSample])-->CodeEditorPlugin[[CodeEditorPlugin]]
    CodeEditorSampleTests{{CodeEditorSampleTests}}-->CodeEditorPlugin[[CodeEditorPlugin]]
    CodeEditorSampleTests{{CodeEditorSampleTests}}-->CodeEditorSample
```
