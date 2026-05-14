# LSP iOS Coverage — Design

**Status:** Approved, ready for implementation plan.
**Date:** 2026-05-14
**Closes:** The final open item from `REVIEW.md` ("LSP iOS coverage" at L275, L495, L588) — `LSPClient` docstrings claim "remote servers on iOS" while the surrounding LSP modules are wrapped in `#if canImport(AppKit)`.

## Problem

`Sources/CodeEditorPlugin/LSP/LSPClient.swift:19-25` promises:

> - macOS: Full support for both local and remote LSP servers
> - iOS / iPadOS: Remote LSP servers only (via WebSocket transport)

In reality only `LSPClient` itself and `WebSocketTransport` are cross-platform. Every module that hosts LSP integration — `LSPManager`, `LSPClientRegistry`, `LSPCompletionProvider`, `LSPDocumentManager`, `LSPContentCoordinator`, `LSPSemanticTokenProvider`, `LSPPathResolver` — is gated `#if canImport(AppKit)`, even though only `LSPProcessManager` and `ProcessTransport` truly require AppKit. iOS hosts cannot instantiate `LSPManager`, so the docstring is fictional.

A secondary lie compounds it: `IOSRootView`'s `.inspectors` `ContentUnavailableView` (added 2026-05-14) tells the user "`LSPManager`, `CompletionManager`, `PerformanceInsights`, `AnnotationsHub` do work on iOS; only the sample's chrome is desktop-only." `LSPManager` does not exist on iOS today.

## Goal

Make iOS LSP support real for the remote-WebSocket flow. Keep `Process`-spawning macOS-only. Match the docstrings.

## Non-goals

- A sample-side iOS LSP demo. The sample's `LSPSampleCoordinator` stays `#if canImport(AppKit)`. iOS gets a corrected inspector copy instead.
- `LSPPathResolver` on iOS. iOS apps are sandboxed; PATH-style resolution is not meaningful. The resolver stays AppKit-gated.
- `Process` on iOS. `LSPProcessManager`, `ProcessTransport`, and `LSPClient.connectLegacy(...)` stay AppKit-only.
- New public error types. Existing `LSPError` / `LSPTransportError` carry the new messages.
- Authentication or transport features beyond what `RemoteLSPConfiguration` + `WebSocketTransport` already support.

## Approach

Two changes, both small in code, one with non-trivial reach across files:

1. **Extend `LanguageServerConfig` with optional remote-server fields** plus two factory inits (`.local(...)` and `.remote(...)`). Mutual exclusion is enforced by the factories — the existing positional initializer remains and constructs a local-shaped config for source compatibility.
2. **Drop the `#if canImport(AppKit)` gate from the LSP modules that don't actually use AppKit**, and migrate `LSPClientRegistry.startLanguageServer(for:)` from the legacy `LSPClient.connect(configuration: ServerConfiguration)` flow to the modern `LSPClient.connect(configuration: LSPServerConfiguration)` overload. `LSPServerConfiguration.createTransport()` already routes `.local` to `ProcessTransport` (AppKit-gated) and `.remote` to `WebSocketTransport` (cross-platform).

After this, on iOS:
- `LSPManager`, `LSPClientRegistry`, `LSPCompletionProvider`, `LSPDocumentManager`, `LSPContentCoordinator`, `LSPSemanticTokenProvider` compile and work for `.remote` configs.
- `LSPPathResolver`, `LSPProcessManager`, `ProcessTransport`, `LSPClient.connectLegacy(...)` remain AppKit-only.
- Registering a `.local(...)` config and starting it on iOS throws a clear `LSPError` instead of silently failing to compile.

## Surface changes

### `Sources/CodeEditorPlugin/LSP/LSPManagerTypes.swift` — `LanguageServerConfig`

```swift
public struct LanguageServerConfig: Sendable {
    public let languageId: String
    public let fileExtensions: [String]
    public let capabilities: ClientCapabilities
    public let autoStart: Bool
    public let retryConfiguration: LSPRetryConfiguration

    // Local-server fields. `serverPath == ""` on remote-shaped configs.
    public let serverPath: String
    public let serverArguments: [String]
    public let enablePathResolution: Bool

    // Remote-server fields. `remoteURL == nil` on local-shaped configs.
    public let remoteURL: URL?
    public let remoteHeaders: [String: String]
    public let remoteAuthentication: LSPAuthentication?
    public let remoteTransportConfiguration: LSPTransportConfiguration?

    // Existing positional init kept for source compatibility — constructs a local-shaped config.
    public init(
        languageId: String,
        serverPath: String,
        fileExtensions: [String],
        serverArguments: [String] = [],
        capabilities: ClientCapabilities = .default,
        autoStart: Bool = true,
        enablePathResolution: Bool = true,
        retryConfiguration: LSPRetryConfiguration = .default
    )

    // New factories — the canonical way to construct configs going forward.
    public static func local(
        languageId: String,
        serverPath: String,
        fileExtensions: [String],
        serverArguments: [String] = [],
        capabilities: ClientCapabilities = .default,
        autoStart: Bool = true,
        enablePathResolution: Bool = true,
        retryConfiguration: LSPRetryConfiguration = .default
    ) -> Self

    public static func remote(
        languageId: String,
        url: URL,
        fileExtensions: [String],
        headers: [String: String] = [:],
        authentication: LSPAuthentication? = nil,
        transportConfiguration: LSPTransportConfiguration? = nil,
        capabilities: ClientCapabilities = .default,
        autoStart: Bool = true,
        retryConfiguration: LSPRetryConfiguration = .default
    ) -> Self

    /// Translates to the modern transport-typed configuration.
    /// Throws on iOS for local-shaped configs.
    internal func makeServerConfiguration(workspaceRoot: URL) throws -> LSPServerConfiguration
}
```

