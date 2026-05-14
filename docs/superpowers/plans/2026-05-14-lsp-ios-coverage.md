# LSP iOS Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make iOS LSP support real for the remote-WebSocket flow. Un-gate the LSP modules that don't actually use AppKit (`LSPManager`, `LSPClientRegistry`, `LSPCompletionProvider`, `LSPDocumentManager`, `LSPContentCoordinator`, `LSPSemanticTokenProvider`), keep `LSPPathResolver` / `LSPProcessManager` / `ProcessTransport` / `LSPClient.connectLegacy` macOS-only, and migrate `LSPClientRegistry.startLanguageServer(for:)` to the modern `LSPClient.connect(configuration: LSPServerConfiguration, languageId: String)` overload so `.remote(...)` configs flow over the existing cross-platform `WebSocketTransport`. Docstrings and the `IOSRootView` inspector copy stop lying.

**Architecture:** Extend `LanguageServerConfig` with optional remote fields plus `.local(...)` / `.remote(...)` factory inits. Drop the `#if canImport(AppKit)` gate from six LSP modules; gate only the resolver field inside `LSPClientRegistry`. Simplify the modern `LSPClient.connect(configuration:, language: Language)` overload to take `languageId: String` (zero in-tree callers — verified). The legacy `connect(configuration: ServerConfiguration)` at `LSPClient.swift:138` is already transport-aware (`if transport != nil { use transport } else { processManager }`) so once the registry sets `self.transport` via `LSPServerConfiguration.createTransport()`, both platforms route correctly. Delete the dead `connectLegacy` extension (`LSPClient.swift:535-573`).

**Tech Stack:** Swift 6.3 (`StrictConcurrency`), Foundation, `URLSessionWebSocketTask` (via `WebSocketTransport`), `Process` (macOS only, via `ProcessTransport`), Swift Testing + XCTest. Spec at `docs/superpowers/specs/2026-05-14-lsp-ios-coverage-design.md` (commit `170cdb7`).

---

## File Structure

**Framework — 6 modified, 0 created, 0 deleted (whole-file):**
- `Sources/CodeEditorPlugin/LSP/LSPManagerTypes.swift` — extend `LanguageServerConfig` with remote fields, `.local(...)` and `.remote(...)` factories, internal `makeServerConfiguration(workspaceRoot:)` helper.
- `Sources/CodeEditorPlugin/LSP/LSPClient+Transport.swift` — change modern overload's `language: Language` parameter to `languageId: String`.
- `Sources/CodeEditorPlugin/LSP/LSPClient.swift` — delete the dead `connectLegacy` extension at L535-573; update Platform Support docstring at L19-25.
- `Sources/CodeEditorPlugin/LSP/LSPManager.swift` — drop the file-level `#if canImport(AppKit)` ... `#endif`; drop the `// LSP functionality is only available on macOS` lead comment; update Platform Support docstring.
- `Sources/CodeEditorPlugin/LSP/LSPClientRegistry.swift` — drop the file-level `#if canImport(AppKit)`; gate the `pathResolver` field with `#if canImport(AppKit)`; migrate `startLanguageServer(for:)` to `makeServerConfiguration` + modern `connect(configuration:, languageId:)`; branch `isLanguageServerAvailable(_:)` and `resolveLanguageServerPath(_:)`; add internal `clientFactory` seam for the registry-flow test.
- `Sources/CodeEditorPlugin/LSP/LSPCompletionProvider.swift`, `LSPDocumentManager.swift`, `LSPContentCoordinator.swift`, `LSPSemanticTokenProvider.swift` — drop the file-level `#if canImport(AppKit)` gates only.

**Sample — 1 modified:**
- `Sources/CodeEditorSample/iOS/IOSRootView.swift` — update the `.inspectors` `ContentUnavailableView` copy so it points at `LanguageServerConfig.remote(url:)` for iOS LSP and only marks the chrome as desktop-only.

**Tests — 3 created, 0 modified:**
- `Tests/CodeEditorPluginTests/LSP/LanguageServerConfigFactoryTests.swift` — Swift Testing, cross-platform. Covers `.local` / `.remote` / positional-init invariants + `makeServerConfiguration` translation.
- `Tests/CodeEditorPluginTests/LSP/LSPClientRegistryRemoteFlowTests.swift` — XCTest, cross-platform. Verifies the registry's migration off the process-only path via an injected `clientFactory`.
- `Tests/CodeEditorPluginTests/LSP/LSPManagerIOSCoverageTests.swift` — Swift Testing, iOS-only (`#if !canImport(AppKit)`; empty on macOS). Smoke-tests that all the un-gated types instantiate on iOS.

The `Tests/CodeEditorPluginTests/LSP/` directory does not exist yet — Task 1 creates it.

**Files explicitly NOT touched:**
- `Sources/CodeEditorPlugin/LSP/LSPPathResolver.swift` — stays `#if canImport(AppKit)`.
- `Sources/CodeEditorPlugin/LSP/LSPProcessManager.swift` — stays as is (already has `#else` stubs for non-AppKit).
- `Sources/CodeEditorPlugin/LSP/Transport/ProcessTransport.swift` — stays `#if canImport(AppKit)`.
- `Sources/CodeEditorPlugin/LSP/Transport/WebSocketTransport.swift` — already cross-platform.
- `Sources/CodeEditorPlugin/LSP/RemoteLSPConfiguration.swift` — already cross-platform.
- `Sources/CodeEditorPlugin/LSP/LSPProtocol.swift`, `LSPTypes.swift`, `LSPMessageHandler.swift`, `LSPConnectionManager.swift`, `LSPLanguageFeatures.swift`, `LSPRetryConfiguration.swift`, `LSPTypeAliases.swift` — already cross-platform (no `#if canImport(AppKit)`).
- `Sources/CodeEditorSample/App/LSP/LSPSampleCoordinator.swift` — stays `#if canImport(AppKit)` (non-goal: sample iOS LSP demo).

---

## Task 1: Add LanguageServerConfig factory tests (red)

**Files:**
- Create: `Tests/CodeEditorPluginTests/LSP/LanguageServerConfigFactoryTests.swift` (new directory)

Write the failing test file first so we can verify the new API doesn't exist yet, then unblock it in Task 2. The tests use Swift Testing's `@Suite` / `@Test` macros to match the project's modern test style.

- [ ] **Step 1: Create the `Tests/CodeEditorPluginTests/LSP/` directory**

```bash
mkdir -p Tests/CodeEditorPluginTests/LSP
```

- [ ] **Step 2: Write the failing test file**

Create `Tests/CodeEditorPluginTests/LSP/LanguageServerConfigFactoryTests.swift` with the following content:

