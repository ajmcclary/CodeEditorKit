# LSP Retry Configuration

Configure robust retry behavior for Language Server Protocol connections to ensure reliability.

> Important: this page covers macOS local process-backed LSP servers managed by `LSPManager`. Remote WebSocket clients are available on all supported platforms; see [LSP integration](integration.md).

## Overview

The CodeEditorKit includes sophisticated retry logic for LSP connections, ensuring better reliability when starting language servers. This is particularly useful in environments where servers may take time to start or experience intermittent failures.

## Predefined Configurations

### Default Configuration

Standard retry configuration suitable for most use cases:

```swift
let lspManager = LSPManager(
    memoryMonitor: MemoryMonitor(),
    workspaceRoot: projectURL
)
try await lspManager.startLanguageServer(for: "swift")
```

### Aggressive Configuration

More persistent retry behavior for critical servers:

```swift
let swiftConfig = LanguageServerConfig(
    languageId: "swift",
    serverPath: "/usr/bin/sourcekit-lsp",
    fileExtensions: ["swift"],
    retryConfiguration: .aggressive
)
lspManager.registerLanguageServer(swiftConfig)
```

### Conservative Configuration

Fewer retries for resource-limited environments:

```swift
try await lspManager.startLanguageServer(
    for: "python",
    retryConfig: .conservative
)
```

### No Retry Configuration

Single attempt with no retries:

```swift
// Useful for testing or when retries are undesirable
try await lspManager.startLanguageServer(
    for: "rust",
    retryConfig: .noRetry
)
```

## Custom Configuration

Create custom retry parameters for specific requirements:

```swift
let customRetry = LSPRetryConfiguration(
    maxRetries: 4,
    initialDelay: 0.25,
    maxDelay: 20.0,
    backoffFactor: 3.0,
    jitterEnabled: true
)

try await lspManager.startLanguageServer(
    for: "rust",
    retryConfig: customRetry
)
```

## Retry Behavior

### Exponential Backoff

The delay between retries increases exponentially:

1. Attempt 1: 1.0s delay
2. Attempt 2: 2.0s delay (1.0 × 2.0)
3. Attempt 3: 4.0s delay (2.0 × 2.0)
4. Capped at `maxDelay`

### Jitter

When enabled, adds ±20% random variation to delays to prevent synchronized retries across multiple clients.

### Logging

Retry attempts are logged with appropriate severity:

Example log output:
```
[WARNING] Failed to start LSP server for swift on attempt 1/4. Retrying in 1.0s. Error: Connection refused
[WARNING] Failed to start LSP server for swift on attempt 2/4. Retrying in 2.0s. Error: Connection refused
[INFO] Successfully started LSP server for swift on attempt 3
```

## Error Handling

When all retry attempts are exhausted, the original error is thrown with additional context:

```swift
do {
    try await lspManager.startLanguageServer(for: "rust")
} catch {
    // Handle LSPError with details about failed attempts
    CrossPlatformLogger.logger().error("Failed to start language server after retries: \(error)")
}
```

## Best Practices

1. **Use Default Configuration**: Works well for most scenarios
2. **Customize for Critical Servers**: Use aggressive retry for essential language servers
3. **Consider Server Startup Time**: Increase `initialDelay` for slow-starting servers
4. **Monitor Logs**: Watch for repeated retry patterns indicating configuration issues
5. **Disable for Testing**: Use `.noRetry` in unit tests for predictable behavior

## Implementation Details

The retry logic is implemented in the local LSP registry startup path.

The retry mechanism:
1. Attempts connection with the language server
2. On failure, logs the error and calculates retry delay
3. Disconnects any partial connection state
4. Waits for the calculated delay (with optional jitter)
5. Repeats until success or max retries reached

## See Also

- [LSP-Integration](integration.md)