`LSPAuthentication` already exists in `RemoteLSPConfiguration.swift` (line 145+; cases include `.noAuth`, `.bearerToken`, `.apiKey`, `.custom`). `LSPTransportConfiguration` already exists in `Transport/LSPTransport.swift` (line 99). `RemoteLSPConfiguration` (line 17) takes `serverURL`, `authentication`, `reconnectPolicy`, `customHeaders`, `transportConfiguration`, etc. — no `languageId` parameter. We reuse them.

### Gating moves

| File | Today | After |
|---|---|---|
| `LSP/LSPManager.swift` | `#if canImport(AppKit)` over whole file | un-gated |
| `LSP/LSPClientRegistry.swift` | gated | un-gated; `pathResolver` field becomes `#if canImport(AppKit)`-only |
| `LSP/LSPCompletionProvider.swift` | gated | un-gated |
| `LSP/LSPDocumentManager.swift` | gated | un-gated |
| `LSP/LSPContentCoordinator.swift` | gated | un-gated |
| `LSP/LSPSemanticTokenProvider.swift` | gated | un-gated |
| `LSP/LSPPathResolver.swift` | gated | **stays gated** (macOS-only) |
| `LSP/LSPProcessManager.swift` | partial gating | **stays gated** (Process API) |
| `LSP/LSPClient.swift` `connectLegacy` extension at L537-573 | gated | **deleted** — zero callers in tree today; the registry never used it |
| `LSP/Transport/ProcessTransport.swift` | gated | unchanged |

`LSPClient.processManager` (an unconditionally-stored `private lazy var` at `LSPClient.swift:99`) already compiles on iOS today because `LSPProcessManager` ships `#else` stubs at `LSPProcessManager.swift:124-152` (`startServerProcess` throws, `terminateServerProcess` is a no-op, `sendMessage` throws, `isRunning` returns false). No platform-gating needed inside `LSPClient`. The legacy `connect(configuration: ServerConfiguration)` at `LSPClient.swift:138` is already transport-aware (`LSPClient.swift:146`: `if transport != nil { use transport } else { processManager.startServerProcess(...) }`) — the registry's migration just has to ensure `self.transport` is set before calling it.

### `LSPClient.connect(configuration:, language:)` overload simplification

`LSPClient+Transport.swift:18` defines:

```swift
public func connect(configuration: LSPServerConfiguration, language: Language) async throws
```

The `language: Language` parameter is used only to extract `language.lspIdentifier: String` and stuff it into the synthesized `ServerConfiguration.languageId`. Zero in-tree callers (verified via `grep`). Change the public signature to:

```swift
public func connect(configuration: LSPServerConfiguration, languageId: String) async throws
```

The body becomes a one-line edit: `baseConfig.languageId = languageId` instead of `language.lspIdentifier`. This makes the registry's migration trivial because `LSPClientRegistry` keys configs by `languageId: String` and has no `Language` enum on hand.

### `LSPClientRegistry.startLanguageServer(for:)` migration

Today:

```swift
let client = await LSPClient.createAndSetup()
let serverConfig = LSPClient.ServerConfiguration(
    languageId: languageId,
    serverPath: resolvedServerPath,
    workspaceRoot: workspaceRoot,
    serverArguments: config.serverArguments,
    capabilities: config.capabilities
)
try await client.connect(configuration: serverConfig)
```

After:

```swift
let client = await LSPClient.createAndSetup()
let serverConfig = try config.makeServerConfiguration(workspaceRoot: workspaceRoot)
try await client.connect(configuration: serverConfig, languageId: languageId)
```

The modern overload (post-simplification) sets `self.transport` from `serverConfig.createTransport()`, then delegates to the legacy `connect(configuration: ServerConfiguration)` at `LSPClient.swift:138`. Because `self.transport` is now non-nil, the legacy `connect` takes the transport branch at L146 and bypasses `processManager.startServerProcess(...)` entirely. On iOS with `.remote`, that means `WebSocketTransport` handles the connection; on macOS with `.local`, `ProcessTransport`.