```swift
import Foundation
import Testing
@testable import CodeEditorPlugin

@Suite("LanguageServerConfig factory invariants")
struct LanguageServerConfigFactoryTests {

    @Test("`.local(...)` factory produces a local-shaped config")
    func localFactoryProducesLocalShape() {
        let config = LanguageServerConfig.local(
            languageId: "swift",
            serverPath: "/usr/bin/sourcekit-lsp",
            fileExtensions: ["swift"]
        )

        #expect(config.serverPath == "/usr/bin/sourcekit-lsp")
        #expect(config.remoteURL == nil)
        #expect(config.languageId == "swift")
        #expect(config.fileExtensions == ["swift"])
    }

    @Test("`.remote(url:)` factory produces a remote-shaped config")
    func remoteFactoryProducesRemoteShape() throws {
        let url = try #require(URL(string: "wss://lsp.example.com/swift"))
        let config = LanguageServerConfig.remote(
            languageId: "swift",
            url: url,
            fileExtensions: ["swift"]
        )

        #expect(config.serverPath == "")
        #expect(config.remoteURL == url)
        #expect(config.remoteHeaders.isEmpty)
        #expect(config.remoteAuthentication == nil)
        #expect(config.languageId == "swift")
    }

    @Test("Existing positional init still produces a local-shaped config (source compat)")
    func positionalInitIsLocalShaped() {
        let config = LanguageServerConfig(
            languageId: "python",
            serverPath: "/usr/local/bin/pylsp",
            fileExtensions: ["py", "pyw"]
        )

        #expect(config.serverPath == "/usr/local/bin/pylsp")
        #expect(config.remoteURL == nil)
        #expect(config.languageId == "python")
    }

    @Test("`.remote(...)` factory preserves auth, headers, and transport overrides")
    func remoteFactoryPreservesOptionalFields() throws {
        let url = try #require(URL(string: "wss://lsp.example.com/swift"))
        let transport = LSPTransportConfiguration(autoReconnect: false, maxReconnectAttempts: 1, reconnectDelay: 0.5)
        let config = LanguageServerConfig.remote(
            languageId: "swift",
            url: url,
            fileExtensions: ["swift"],
            headers: ["X-Test": "1"],
            authentication: .bearerToken("xyz"),
            transportConfiguration: transport
        )

        #expect(config.remoteHeaders == ["X-Test": "1"])
        if case .bearerToken(let token) = config.remoteAuthentication {
            #expect(token == "xyz")
        } else {
            Issue.record("Expected .bearerToken authentication, got \(String(describing: config.remoteAuthentication))")
        }
        #expect(config.remoteTransportConfiguration?.autoReconnect == false)
    }
}
```

- [ ] **Step 3: Run the test file to verify it fails**

```bash
swift test --filter LanguageServerConfigFactoryTests 2>&1 | head -30
```

Expected: build failure. The compiler reports unknown members `LanguageServerConfig.local`, `LanguageServerConfig.remote`, `config.remoteURL`, `config.remoteHeaders`, `config.remoteAuthentication`, `config.remoteTransportConfiguration`. **Do not commit yet** — the failing file is part of Task 2's commit.

---

## Task 2: Extend `LanguageServerConfig` with `.local` / `.remote` factories (green)

**Files:**
- Modify: `Sources/CodeEditorPlugin/LSP/LSPManagerTypes.swift` (entire `LanguageServerConfig` struct, currently at lines 27-56)

Add the remote fields and both factories. The existing positional initializer is preserved verbatim for source compatibility; it constructs a local-shaped config with `remoteURL = nil`.

- [ ] **Step 1: Replace the `LanguageServerConfig` struct definition**

Open `Sources/CodeEditorPlugin/LSP/LSPManagerTypes.swift`. Replace the entire struct body (currently L27-56) with:

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

    /// Existing positional initializer — kept for source compatibility.
    /// Constructs a local-shaped config (`remoteURL == nil`).
    public init(
        languageId: String,
        serverPath: String,
        fileExtensions: [String],
        serverArguments: [String] = [],
        capabilities: ClientCapabilities = .default,
        autoStart: Bool = true,
        enablePathResolution: Bool = true,
        retryConfiguration: LSPRetryConfiguration = .default
    ) {
        self.languageId = languageId
        self.serverPath = serverPath
        self.serverArguments = serverArguments
        self.fileExtensions = fileExtensions
        self.capabilities = capabilities
        self.autoStart = autoStart
        self.enablePathResolution = enablePathResolution
        self.retryConfiguration = retryConfiguration
        self.remoteURL = nil
        self.remoteHeaders = [:]
        self.remoteAuthentication = nil
        self.remoteTransportConfiguration = nil
    }

    /// Construct a local LSP server configuration. Process-based; macOS only at start time.
    public static func local(
        languageId: String,
        serverPath: String,
        fileExtensions: [String],
        serverArguments: [String] = [],
        capabilities: ClientCapabilities = .default,
        autoStart: Bool = true,
        enablePathResolution: Bool = true,
        retryConfiguration: LSPRetryConfiguration = .default
    ) -> Self {
        Self(
            languageId: languageId,
            serverPath: serverPath,
            fileExtensions: fileExtensions,
            serverArguments: serverArguments,
            capabilities: capabilities,
            autoStart: autoStart,
            enablePathResolution: enablePathResolution,
            retryConfiguration: retryConfiguration
        )
    }

    /// Construct a remote LSP server configuration. Uses WebSocket transport on all platforms.
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
    ) -> Self {
        Self(
            languageId: languageId,
            fileExtensions: fileExtensions,
            capabilities: capabilities,
            autoStart: autoStart,
            retryConfiguration: retryConfiguration,
            remoteURL: url,
            remoteHeaders: headers,
            remoteAuthentication: authentication,
            remoteTransportConfiguration: transportConfiguration
        )
    }

    /// Internal designated initializer used by `.remote(...)`. Not public — callers go through the factories.
    private init(
        languageId: String,
        fileExtensions: [String],
        capabilities: ClientCapabilities,
        autoStart: Bool,
        retryConfiguration: LSPRetryConfiguration,
        remoteURL: URL,
        remoteHeaders: [String: String],
        remoteAuthentication: LSPAuthentication?,
        remoteTransportConfiguration: LSPTransportConfiguration?
    ) {
        self.languageId = languageId
        self.serverPath = ""
        self.serverArguments = []
        self.fileExtensions = fileExtensions
        self.capabilities = capabilities
        self.autoStart = autoStart
        self.enablePathResolution = false
        self.retryConfiguration = retryConfiguration
        self.remoteURL = remoteURL
        self.remoteHeaders = remoteHeaders
        self.remoteAuthentication = remoteAuthentication
        self.remoteTransportConfiguration = remoteTransportConfiguration
    }
}
```

- [ ] **Step 2: Build to verify the framework still compiles**

```bash
swift build 2>&1 | tail -20
```

Expected: `Build complete!` with zero errors.

- [ ] **Step 3: Run the factory tests**

```bash
swift test --filter LanguageServerConfigFactoryTests 2>&1 | tail -30
```

Expected: all four `@Test` cases pass.

- [ ] **Step 4: Commit Tasks 1 + 2 together**

```bash
git add Tests/CodeEditorPluginTests/LSP/LanguageServerConfigFactoryTests.swift Sources/CodeEditorPlugin/LSP/LSPManagerTypes.swift
git commit -m "$(cat <<'EOF'
LSP: add LanguageServerConfig.local / .remote factories

Adds remote-server fields (remoteURL, remoteHeaders, remoteAuthentication,
remoteTransportConfiguration) and two factory inits. Existing positional
init is preserved for source compatibility and constructs a local-shaped
config. New `Tests/CodeEditorPluginTests/LSP/LanguageServerConfigFactoryTests.swift`
covers the invariants.

Part 1 of the LSP iOS coverage rollout. Spec at
docs/superpowers/specs/2026-05-14-lsp-ios-coverage-design.md.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Add `makeServerConfiguration` helper (TDD)

**Files:**
- Modify: `Sources/CodeEditorPlugin/LSP/LSPManagerTypes.swift` (append the helper to the `LanguageServerConfig` struct or as an extension at the end of the file)
- Modify: `Tests/CodeEditorPluginTests/LSP/LanguageServerConfigFactoryTests.swift` (append three new `@Test` cases)

This helper translates a `LanguageServerConfig` into the transport-typed `LSPServerConfiguration` enum that `LSPClient.connect(configuration:, languageId:)` consumes. On iOS, a local-shaped config throws an `LSPError` with a clear message.

- [ ] **Step 1: Write the failing helper tests**

Append the following section inside the existing `LanguageServerConfigFactoryTests` suite, before the closing `}` of the struct:

