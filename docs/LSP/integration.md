# LSP Integration

CodeEditorPlugin exposes Language Server Protocol primitives for IDE-style code intelligence. The current implementation has two surfaces:

- macOS local server management through `LSPManager` and process-backed language servers.
- Cross-platform remote server primitives through `LSPClient`, `LSPServerConfiguration.remote`, and `WebSocketTransport`.

## Platform Support

| Capability | macOS | iOS / iPadOS | Notes |
|---|:---:|:---:|---|
| Local process-backed LSP servers | ✅ | — | `LSPManager`, `LSPClientRegistry`, `LSPPathResolver`, and `ProcessTransport` are AppKit-gated. |
| Remote WebSocket LSP transport | ✅ | ✅ | `LSPClient`, `RemoteLSPConfiguration`, `LSPServerConfiguration`, and `WebSocketTransport` are all-platform. |
| `EditorConfiguration.workspaceRoot` | ✅ | ✅ | Stored on the editor configuration; local LSP server lifecycle currently consumes it through macOS `LSPManager`. |
| Sample app LSP UI | ✅ | — | macOS inspector probes common local language-server executables. |

Local LSP servers require `Process`, so they are unavailable on iOS. iOS apps that need LSP must connect to a remote WebSocket endpoint.

## Workspace Root

Set a workspace root for file-relative features and local server initialization:

```swift
var configuration = EditorConfiguration()
configuration.workspaceRoot = URL(fileURLWithPath: "/path/to/project")
```

In SwiftUI, use the environment or the provided modifier:

```swift
CodeEditor(text: $code)
    .codeLanguage(.swift)
    .codeWorkspaceRoot(projectURL)
```

## macOS Local Server Setup

`LSPManager` is the high-level macOS API for local language servers:

```swift
#if canImport(AppKit)
import CodeEditorPlugin

let memoryMonitor = MemoryMonitor()
let manager = LSPManager(
    memoryMonitor: memoryMonitor,
    workspaceRoot: projectURL
)

let swiftServer = LanguageServerConfig(
    languageId: "swift",
    serverPath: "sourcekit-lsp",
    fileExtensions: ["swift"],
    enablePathResolution: true
)

manager.registerLanguageServer(swiftServer)

if manager.isLanguageServerAvailable(swiftServer) {
    try await manager.startLanguageServer(for: "swift")
    try await manager.openDocument(
        filePath: fileURL.path,
        content: source,
        languageId: "swift"
    )
}
#endif
```

Request language features after a document is open:

```swift
#if canImport(AppKit)
let completions = try await manager.requestCompletion(
    filePath: fileURL.path,
    line: 10,
    character: 4
)

let hover = try await manager.requestHover(
    filePath: fileURL.path,
    line: 10,
    character: 4
)

let definitions = try await manager.requestDefinition(
    filePath: fileURL.path,
    line: 10,
    character: 4
)
#endif
```

## Remote Server Setup

Use `LSPClient` directly for remote servers:

```swift
import CodeEditorPlugin

let remote = RemoteLSPConfiguration.publicServer(
    url: URL(string: "wss://lsp.example.com/swift")!
)

let client = await LSPClient.createAndSetup()
try await client.connect(
    configuration: .remote(remote),
    language: .swift
)

try await client.openDocument(
    uri: "file:///workspace/Sources/App.swift",
    languageId: "swift",
    version: 1,
    text: source
)

let result = try await client.requestCompletion(
    uri: "file:///workspace/Sources/App.swift",
    position: Position(line: 10, character: 4)
)
```

For authenticated servers:

```swift
let remote = RemoteLSPConfiguration.privateServer(
    url: URL(string: "wss://lsp.example.com/typescript")!,
    token: token
)
```

Remote security options include bearer/basic/API-key authentication, custom headers, TLS validation, and certificate pinning.

## Common Local Servers

| Language | Server | Typical install |
|---|---|---|
| Swift | `sourcekit-lsp` | Bundled with Xcode toolchains |
| TypeScript / JavaScript | `typescript-language-server` | `npm install -g typescript-language-server typescript` |
| Python | `pylsp` | `pip install python-lsp-server` |
| Rust | `rust-analyzer` | `rustup component add rust-analyzer` |
| Go | `gopls` | `go install golang.org/x/tools/gopls@latest` |

`LSPPathResolver` checks absolute paths, environment overrides such as `LSP_SOURCEKIT_LSP_PATH`, `PATH`, and common install directories. See [path resolution](path-resolution.md).

## Current Scope

Implemented request helpers include:

- document open / change / close synchronization
- completion
- hover
- definition
- document symbols on `LSPClient`
- diagnostics storage from `textDocument/publishDiagnostics`

The framework does not yet ship a full editor UI for diagnostics, references, rename, code actions, formatting, or multi-root workspace management.

## iOS Guidance

For iOS, rely on local framework intelligence unless you have a remote LSP service:

```swift
var configuration = EditorConfiguration()
configuration.behavior.isCodeCompletionEnabled = true
configuration.workspaceRoot = projectURL
```

The local completion system still provides descriptor-backed completions for the 25 concrete language catalog plus the plain-text fallback. Use remote LSP only when your app can operate a secure WebSocket endpoint.

## Troubleshooting

### Server Not Found

- Confirm the executable is installed.
- Use `manager.resolveLanguageServerPath(config)` to see the resolved path.
- Set `LSP_<EXECUTABLE>_PATH` when the server is outside common install directories.
- Make sure `workspaceRoot` is set before starting the server.

### No Results

- Open the document with the manager/client before requesting features.
- Use zero-based line and character positions.
- Check that the language server supports the requested capability.
- Confirm the document URI is stable across open/change/request calls.

### iOS Local Server Errors

Local process-backed servers are not supported on iOS. Use `LSPServerConfiguration.remote` with `WebSocketTransport`, or rely on local completions.

## See Also

- [Path resolution](path-resolution.md)
- [Retry configuration](retry-configuration.md)
- [Feature matrix](../FeatureMatrix.md)