The local-vs-remote branch — including the `pathResolver.resolvePath(_:)` call gated behind `#if canImport(AppKit)` — moves inside `makeServerConfiguration` and the surrounding helpers, not the registry's hot path. `enablePathResolution` is consulted inside the macOS `#if` arm of `makeServerConfiguration` so the resolver call never compiles on iOS.

`isLanguageServerAvailable(_:)` and `resolveLanguageServerPath(_:)` get platform branches: macOS retains the resolver call; iOS short-circuits to `config.remoteURL != nil ? true : false` for `isAvailable` and `nil` for `resolveLanguageServerPath`.

### Docstring corrections

- `Sources/CodeEditorPlugin/LSP/LSPClient.swift:19-25` — preserve the platform-support paragraph; rewrite the example code block to use `LanguageServerConfig.remote(url:)` rather than `LSPServerConfiguration.remote(...)` (the public-facing path now goes through `LanguageServerConfig`).
- `Sources/CodeEditorPlugin/LSP/LSPManager.swift:9-71` — drop the `// LSP functionality is only available on macOS` comment at L2; add the same Platform Support block as `LSPClient`.
- `Sources/CodeEditorPlugin/LSP/Transport/WebSocketTransport.swift:1-24` — unchanged.
- `Sources/CodeEditorSample/iOS/IOSRootView.swift` — `inspectors` `ContentUnavailableView` copy adjusted to say "Remote LSP servers work on iOS — use `LanguageServerConfig.remote(url:)` with `LSPManager`. The inspector chrome that lives in `Sources/CodeEditorSample/Sidebars/` is desktop-only. Local servers require AppKit."

## Data flow & lifecycle

**Bootstrap (both platforms):** Host constructs `LSPManager(memoryMonitor:, workspaceRoot:)` and calls `registerLanguageServer(.remote(...))` (or `.local(...)` on macOS). `LSPClientRegistry.registerLanguageServer(_:)` stores the config and, if `autoStart`, calls `startLanguageServer(for:)`.

**Start path:** registry resolves the modern transport-typed configuration via `config.makeServerConfiguration(workspaceRoot:)`, creates an `LSPClient` via `createAndSetup()`, and calls `client.connect(configuration: LSPServerConfiguration)`. `createTransport()` returns `ProcessTransport` (macOS, local) or `WebSocketTransport` (any platform, remote). `LSPClient` installs the data handler, runs the init handshake, transitions to `.initialized`.

**Document sync, completion, semantic tokens:** unchanged. `LSPDocumentManager.openDocument(...)` routes to the right `LSPClient` via the registry; `LSPCompletionProvider` calls `LSPManager.requestCompletion(...)`; `LSPSemanticTokenProvider` requests semantic tokens — all transport-agnostic.

**Retry / reconnect (unchanged, documented):** Two layers, different surfaces.
- Registry: `LSPRetryConfiguration` retries the initial connect (covers process-spawn failure on macOS and WebSocket-handshake failure everywhere).
- Transport: `WebSocketTransport.attemptReconnection()` retries mid-session disconnects with exponential backoff.

**Memory monitor cleanup:** unchanged. `LSPManager.init` registers a `MemoryMonitor` cleanup handler; the handler logic is already platform-agnostic.

## Error handling

| Trigger | Where | Message |
|---|---|---|
| iOS host registers a `.local(...)` config and `autoStart`/`startLanguageServer(for:)` fires | `LSPClientRegistry.startLanguageServer` → `config.makeServerConfiguration` `#else` branch | `LSPError.serverError(code: -1, message: "Local language servers require AppKit (macOS). Use LanguageServerConfig.remote(...) for iOS.", data: nil)` |
| Bad URL on `.remote` connect | `WebSocketTransport.connect()` | `LSPTransportError.connectionFailed(underlying:)` — wrapped by retry loop |
| WebSocket mid-session disconnect | `WebSocketTransport.startReceiving` | Auto-reconnect; if exhausted, in-flight continuations fail via `LSPClient.disconnect()` (existing path, fixed in the Concurrency batch) |
| `enablePathResolution: true` on iOS | `makeServerConfiguration` `#else` branch | Same `LSPError.serverError` as above; the resolver is never invoked on iOS |

No new public error types. `LSPError`, `LSPTransportError`, and `CodeEditorError.languageServerNotAvailable(_:)` carry the new copy.

## Testing

Three new files. All cross-platform unless noted.

### 1. `Tests/CodeEditorPluginTests/LSP/LanguageServerConfigFactoryTests.swift`

Swift Testing. Covers the `LanguageServerConfig` factory + `makeServerConfiguration` invariants.