```swift

    @Test("`makeServerConfiguration` on `.remote` returns `.remote(_)` regardless of platform")
    func makeServerConfigurationRemoteShape() throws {
        let url = try #require(URL(string: "wss://lsp.example.com/swift"))
        let config = LanguageServerConfig.remote(
            languageId: "swift",
            url: url,
            fileExtensions: ["swift"],
            authentication: .bearerToken("xyz")
        )

        let server = try config.makeServerConfiguration(
            workspaceRoot: URL(fileURLWithPath: "/tmp")
        )

        guard case .remote(let remote) = server else {
            Issue.record("Expected .remote, got \(server)")
            return
        }
        #expect(remote.serverURL == url)
        if case .bearerToken(let token) = remote.authentication {
            #expect(token == "xyz")
        } else {
            Issue.record("Expected bearer-token authentication on the translated remote config")
        }
    }

    #if canImport(AppKit)
    @Test("`makeServerConfiguration` on `.local` returns `.local(_)` on macOS")
    func makeServerConfigurationLocalShapeOnMac() throws {
        let config = LanguageServerConfig.local(
            languageId: "swift",
            serverPath: "/usr/bin/sourcekit-lsp",
            fileExtensions: ["swift"],
            serverArguments: ["--log-file", "/tmp/x.log"]
        )

        let server = try config.makeServerConfiguration(
            workspaceRoot: URL(fileURLWithPath: "/tmp")
        )

        guard case .local(let local) = server else {
            Issue.record("Expected .local, got \(server)")
            return
        }
        #expect(local.executablePath == "/usr/bin/sourcekit-lsp")
        #expect(local.arguments == ["--log-file", "/tmp/x.log"])
        #expect(local.workingDirectory == URL(fileURLWithPath: "/tmp"))
    }
    #else
    @Test("`makeServerConfiguration` on `.local` throws on iOS")
    func makeServerConfigurationLocalThrowsOnIOS() {
        let config = LanguageServerConfig.local(
            languageId: "swift",
            serverPath: "/usr/bin/sourcekit-lsp",
            fileExtensions: ["swift"]
        )

        do {
            _ = try config.makeServerConfiguration(
                workspaceRoot: URL(fileURLWithPath: "/tmp")
            )
            Issue.record("Expected throw; got success")
        } catch let error as LSPError {
            if case .serverError(_, let message, _) = error {
                #expect(message.contains("AppKit") || message.contains("remote"))
            } else {
                Issue.record("Expected LSPError.serverError, got \(error)")
            }
        } catch {
            Issue.record("Expected LSPError, got \(error)")
        }
    }
    #endif
```

- [ ] **Step 2: Run to verify the test fails**

```bash
swift test --filter LanguageServerConfigFactoryTests 2>&1 | tail -20
```

Expected: build failure. The compiler reports `value of type 'LanguageServerConfig' has no member 'makeServerConfiguration'`.

- [ ] **Step 3: Implement `makeServerConfiguration`**

Append the following extension to `Sources/CodeEditorPlugin/LSP/LSPManagerTypes.swift`, after the closing `}` of `LanguageServerConfig`:

```swift

extension LanguageServerConfig {
    /// Translate this configuration into the transport-typed `LSPServerConfiguration`
    /// that `LSPClient.connect(configuration:, languageId:)` consumes.
    ///
    /// - Parameter workspaceRoot: workspace directory used by local-server transports.
    ///   Ignored for remote configurations.
    /// - Throws: `LSPError.serverError` on iOS for local-shaped configurations.
    ///   Local LSP servers require AppKit's `Process` API.
    internal func makeServerConfiguration(workspaceRoot: URL) throws -> LSPServerConfiguration {
        if let remoteURL {
            return .remote(RemoteLSPConfiguration(
                serverURL: remoteURL,
                authentication: remoteAuthentication,
                customHeaders: remoteHeaders,
                transportConfiguration: remoteTransportConfiguration
            ))
        }

        #if canImport(AppKit)
        return .local(LocalLSPConfiguration(
            executablePath: serverPath,
            arguments: serverArguments,
            workingDirectory: workspaceRoot,
            environment: [:]
        ))
        #else
        throw LSPError.serverError(
            code: -1,
            message: "Local language servers require AppKit (macOS). Use LanguageServerConfig.remote(url:) for iOS.",
            data: nil
        )
        #endif
    }
}
```

- [ ] **Step 4: Run the tests and verify green**

```bash
swift test --filter LanguageServerConfigFactoryTests 2>&1 | tail -20
```

Expected: all factory tests (including the new `makeServerConfiguration*` cases) pass on macOS.

- [ ] **Step 5: Commit**

```bash
git add Tests/CodeEditorPluginTests/LSP/LanguageServerConfigFactoryTests.swift Sources/CodeEditorPlugin/LSP/LSPManagerTypes.swift
git commit -m "$(cat <<'EOF'
LSP: add LanguageServerConfig.makeServerConfiguration helper

Translates a LanguageServerConfig to the transport-typed
LSPServerConfiguration that LSPClient.connect(configuration:, languageId:)
consumes. Remote configs produce .remote(_) on all platforms; local configs
produce .local(_) on macOS and throw LSPError.serverError on iOS.

Part 2 of the LSP iOS coverage rollout.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Simplify the modern `LSPClient.connect` overload

**Files:**
- Modify: `Sources/CodeEditorPlugin/LSP/LSPClient+Transport.swift` (entire file, currently 47 lines)

The modern overload at `LSPClient+Transport.swift:18` takes `language: Language` and uses it only to extract `language.lspIdentifier`. Zero in-tree callers (verified via `grep "connect(configuration:.*language:"`). Renaming the parameter to `languageId: String` unblocks the registry migration in Task 5 because `LSPClientRegistry` keys configs by `languageId: String`.

No new test — the build is the test. Task 5's registry-flow test exercises the new signature.

- [ ] **Step 1: Replace the file contents**

Overwrite `Sources/CodeEditorPlugin/LSP/LSPClient+Transport.swift` with:

```swift
import Foundation

/// Extension to LSPClient that adds transport-based initialization.
/// Available on all platforms — the underlying transport (ProcessTransport on macOS,
/// WebSocketTransport everywhere) is selected by `LSPServerConfiguration.createTransport()`.
@available(macOS 10.15, iOS 13.0, *)
extension LSPClient {
    /// Initialize LSPClient with a specific transport.
    /// - Parameter transport: The transport to use for communication.
    public convenience init(transport: LSPTransport) {
        self.init()
        self.transport = transport
    }

