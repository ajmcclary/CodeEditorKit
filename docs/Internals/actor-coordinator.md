# `ActorCoordinator`

`ActorCoordinator` groups the framework's actor-backed cache, file-system,
performance, document-state, and error-recovery services. It is a runtime
dependency rather than a singleton.

## Owned services

- `CacheCoordinatorActor` manages registered caches.
- `FileSystemActor` owns file handles and file observation.
- `PerformanceMetricsActor` aggregates measured durations.
- `DocumentStateActor` owns document lifecycle state.
- `ErrorRecoveryCoordinator` applies explicit recovery strategies.

Text transformation is intentionally not part of this coordinator. Hosts that
need auto-bracketing, indentation, multiple cursors, or selection expansion
attach `SmartEditingEngine` from `CodeEditorSmartEditing` to a `CodeEditorView`:

```swift
import CodeEditorSmartEditing
import CodeEditorView

let editor = CodeEditorView(frame: .zero)
let smartEditing = SmartEditingEngine()
smartEditing.attach(to: editor)
```

## Injection

Create a coordinator per runtime scope and pass it through
`EditorRuntimeDependencies`:

```swift
let coordinator = ActorCoordinator.create()
let setup = EditorSetup(
    runtimeDependencies: EditorRuntimeDependencies(
        actorCoordinator: coordinator
    )
)

try setup.apply(to: editor)
```

The editor exposes the injected instance through `editor.actorCoordinator`.

## Performance metrics

Record observed work with a stable category and useful metadata:

```swift
let start = ContinuousClock.now
// Perform real work.
let duration = ContinuousClock.now - start

await coordinator.trackPerformance(
    name: "syntax-highlighting",
    duration: duration,
    metadata: ["language": "swift"]
)
```

## Documents

`createOrUpdateDocument(content:url:language:)` updates an existing document at
the URL or creates a new document when needed:

```swift
let documentID = await coordinator.createOrUpdateDocument(
    content: source,
    url: fileURL,
    language: .swift
)

await coordinator.documentState.markSaved(documentID)
```

## Caches

Register caches that conform to `CacheProtocol` with a stable identifier:

```swift
await coordinator.cacheCoordinator.registerCache(
    tokenCache,
    identifier: "syntax-tokens"
)

await coordinator.cacheCoordinator.clearCache("syntax-tokens")
```

`SmartTokenCache` already conforms to `CacheProtocol`.

## File operations

```swift
let content = try await coordinator.fileSystem.readFile(at: fileURL)
try await coordinator.fileSystem.writeFile(content, to: destinationURL)
```

## Platform requirements

`ActorCoordinator` supports the package deployment targets: macOS 26.3+ and
iOS/iPadOS 26.3+.

## See also

- `CacheCoordinatorActor`
- `FileSystemActor`
- `PerformanceMetricsActor`
- `DocumentStateActor`
- `ErrorRecoveryCoordinator`
- `SmartEditingEngine`
