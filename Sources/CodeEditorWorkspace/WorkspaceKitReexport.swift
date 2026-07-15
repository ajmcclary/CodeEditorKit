// CodeEditorWorkspace is now a compatibility shim over the promoted
// top-level WorkspaceKit package (workspace decomposition step 5).
// The contracts (WorkspaceFileNode, WorkspaceFileEvent, WorkspaceFileTree,
// WorkspaceFileWatching) and the MacOSWorkspaceFileManager adapter moved
// there verbatim. Existing consumers keep `import CodeEditorWorkspace`;
// new code should import WorkspaceKit directly.
@_exported import WorkspaceKit