    /// Connect using a transport-typed server configuration.
    /// - Parameters:
    ///   - configuration: Unified server configuration (`.local` or `.remote`).
    ///   - languageId: LSP language identifier (e.g. "swift", "python") used during init handshake.
    public func connect(configuration: LSPServerConfiguration, languageId: String) async throws {
        // Create appropriate transport based on configuration.
        let transport = try await configuration.createTransport()
        self.transport = transport

        // Extract a legacy ServerConfiguration so the transport-aware
        // `connect(configuration: ServerConfiguration)` body at LSPClient.swift:138
        // can run the init handshake without changes.
        let baseConfig: ServerConfiguration
        switch configuration {
        case .local(let localConfig):
            baseConfig = ServerConfiguration(
                languageId: languageId,
                serverPath: localConfig.executablePath,
                workspaceRoot: localConfig.workingDirectory ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
                serverArguments: localConfig.arguments
            )

        case .remote(let remoteConfig):
            baseConfig = ServerConfiguration(
                languageId: languageId,
                serverPath: remoteConfig.serverURL.absoluteString,
                workspaceRoot: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
                serverArguments: []
            )
        }

        // Connect using the base implementation. Because `self.transport` is now non-nil,
        // it takes the transport branch and bypasses `processManager.startServerProcess(...)`.
        try await connect(configuration: baseConfig)
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
swift build 2>&1 | tail -10
```

Expected: `Build complete!` with zero errors.

- [ ] **Step 3: Commit**

```bash
git add Sources/CodeEditorPlugin/LSP/LSPClient+Transport.swift
git commit -m "$(cat <<'EOF'
LSP: simplify modern LSPClient.connect overload to take languageId: String

The `language: Language` parameter was only used to extract
language.lspIdentifier. Zero in-tree callers, so renaming to
`languageId: String` is safe and unblocks LSPClientRegistry's migration
to the modern connect overload (registry keys configs by languageId
string, not Language enum).

Part 3 of the LSP iOS coverage rollout.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Failing test — registry routes remote configs to `.remote(_)` (red)

**Files:**
- Create: `Tests/CodeEditorPluginTests/LSP/LSPClientRegistryRemoteFlowTests.swift`

This test exercises the migration we'll implement in Task 6. It needs a small testable seam — a client factory closure injected into `LSPClientRegistry` — so the test can substitute an `LSPClient` whose `connect(configuration: LSPServerConfiguration, languageId: String)` records its argument instead of opening a real WebSocket. Task 6 adds both the seam and the migration.

The registry today is wrapped in `#if canImport(AppKit)`. The test file likewise uses that gate; after Task 8 lands the un-gating we'll come back and remove the gate on this test file in Task 9. For now, keep it AppKit-gated so the test compiles against the current source tree.

- [ ] **Step 1: Write the failing test file**

Create `Tests/CodeEditorPluginTests/LSP/LSPClientRegistryRemoteFlowTests.swift`:

```swift
#if canImport(AppKit)
import Foundation
import XCTest
@testable import CodeEditorPlugin

/// Verifies LSPClientRegistry's migration off the process-only legacy connect path.
///
/// The registry now translates a LanguageServerConfig to a transport-typed
/// LSPServerConfiguration via `config.makeServerConfiguration(workspaceRoot:)`
/// before calling `client.connect(configuration:, languageId:)`. We inject a
/// recording client so we can assert the payload shape without spinning up a
/// real WebSocket or Process.
@MainActor
final class LSPClientRegistryRemoteFlowTests: XCTestCase {

    func testRemoteConfigRoutesToRemotePayload() async throws {
        let url = try XCTUnwrap(URL(string: "wss://lsp.example.com/swift"))
        let recordedConfig = LSPClientRegistryRemoteFlowRecorder()
        let registry = LSPClientRegistry(clientFactory: recordedConfig.makeRecordingClient)
        registry.workspaceRoot = URL(fileURLWithPath: "/tmp/ws")

        let remote = LanguageServerConfig.remote(
            languageId: "swift",
            url: url,
            fileExtensions: ["swift"],
            authentication: .bearerToken("xyz"),
            autoStart: false
        )
        registry.registerLanguageServer(remote)

        try await registry.startLanguageServer(for: "swift")

        let lastConfig = try XCTUnwrap(await recordedConfig.lastConfiguration)
        guard case .remote(let payload) = lastConfig else {
            XCTFail("Expected .remote payload, got \(lastConfig)")
            return
        }
        XCTAssertEqual(payload.serverURL, url)

        let recordedLanguageId = await recordedConfig.lastLanguageId
        XCTAssertEqual(recordedLanguageId, "swift")
    }

    func testLocalConfigRoutesToLocalPayloadOnMac() async throws {
        let recordedConfig = LSPClientRegistryRemoteFlowRecorder()
        let registry = LSPClientRegistry(clientFactory: recordedConfig.makeRecordingClient)
        registry.workspaceRoot = URL(fileURLWithPath: "/tmp/ws")

        let local = LanguageServerConfig.local(
            languageId: "swift",
            serverPath: "/usr/bin/sourcekit-lsp",
            fileExtensions: ["swift"],
            enablePathResolution: false,    // Skip resolver — `/usr/bin/sourcekit-lsp` may not exist on CI.
            autoStart: false
        )
        registry.registerLanguageServer(local)

        try await registry.startLanguageServer(for: "swift")

        let lastConfig = try XCTUnwrap(await recordedConfig.lastConfiguration)
        guard case .local(let payload) = lastConfig else {
            XCTFail("Expected .local payload, got \(lastConfig)")
            return
        }
        XCTAssertEqual(payload.executablePath, "/usr/bin/sourcekit-lsp")
    }
}

/// Records the configuration last passed to `connect(configuration:, languageId:)`.
/// Lives at file scope so the registry's client-factory closure can capture it.
actor LSPClientRegistryRemoteFlowRecorder {
    var lastConfiguration: LSPServerConfiguration?
    var lastLanguageId: String?

    @MainActor
    func makeRecordingClient() async -> LSPClient {
        let client = await LSPClient.createAndSetup()
        client.recordingHandler = { [weak self] config, languageId in
            await self?.record(configuration: config, languageId: languageId)
        }
        return client
    }

    func record(configuration: LSPServerConfiguration, languageId: String) {
        self.lastConfiguration = configuration
        self.lastLanguageId = languageId
    }
}
#endif
```

This test references two not-yet-existing seams:
- `LSPClientRegistry.init(clientFactory: …)` — the dependency-injection point.
- `LSPClient.recordingHandler` — a test-only closure on `LSPClient` that fires before the real connect work. (Alternative: a `@testable internal var` substitute for `connect(configuration:, languageId:)`.)

Both come in Task 6.

- [ ] **Step 2: Run the test to verify it fails**

```bash
swift test --filter LSPClientRegistryRemoteFlowTests 2>&1 | tail -20
```

Expected: build failure. Compiler reports unknown `LSPClientRegistry.init(clientFactory:)` and unknown `LSPClient.recordingHandler`. **Do not commit yet** — this file is part of Task 6's commit.

---

## Task 6: Add registry `clientFactory` seam + migrate `startLanguageServer` (green)

**Files:**
- Modify: `Sources/CodeEditorPlugin/LSP/LSPClient.swift` — add `internal var recordingHandler` and route through it in the modern overload.
- Modify: `Sources/CodeEditorPlugin/LSP/LSPClient+Transport.swift` — fire `recordingHandler` before the real connect work.
- Modify: `Sources/CodeEditorPlugin/LSP/LSPClientRegistry.swift` — add `clientFactory` init parameter, migrate `startLanguageServer(for:)`.

- [ ] **Step 1: Add `recordingHandler` to `LSPClient`**

Open `Sources/CodeEditorPlugin/LSP/LSPClient.swift`. Locate the `// MARK: - Private Properties` block (around L90-106) and add the following internal property after `internal var transport: LSPTransport?` (currently at L96):

```swift
    /// Test-only hook: fires from the modern `connect(configuration:, languageId:)` overload
    /// before any transport work. Production callers leave this `nil`.
    internal var recordingHandler: (@Sendable (LSPServerConfiguration, String) async -> Void)?
```

- [ ] **Step 2: Fire `recordingHandler` from the modern connect overload**

Open `Sources/CodeEditorPlugin/LSP/LSPClient+Transport.swift`. Inside the `connect(configuration:, languageId:)` body, insert the recording call immediately after the `func connect(...)` signature opening brace, before the existing `let transport = try await configuration.createTransport()`:

```swift
    public func connect(configuration: LSPServerConfiguration, languageId: String) async throws {
        // Test-only hook (production callers leave this nil).
        if let handler = recordingHandler {
            await handler(configuration, languageId)
            return
        }

        // Create appropriate transport based on configuration.
        let transport = try await configuration.createTransport()
        // ... existing body unchanged ...
```

The `return` short-circuits after recording so the test doesn't try to spin up a real transport against `wss://lsp.example.com`.

- [ ] **Step 3: Add `clientFactory` to `LSPClientRegistry` and migrate `startLanguageServer`**

Open `Sources/CodeEditorPlugin/LSP/LSPClientRegistry.swift`. Two edits:

a) Replace the existing initializer area (around L22-37, the `init()` block plus the `private let pathResolver` field). Look for:

```swift
final class LSPClientRegistry {
```

Add this directly under the class declaration (replace existing properties if they conflict):

```swift
    /// Test-only client factory. Production uses `LSPClient.createAndSetup()`.
    private let clientFactory: @MainActor () async -> LSPClient

    private let pathResolver = LSPPathResolver()

    /// Production initializer — uses `LSPClient.createAndSetup()`.
    init() {
        self.clientFactory = { await LSPClient.createAndSetup() }
    }

    /// Test initializer — substitute the client factory.
    init(clientFactory: @escaping @MainActor () async -> LSPClient) {
        self.clientFactory = clientFactory
    }
```

(Preserve the surrounding properties — `serverConfigurations`, `activeClients`, `logger`, `workspaceRoot`, anything else.)

b) Rewrite `startLanguageServer(for:)` to use `makeServerConfiguration` + the modern connect overload. Replace the body (currently around L97-156, the section that builds `LSPClient.ServerConfiguration` and calls `client.connect(configuration:)`):