- `LanguageServerConfig.local(...)` produces a config with `remoteURL == nil` and a populated `serverPath`.
- `LanguageServerConfig.remote(url:)` produces a config with `remoteURL != nil` and `serverPath == ""`.
- The existing positional `init(languageId:serverPath:fileExtensions:…)` produces a local-shaped config (compat assertion).
- `makeServerConfiguration(workspaceRoot:)` on a remote-shaped config returns `.remote(_)` regardless of platform.
- `makeServerConfiguration(workspaceRoot:)` on a local-shaped config:
  - macOS (`#if canImport(AppKit)`): returns `.local(_)` whose `LocalLSPConfiguration.executablePath` matches the input `serverPath`.
  - iOS (`#else`): throws `LSPError.serverError` whose `message` contains "AppKit".

### 2. `Tests/CodeEditorPluginTests/LSP/LSPManagerIOSCoverageTests.swift`

Swift Testing, iOS-only (`#if !canImport(AppKit)`; compiles to empty on macOS). Pure compile-time + smoke-test surface.

- `LSPManager(memoryMonitor: MemoryMonitor.mock(), workspaceRoot: nil)` initializes.
- `lspManager.registerLanguageServer(.remote(languageId: "swift", url: ..., fileExtensions: ["swift"]))` succeeds and the config appears in `serverConfigurations`.
- `lspManager.registerLanguageServer(.local(languageId: "swift", serverPath: "/nope", fileExtensions: ["swift"]))` followed by `lspManager.startLanguageServer(for: "swift")` throws an `LSPError` whose message contains "AppKit" or "remote".
- `LSPCompletionProvider(lspManager:)` initializes without crashing.
- `LSPSemanticTokenProvider(lspManager:, filePath: "/tmp/x.swift")` initializes.
- `LSPDocumentManager` and `LSPContentCoordinator` initialize.

### 3. `Tests/CodeEditorPluginTests/LSP/LSPClientRegistryRemoteFlowTests.swift`

XCTest, cross-platform. Verifies the registry's migration off `connectLegacy`. Requires a small testable seam — a closure or protocol injected into `LSPClientRegistry` that lets the test substitute an `LSPClient` whose `connect(configuration:)` records its argument.

- Given a remote-shaped `LanguageServerConfig`, `startLanguageServer(for:)` calls `client.connect(configuration:)` with a `.remote(_)` payload (not `.local(_)`), regardless of platform.
- On macOS only (`#if canImport(AppKit)`), the same test against a local-shaped config asserts the `.local(_)` payload.

If introducing the testable seam is heavier than expected, this test gets a follow-up issue and we ship without it; the first two tests still cover the iOS-side correctness.

### Existing tests

- `Tests/CodeEditorSampleTests/LSPSampleCoordinatorStateTests.swift` stays `#if canImport(AppKit)`. The pre-existing failure (`resolverFailureTransitionsToFailed`) documented in `REVIEW.md` carries forward.
- `Tests/CodeEditorPluginTests/LSPClientTests.swift` — if any test calls `client.connectLegacy(...)`, migrate to `client.connect(configuration: LSPServerConfiguration)`. The legacy entry point is deleted.
- The other documented pre-existing failures (`EditorStatusBarSnapshots/*` parallel SIGSEGV, `RegexRangeHighlightProviderTests.testParsePerformance100KLines`, etc.) are unrelated.

## Verification

- `swift build` (macOS): green.
- `swift build` targeting iOS-simulator: **green** — this is the new must-pass. Today no one runs the iOS-targeted build because LSP is AppKit-gated; flipping the gates requires actually compiling against the iOS SDK.
- `swiftlint --strict`: green.
- `swift test --parallel`: no regressions beyond the documented pre-existing failures.

## Open questions

None. The framing, registration API, module scope, and invariant strategy were all decided during brainstorming.

## Risk register

- **`LSPClient.connect(configuration:)` overload pair stays.** `LSPClient` will continue to expose both `connect(configuration: ServerConfiguration)` (legacy, transport-aware) and `connect(configuration: LSPServerConfiguration, languageId: String)` (modern, delegates to legacy). The legacy overload is *not* deletable — it's the load-bearing connect path; the modern overload sets `self.transport` and falls through to it. This is fine, just worth recording so a future cleanup doesn't blindly drop the "legacy" one.
- **iOS-simulator build was never gated by CI.** Spinning it up may surface latent issues unrelated to LSP. If unrelated breakage appears, scope it out — this work fixes only the LSP-iOS path. The build command lives in the Verification section above.
- **WebSocket reconnect under sandboxed iOS.** `WebSocketTransport` was written cross-platform but never exercised under iOS background-app-suspend semantics. The reconnect loop assumes the app stays foregrounded long enough to retry. If a test surfaces unexpected suspend-time behavior, it's a follow-up — not in scope for this work.