```swift
    func startLanguageServer(
        for languageId: String,
        retryConfig: LSPRetryConfiguration? = nil
    ) async throws {
        guard let config = serverConfigurations[languageId] else {
            throw LSPError.invalidResponse("No configuration found for language: \(languageId)")
        }

        // Use provided retry config or fall back to the server's configured retry settings
        let effectiveRetryConfig = retryConfig ?? config.retryConfiguration

        // Remote configs don't need a workspace root (WebSocket transport ignores it).
        // Local configs require one — Process needs a working directory.
        let effectiveWorkspaceRoot: URL
        if config.remoteURL != nil {
            effectiveWorkspaceRoot = workspaceRoot ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        } else {
            guard let root = workspaceRoot else {
                throw LSPError.invalidResponse("No workspace root set")
            }
            effectiveWorkspaceRoot = root
        }

        // Don't start if already running
        if activeClients[languageId] != nil {
            return
        }

        logger.info("Starting LSP server for \(languageId)")

        // Resolve the executable path on macOS for local-shaped configs.
        // Remote-shaped configs and iOS short-circuit (no resolver).
        let resolvedConfig: LanguageServerConfig
        #if canImport(AppKit)
        if config.remoteURL == nil, config.enablePathResolution {
            guard let resolved = pathResolver.resolvePath(config.serverPath) else {
                throw LSPError.invalidResponse("Language server executable not found: \(config.serverPath)")
            }
            logger.debug("Resolved server path for \(languageId): \(config.serverPath) -> \(resolved)")
            resolvedConfig = LanguageServerConfig.local(
                languageId: config.languageId,
                serverPath: resolved,
                fileExtensions: config.fileExtensions,
                serverArguments: config.serverArguments,
                capabilities: config.capabilities,
                autoStart: config.autoStart,
                enablePathResolution: false,
                retryConfiguration: config.retryConfiguration
            )
        } else {
            resolvedConfig = config
        }
        #else
        resolvedConfig = config
        #endif

        let client = await clientFactory()
        let serverConfig = try resolvedConfig.makeServerConfiguration(workspaceRoot: effectiveWorkspaceRoot)

        // Attempt connection with retry logic.
        var lastError: Error?

        for attempt in 0...effectiveRetryConfig.maxRetries {
            do {
                try await client.connect(configuration: serverConfig, languageId: languageId)
                activeClients[languageId] = client
                logger.info("Successfully started LSP server for \(languageId) on attempt \(attempt + 1)")
                return
            } catch {
                lastError = error

                if attempt < effectiveRetryConfig.maxRetries {
                    let delay = effectiveRetryConfig.delay(for: attempt)
                    logger.warning("Failed to start LSP server for \(languageId) on attempt \(attempt + 1)/\(effectiveRetryConfig.maxRetries + 1). Retrying in \(String(format: "%.1f", delay))s. Error: \(error.localizedDescription)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    client.disconnect()
                } else {
                    logger.error("Failed to start LSP server for \(languageId) after \(effectiveRetryConfig.maxRetries + 1) attempts. Error: \(error.localizedDescription)")
                }
            }
        }

        throw lastError ?? LSPError.serverError(code: -1, message: "Failed to start LSP server after retries", data: nil)
    }
```

c) Update `isLanguageServerAvailable(_:)` and `resolveLanguageServerPath(_:)` to handle remote configs and the iOS case. Locate the existing definitions (around L211-247) and replace with:

```swift
    /// Check if a language server is available for the given configuration.
    /// Remote configs are "available" iff they carry a URL.
    /// Local configs require AppKit; on iOS they always return false.
    func isLanguageServerAvailable(_ config: LanguageServerConfig) -> Bool {
        if config.remoteURL != nil {
            return true
        }
        #if canImport(AppKit)
        if config.enablePathResolution {
            return pathResolver.isAvailable(config.serverPath)
        }
        return FileManager.default.fileExists(atPath: config.serverPath)
        #else
        return false
        #endif
    }

    /// Get all available paths for a language server executable.
    /// macOS-only — iOS returns an empty array (no executable resolution under sandbox).
    func findLanguageServerPaths(for executableName: String) -> [String] {
        #if canImport(AppKit)
        return pathResolver.findAllPaths(for: executableName)
        #else
        _ = executableName
        return []
        #endif
    }

    /// Get availability status for all configured language servers.
    func getLanguageServerAvailability() -> [String: Bool] {
        var availability: [String: Bool] = [:]
        for (languageId, config) in serverConfigurations {
            availability[languageId] = isLanguageServerAvailable(config)
        }
        return availability
    }

    /// Resolve the actual path that would be used for a language server.
    /// macOS-only for local configs. Returns the remote URL string for remote configs.
    /// Returns nil for local configs on iOS.
    func resolveLanguageServerPath(_ config: LanguageServerConfig) -> String? {
        if let url = config.remoteURL {
            return url.absoluteString
        }
        #if canImport(AppKit)
        if config.enablePathResolution {
            return pathResolver.resolvePath(config.serverPath)
        }
        return FileManager.default.fileExists(atPath: config.serverPath) ? config.serverPath : nil
        #else
        return nil
        #endif
    }
```

- [ ] **Step 4: Build and run the test**

```bash
swift build 2>&1 | tail -10
```

Expected: `Build complete!`.

```bash
swift test --filter LSPClientRegistryRemoteFlowTests 2>&1 | tail -25
```

Expected: both tests in `LSPClientRegistryRemoteFlowTests` pass.

- [ ] **Step 5: Run the full LSP test slice to make sure nothing else broke**

```bash
swift test --filter "LSP|LanguageServerConfig" 2>&1 | tail -40
```

Expected: pre-existing pass list unchanged. The only known pre-existing failure that touches this slice is `LSPSampleCoordinatorStateTests.resolverFailureTransitionsToFailed` (carries forward per `REVIEW.md`).

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorPlugin/LSP/LSPClient.swift Sources/CodeEditorPlugin/LSP/LSPClient+Transport.swift Sources/CodeEditorPlugin/LSP/LSPClientRegistry.swift Tests/CodeEditorPluginTests/LSP/LSPClientRegistryRemoteFlowTests.swift
git commit -m "$(cat <<'EOF'
LSP: migrate LSPClientRegistry to modern connect overload + add test seam

LSPClientRegistry.startLanguageServer(for:) now translates each
LanguageServerConfig via makeServerConfiguration(workspaceRoot:) and
calls client.connect(configuration: LSPServerConfiguration, languageId:).
Path resolution stays macOS-only via #if canImport(AppKit). Remote
configs bypass the resolver entirely.

isLanguageServerAvailable / resolveLanguageServerPath / findLanguageServerPaths
now branch: remote configs are URL-keyed; local configs require AppKit.

LSPClient gains an internal `recordingHandler` test-hook fired by the
modern connect overload so tests can substitute clients without
spinning up real WebSockets or Processes.

New `Tests/CodeEditorPluginTests/LSP/LSPClientRegistryRemoteFlowTests.swift`
covers the .remote and .local payload routing.

Part 4 of the LSP iOS coverage rollout.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Drop `#if canImport(AppKit)` from six LSP modules

**Files:**
- Modify: `Sources/CodeEditorPlugin/LSP/LSPManager.swift` (drop file-level gate at L1 + L429)
- Modify: `Sources/CodeEditorPlugin/LSP/LSPCompletionProvider.swift` (drop file-level gate at L1 + L427)
- Modify: `Sources/CodeEditorPlugin/LSP/LSPDocumentManager.swift` (drop file-level gate at L1 + L196)
- Modify: `Sources/CodeEditorPlugin/LSP/LSPContentCoordinator.swift` (drop file-level gate at L1 + L224)
- Modify: `Sources/CodeEditorPlugin/LSP/LSPSemanticTokenProvider.swift` (drop file-level gate at L1 + L293)
- Modify: `Sources/CodeEditorPlugin/LSP/LSPClientRegistry.swift` (drop the outer `#if canImport(AppKit)` ... `#endif` wrapping the whole file at L1 + L427; the inner `#if canImport(AppKit)` blocks added in Task 6 stay)

These files don't actually use AppKit — only `LSPProcessManager` and `LSPPathResolver` do. The file-level gates were over-broad.

- [ ] **Step 1: `LSPManager.swift` — drop the file-level gate**

Open `Sources/CodeEditorPlugin/LSP/LSPManager.swift`. Remove L1-2 (the `#if canImport(AppKit)` directive and `// LSP functionality is only available on macOS` comment). Remove the trailing `#endif // canImport(AppKit)` at L429.

Keep the inner `#if canImport(Combine)` block at L5-7 — that's unrelated.

- [ ] **Step 2: `LSPCompletionProvider.swift` — drop the file-level gate**

Open `Sources/CodeEditorPlugin/LSP/LSPCompletionProvider.swift`. Remove the `#if canImport(AppKit)` at L1 and the matching `#endif` at L427.

- [ ] **Step 3: `LSPDocumentManager.swift` — drop the file-level gate**

Open `Sources/CodeEditorPlugin/LSP/LSPDocumentManager.swift`. Remove the `#if canImport(AppKit)` at L1 and the matching `#endif // canImport(AppKit)` at L196.

- [ ] **Step 4: `LSPContentCoordinator.swift` — drop the file-level gate**

Open `Sources/CodeEditorPlugin/LSP/LSPContentCoordinator.swift`. Remove the `#if canImport(AppKit)` at L1 and the matching `#endif // canImport(AppKit)` at L224.

- [ ] **Step 5: `LSPSemanticTokenProvider.swift` — drop the file-level gate**

Open `Sources/CodeEditorPlugin/LSP/LSPSemanticTokenProvider.swift`. Remove the `#if canImport(AppKit)` at L1 and the matching `#endif // canImport(AppKit)` at L293.

- [ ] **Step 6: `LSPClientRegistry.swift` — drop the file-level gate (keep inner gates from Task 6)**

Open `Sources/CodeEditorPlugin/LSP/LSPClientRegistry.swift`. Remove the file-level `#if canImport(AppKit)` at L1 and the matching `#endif // canImport(AppKit)` at L427. The inner `#if canImport(AppKit)` blocks introduced in Task 6 (around the `pathResolver` field and the `enablePathResolution` branch in `startLanguageServer`, plus the inner blocks of `isLanguageServerAvailable` / `findLanguageServerPaths` / `resolveLanguageServerPath`) stay.

- [ ] **Step 7: Verify the build is green on macOS**

```bash
swift build 2>&1 | tail -10
```

Expected: `Build complete!`. If you hit a missing-symbol error, double-check that the `pathResolver` field gate from Task 6 is intact (`#if canImport(AppKit) private let pathResolver = LSPPathResolver() #endif`).

- [ ] **Step 8: Run the LSP test slice**

```bash
swift test --filter "LSP|LanguageServerConfig" 2>&1 | tail -25
```

Expected: same pass list as Task 6 step 5. No regressions.

- [ ] **Step 9: Run SwiftLint**

```bash
swiftlint --fix && swiftlint 2>&1 | tail -10
```

Expected: zero violations.

- [ ] **Step 10: Commit**

```bash
git add Sources/CodeEditorPlugin/LSP/LSPManager.swift Sources/CodeEditorPlugin/LSP/LSPClientRegistry.swift Sources/CodeEditorPlugin/LSP/LSPCompletionProvider.swift Sources/CodeEditorPlugin/LSP/LSPDocumentManager.swift Sources/CodeEditorPlugin/LSP/LSPContentCoordinator.swift Sources/CodeEditorPlugin/LSP/LSPSemanticTokenProvider.swift
git commit -m "$(cat <<'EOF'
LSP: drop #if canImport(AppKit) from six modules

LSPManager, LSPClientRegistry, LSPCompletionProvider, LSPDocumentManager,
LSPContentCoordinator, LSPSemanticTokenProvider — none of these import
AppKit or use AppKit-specific APIs. The file-level gates were over-broad.
Only LSPPathResolver / LSPProcessManager / ProcessTransport still need
AppKit; the inner gates inside LSPClientRegistry (added in part 4) cover
the pathResolver field and resolver call sites.

Part 5 of the LSP iOS coverage rollout.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Un-gate the registry-flow test now that the registry compiles on iOS

**Files:**
- Modify: `Tests/CodeEditorPluginTests/LSP/LSPClientRegistryRemoteFlowTests.swift`

The Task 5 test file is wrapped in `#if canImport(AppKit)` to match the source-tree state at that point. After Task 7, the registry compiles on all platforms — the test can shed its file-level gate. The local-payload assertion stays inside an inner `#if canImport(AppKit)` because `makeServerConfiguration` throws on iOS for local configs.

- [ ] **Step 1: Drop the file-level gate, narrow it to the local test only**

Open `Tests/CodeEditorPluginTests/LSP/LSPClientRegistryRemoteFlowTests.swift`. Remove the outermost `#if canImport(AppKit)` at L1 and the matching `#endif` at the end of the file. Then wrap the second test method (`testLocalConfigRoutesToLocalPayloadOnMac`) in its own `#if canImport(AppKit)` block:

```swift
    #if canImport(AppKit)
    func testLocalConfigRoutesToLocalPayloadOnMac() async throws {
        // ... existing body ...
    }
    #endif
```

- [ ] **Step 2: Build and run the test slice**

```bash
swift test --filter "LSPClientRegistryRemoteFlow" 2>&1 | tail -15
```

Expected: both tests pass on macOS. The remote-payload test compiles and runs on iOS too (we'll verify in Task 11's iOS-simulator build).

- [ ] **Step 3: Commit**

```bash
git add Tests/CodeEditorPluginTests/LSP/LSPClientRegistryRemoteFlowTests.swift
git commit -m "$(cat <<'EOF'
LSP: un-gate registry-flow test now that LSPClientRegistry is cross-platform

The remote-payload test runs on iOS too; only the local-payload test
stays AppKit-gated because makeServerConfiguration throws for .local on iOS.

Part 6 of the LSP iOS coverage rollout.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Add iOS smoke tests for the un-gated LSP types

**Files:**
- Create: `Tests/CodeEditorPluginTests/LSP/LSPManagerIOSCoverageTests.swift`

Pure compile-time + smoke-test surface. Compiles to empty on macOS (`#if !canImport(AppKit)`); on iOS the body asserts that each previously-gated type can be instantiated and that `.local` configs are rejected at start time.

- [ ] **Step 1: Write the test file**

Create `Tests/CodeEditorPluginTests/LSP/LSPManagerIOSCoverageTests.swift`:

```swift
#if !canImport(AppKit)
import Foundation
import Testing
@testable import CodeEditorPlugin

@Suite("LSP types instantiate on iOS")
@MainActor
struct LSPManagerIOSCoverageTests {

    @Test("LSPManager initializes on iOS")
    func lspManagerInitializesOnIOS() {
        let memoryMonitor = MemoryMonitor.mock()
        let manager = LSPManager(memoryMonitor: memoryMonitor, workspaceRoot: nil)
        #expect(manager.activeClients.isEmpty)
    }

    @Test("registerLanguageServer(.remote) stores config on iOS")
    func remoteRegistrationOnIOS() throws {
        let memoryMonitor = MemoryMonitor.mock()
        let manager = LSPManager(memoryMonitor: memoryMonitor, workspaceRoot: nil)
        let url = try #require(URL(string: "wss://lsp.example.com/swift"))
        manager.registerLanguageServer(.remote(
            languageId: "swift",
            url: url,
            fileExtensions: ["swift"],
            autoStart: false
        ))
        #expect(manager.serverConfigurations["swift"] != nil)
    }

    @Test("startLanguageServer with a .local config throws on iOS")
    func localStartThrowsOnIOS() async {
        let memoryMonitor = MemoryMonitor.mock()
        let manager = LSPManager(memoryMonitor: memoryMonitor, workspaceRoot: nil)
        manager.registerLanguageServer(.local(
            languageId: "swift",
            serverPath: "/usr/bin/sourcekit-lsp",
            fileExtensions: ["swift"],
            enablePathResolution: false,
            autoStart: false
        ))

        do {
            try await manager.startLanguageServer(for: "swift")
            Issue.record("Expected throw on iOS for .local config")
        } catch let error as LSPError {
            if case .serverError(_, let message, _) = error {
                #expect(message.contains("AppKit") || message.contains("remote"))
            } else {
                Issue.record("Expected .serverError, got \(error)")
            }
        } catch {
            Issue.record("Expected LSPError, got \(error)")
        }
    }

    @Test("LSPCompletionProvider initializes on iOS")
    func completionProviderInitializesOnIOS() {
        let memoryMonitor = MemoryMonitor.mock()
        let manager = LSPManager(memoryMonitor: memoryMonitor, workspaceRoot: nil)
        let provider = LSPCompletionProvider(lspManager: manager, supportedLanguages: [.swift])
        #expect(provider.supportedLanguages == [.swift])
    }

    @Test("LSPSemanticTokenProvider initializes on iOS")
    func semanticTokenProviderInitializesOnIOS() {
        let memoryMonitor = MemoryMonitor.mock()
        let manager = LSPManager(memoryMonitor: memoryMonitor, workspaceRoot: nil)
        let provider = LSPSemanticTokenProvider(lspManager: manager, filePath: "/tmp/x.swift")
        _ = provider    // smoke test only — initializes without crashing
    }
}
#endif
```

- [ ] **Step 2: Build on macOS — file compiles to empty (no test impact)**

```bash
swift build 2>&1 | tail -5
```

Expected: `Build complete!`. On macOS the test file resolves to an empty translation unit because of the outer `#if !canImport(AppKit)`.

- [ ] **Step 3: Commit (full iOS build verification happens in Task 11)**

```bash
git add Tests/CodeEditorPluginTests/LSP/LSPManagerIOSCoverageTests.swift
git commit -m "$(cat <<'EOF'
LSP: add iOS smoke tests for un-gated LSP types

Verifies LSPManager, LSPCompletionProvider, LSPSemanticTokenProvider
all instantiate on iOS; that .remote registration succeeds; and that
.local registration + startLanguageServer throws LSPError with a
helpful AppKit/remote message.

#if !canImport(AppKit) — empty on macOS by design.

Part 7 of the LSP iOS coverage rollout.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Delete the dead `LSPClient.connectLegacy` extension + update docstrings

**Files:**
- Modify: `Sources/CodeEditorPlugin/LSP/LSPClient.swift` — delete the `connectLegacy` extension; update header docstring.
- Modify: `Sources/CodeEditorPlugin/LSP/LSPManager.swift` — update header docstring.
- Modify: `Sources/CodeEditorSample/iOS/IOSRootView.swift` — update the `.inspectors` `ContentUnavailableView` copy.

`LSPClient.connectLegacy` has zero callers in tree (verified `grep -rnE "connectLegacy" Sources/ Tests/`). Its only definition site is the AppKit-gated extension at `LSPClient.swift:535-573`.

- [ ] **Step 1: Delete the `connectLegacy` extension**

Open `Sources/CodeEditorPlugin/LSP/LSPClient.swift`. Remove the entire block starting from `// MARK: - Conditional Extensions for Process-based LSP` (around L535) through the closing `#endif` of the `connectLegacy` extension (around L573). That includes:

```swift
// MARK: - Conditional Extensions for Process-based LSP

#if canImport(AppKit)
extension LSPClient {
    /// Legacy process-based connection for backward compatibility
    /// Use LSPServerConfiguration instead for new code
    func connectLegacy(configuration: ServerConfiguration) async throws {
        // ... entire body ...
    }
}
#endif
```

- [ ] **Step 2: Update `LSPClient` header docstring**

In the same file, locate the docstring block at L7-38. Replace lines 19-37 (everything between `/// - Important: LSP client is available on all platforms…` through the trailing `/// ```` of the example code block) with:

```swift
/// - Important: LSP client is available on all platforms, but functionality varies:
///   - macOS: Full support for both local and remote LSP servers
///   - iOS / iPadOS: Remote LSP servers only (via WebSocket transport)
///
/// ## Platform Support
/// - macOS: Full support (local + remote servers)
/// - iOS: Remote servers only — local servers require the `Process` API (AppKit)
///
/// ## Example Usage
/// ```swift
/// // Construct via LanguageServerConfig (the public-facing path).
/// let manager = LSPManager(memoryMonitor: memoryMonitor, workspaceRoot: projectURL)
///
/// // Local server (macOS only). Throws LSPError on iOS at startLanguageServer time.
/// manager.registerLanguageServer(.local(
///     languageId: "swift",
///     serverPath: "/usr/bin/sourcekit-lsp",
///     fileExtensions: ["swift"]
/// ))
///
/// // Remote server (all platforms).
/// manager.registerLanguageServer(.remote(
///     languageId: "swift",
///     url: URL(string: "wss://lsp.example.com/swift")!,
///     fileExtensions: ["swift"],
///     authentication: .bearerToken("token")
/// ))
/// ```
```

- [ ] **Step 3: Update `LSPManager` header docstring**

Open `Sources/CodeEditorPlugin/LSP/LSPManager.swift`. Replace the existing docstring's "Basic Usage" code block (around L21-43) with:

```swift
/// ## Basic Usage
///
/// ```swift
/// let lspManager = LSPManager(memoryMonitor: memoryMonitor, workspaceRoot: projectURL)
///
/// // Local server (macOS only).
/// lspManager.registerLanguageServer(.local(
///     languageId: "swift",
///     serverPath: "/usr/bin/sourcekit-lsp",
///     fileExtensions: ["swift"]
/// ))
///
/// // Remote server (all platforms — WebSocket).
/// lspManager.registerLanguageServer(.remote(
///     languageId: "python",
///     url: URL(string: "wss://lsp.example.com/python")!,
///     fileExtensions: ["py"]
/// ))
///
/// // Open a document.
/// try await lspManager.openDocument(filePath: "/path/to/file.swift", content: sourceCode)
///
/// // Request code completion.
/// let completions = try await lspManager.requestCompletion(
///     filePath: "/path/to/file.swift",
///     line: 10,
///     character: 15
/// )
/// ```
///
/// ## Platform Support
///
/// - macOS: Full support (local + remote servers)
/// - iOS / iPadOS: Remote servers only (via WebSocket transport).
///   Local-server registrations succeed but throw `LSPError` at start time.
```

- [ ] **Step 4: Update the IOSRootView inspector copy**

Open `Sources/CodeEditorSample/iOS/IOSRootView.swift`. Locate the `.inspectors` `ContentUnavailableView` (search for `"Inspector panels"` or `ContentUnavailableView`). Replace its description text with the new copy:

```swift
ContentUnavailableView {
    Label("Inspector panels are desktop-only", systemImage: "rectangle.split.3x1.fill")
} description: {
    Text("""
    Remote LSP servers work on iOS — use `LanguageServerConfig.remote(url:)` with `LSPManager` to wire up a WebSocket-backed language server. \
    Local servers require AppKit's `Process` API (macOS only) and throw an error at start time on iOS. \
    The inspector chrome that lives in `Sources/CodeEditorSample/Sidebars/` is desktop-only because it depends on AppKit-only views; the underlying framework APIs (`LSPManager`, `CompletionManager`, `PerformanceInsights`, `AnnotationsHub`) are cross-platform.
    """)
}
```

If the existing block uses a different syntactic shape, preserve that shape and only swap the description string.

- [ ] **Step 5: Build and lint**

```bash
swift build 2>&1 | tail -5 && swiftlint --fix && swiftlint 2>&1 | tail -5
```

Expected: `Build complete!`, zero SwiftLint violations.

- [ ] **Step 6: Run the LSP test slice**

```bash
swift test --filter "LSP|LanguageServerConfig" 2>&1 | tail -20
```

Expected: same pass list. No regressions.

- [ ] **Step 7: Commit**

```bash
git add Sources/CodeEditorPlugin/LSP/LSPClient.swift Sources/CodeEditorPlugin/LSP/LSPManager.swift Sources/CodeEditorSample/iOS/IOSRootView.swift
git commit -m "$(cat <<'EOF'
LSP: delete dead connectLegacy extension + correct iOS docstrings

LSPClient.connectLegacy had zero callers in tree — the registry never
used it. Deleting both the extension and its surrounding comment block.

LSPClient and LSPManager docstrings now show LanguageServerConfig.local/
.remote as the public-facing path and accurately describe the iOS
platform support level.

IOSRootView's inspector ContentUnavailableView now tells users to use
LanguageServerConfig.remote(url:) with LSPManager rather than claiming
the framework APIs "do work on iOS" without explaining how.

Part 8 of the LSP iOS coverage rollout.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: iOS-simulator build verification

**Files:** None (verification only)

This is the new must-pass: actually compile the framework against the iOS SDK. Today no one does because the LSP modules were AppKit-gated and the verification never ran.

- [ ] **Step 1: Build the framework against the iOS Simulator SDK**

```bash
swift build \
  -Xswiftc -sdk -Xswiftc "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -Xswiftc -target -Xswiftc arm64-apple-ios17.0-simulator \
  2>&1 | tail -40
```

Expected: `Build complete!`. If errors appear:

- `cannot find type 'LSPProcessManager' in scope` inside an un-gated file — Task 7 didn't keep the `pathResolver` field gate in `LSPClientRegistry`. Re-add the `#if canImport(AppKit)` around `private let pathResolver = LSPPathResolver()`.
- `cannot find 'Process' in scope` — somewhere in the un-gated code, a `Process()` slipped through. Search for `Process(` and re-gate that call site.
- Sample target errors — the sample target is iOS-buildable today via `IOSRootView`, but if you touched `Sources/CodeEditorSample/iOS/IOSRootView.swift` and broke its iOS path, fix and re-run.

If errors are unrelated to LSP (e.g., a pre-existing iOS-build issue surfaces because no one ever ran this command before), document them as "out of scope for this PR" and proceed — the spec's risk register flagged this possibility.

- [ ] **Step 2: Build the test target against the iOS Simulator SDK**

```bash
swift build --target CodeEditorPluginTests \
  -Xswiftc -sdk -Xswiftc "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -Xswiftc -target -Xswiftc arm64-apple-ios17.0-simulator \
  2>&1 | tail -40
```

Expected: `Build complete!`. The iOS-only `LSPManagerIOSCoverageTests.swift` compiles to real code under this triple. Compile errors here point at API mismatches in the iOS test file.

- [ ] **Step 3: Run the macOS test suite end-to-end**

```bash
swift test --parallel 2>&1 | tail -50
```

Expected: only the documented pre-existing failures remain (`EditorStatusBarSnapshots/*` parallel SIGSEGV, `RegexRangeHighlightProviderTests.testParsePerformance100KLines`, `ScrollPositionPreservationTests.testScrollPositionPreservedWhenTogglingWordWrap`, `DemoCompletionProviderTests.returnsThreeDemoItemsOnAnyLanguage`, `LSPSampleCoordinatorStateTests.resolverFailureTransitionsToFailed`). No new failures.

- [ ] **Step 4: Final lint pass**

```bash
swiftlint --fix && swiftlint --strict 2>&1 | tail -5
```

Expected: zero violations.

- [ ] **Step 5: Commit (verification-only, but useful to mark the bar)**

If everything green, no commit is needed (the previous commits already cover the changes). If you needed to add an `#if canImport(AppKit)` patch in Step 1, commit it as:

```bash
git add Sources/CodeEditorPlugin/LSP/<file>.swift
git commit -m "$(cat <<'EOF'
LSP: iOS-simulator build patch (post-verification)

Surfaced by running swift build against the iOS Simulator SDK for the
first time after the LSP iOS coverage rollout.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Otherwise, the rollout is complete after Task 10's commit.

---

## Self-Review

### Spec coverage

| Spec section | Plan task |
|---|---|
| Surface — extend `LanguageServerConfig` with remote fields + factories | Tasks 1–2 |
| Surface — `makeServerConfiguration` helper | Task 3 |
| Surface — `LSPClient.connect(configuration:, language:)` overload simplification | Task 4 |
| Surface — `LSPClientRegistry.startLanguageServer(for:)` migration | Task 6 |
| Gating — drop `#if canImport(AppKit)` from six modules | Task 7 |
| Gating — keep `pathResolver` field + resolver call sites macOS-only inside `LSPClientRegistry` | Task 6 (b)/(c), preserved by Task 7 |
| Gating — delete dead `LSPClient.connectLegacy` extension | Task 10 step 1 |
| Docstring — `LSPClient` header | Task 10 step 2 |
| Docstring — `LSPManager` header | Task 10 step 3 |
| Sample — `IOSRootView` inspector copy correction | Task 10 step 4 |
| Test — `LanguageServerConfigFactoryTests` | Tasks 1, 3 |
| Test — `LSPClientRegistryRemoteFlowTests` | Tasks 5, 6, 8 |
| Test — `LSPManagerIOSCoverageTests` | Task 9 |
| Verification — `swift build` macOS green | Tasks 2, 4, 6, 7, 10 (per task) |
| Verification — `swift build` iOS-simulator green | Task 11 step 1–2 |
| Verification — `swiftlint --strict` green | Tasks 7, 10, 11 |
| Verification — `swift test --parallel` green (modulo pre-existing) | Task 11 step 3 |
| Risk — `LSPClient.connect(configuration:)` overload pair stays | Captured in Task 4 narrative |
| Risk — iOS-simulator build never ran in CI | Captured in Task 11 step 1 fallback notes |
| Risk — WebSocket reconnect under sandboxed iOS | Spec-only; outside this rollout's scope |

All spec sections have at least one task that implements them.

### Placeholder scan

- No `TBD`, `TODO`, `implement later`, or `fill in details`.
- Every code step has full code.
- Every command step has the exact command and the expected output.
- Task 5's "alternative seam" is named explicitly (closure on `LSPClient.recordingHandler`) and the alternative is footnoted, not deferred.

### Type / name consistency

- `LSPAuthentication` (not `LSPRemoteAuthentication`) used throughout. Spec amended in commit `170cdb7`.
- `LanguageServerConfig.remote(url:)` parameter label `url` consistent across tests and factory.
- `LanguageServerConfig.remoteURL`, `remoteHeaders`, `remoteAuthentication`, `remoteTransportConfiguration` — same property names across the struct, the tests, and `makeServerConfiguration`.
- `LSPClient.connect(configuration: LSPServerConfiguration, languageId: String)` — parameter label `languageId` consistent across the overload definition, registry callsite, and recording test.
- `recordingHandler` — same identifier in `LSPClient.swift` (Task 6 step 1), `LSPClient+Transport.swift` (Task 6 step 2), and the recording test file (Task 5).
- `clientFactory` — same identifier in `LSPClientRegistry` init (Task 6 step 3) and the test's call site (Task 5).

No drift detected.
