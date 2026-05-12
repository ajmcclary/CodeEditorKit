# LSP Path Resolution

> Important: `LSPPathResolver` and local process-backed LSP management are only available on macOS. The all-platform `LSPClient` remote WebSocket path is documented in [LSP integration](integration.md).

Resolves Language Server Protocol (LSP) server executable paths with flexible path resolution strategies.

## Overview

`LSPPathResolver` provides a robust system for finding language server executables on macOS. It supports multiple resolution strategies including absolute paths, environment variable overrides, system PATH searching, and common installation directories. This makes it easy to integrate language servers regardless of how they were installed (Homebrew, npm, manual installation, etc.).

## Path Resolution Strategy

The resolver uses a multi-step approach to find language server executables:

1. **Absolute Paths**: If the path starts with "/", it's treated as an absolute path and verified directly
2. **Environment Variables**: Checks for `LSP_<EXECUTABLE>_PATH` environment variable overrides
3. **System PATH**: Searches directories in the system PATH environment variable
4. **Common Locations**: Checks standard installation directories like `/usr/local/bin`, `/opt/homebrew/bin`, etc.

## Basic Usage

### Simple Resolution

```swift
let resolver = LSPPathResolver()

// Resolve from executable name
if let path = resolver.resolvePath("typescript-language-server") {
    CrossPlatformLogger.logger().info("Found TypeScript language server at: \(path)")
}

// Use absolute path directly
let absolutePath = resolver.resolvePath("/usr/local/bin/pylsp")
```

### Check Availability

```swift
// Check if a language server is available
if resolver.isAvailable("rust-analyzer") {
    CrossPlatformLogger.logger().info("Rust analyzer is available")
}
```

### Find All Installations

```swift
// Find all installations of a language server
let allPaths = resolver.findAllPaths(for: "gopls")
for path in allPaths {
    CrossPlatformLogger.logger().info("Found gopls at: \(path)")
}
```

## Environment Variable Support

You can override default paths by setting environment variables:

```bash
export LSP_TYPESCRIPT_LANGUAGE_SERVER_PATH=/custom/path/to/typescript-language-server
export LSP_PYLSP_PATH=/custom/path/to/pylsp
export LSP_RUST_ANALYZER_PATH=/custom/path/to/rust-analyzer
export LSP_GOPLS_PATH=/custom/path/to/gopls
```

The environment variable name is constructed by:
1. Starting with `LSP_`
2. Converting the executable name to uppercase
3. Replacing hyphens with underscores
4. Appending `_PATH`

## Common Installation Paths

The resolver searches these common directories by default:

- `/usr/local/bin` - Standard Unix location
- `/opt/homebrew/bin` - Homebrew on Apple Silicon
- `/usr/bin` - System binaries
- `/opt/local/bin` - MacPorts
- `/usr/local/share/npm/bin` - npm global installs
- `~/.local/bin` - User local binaries
- `~/.cargo/bin` - Rust/Cargo installations
- `~/go/bin` - Go installations
- Xcode developer tools paths

## Integration with LSPManager

LSPPathResolver is typically used with LSPManager to configure language servers:

```swift
let resolver = LSPPathResolver()
let manager = LSPManager(
    memoryMonitor: MemoryMonitor(),
    workspaceRoot: projectURL
)

// Configure TypeScript language server
if let tsPath = resolver.resolvePath("typescript-language-server") {
    let config = LanguageServerConfig(
        languageId: "typescript",
        serverPath: tsPath,
        fileExtensions: ["ts", "tsx", "js", "jsx"],
        serverArguments: ["--stdio"],
        enablePathResolution: false
    )
    manager.registerLanguageServer(config)
    try await manager.startLanguageServer(for: "typescript")
}
```

## Platform Availability

LSPPathResolver is only available on macOS, as LSP functionality requires desktop features not available on iOS:

```swift
#if canImport(AppKit)
// LSP functionality is available
let resolver = LSPPathResolver()
#endif
```

## Best Practices

1. **Environment Variables**: Use environment variables for custom installations or when multiple versions are installed
2. **Fallback Paths**: Always have a fallback plan if a language server isn't found
3. **User Feedback**: Provide clear error messages when a required language server isn't found
4. **Caching**: Cache resolved paths to avoid repeated filesystem lookups

## Error Handling

```swift
let resolver = LSPPathResolver()

guard let serverPath = resolver.resolvePath("my-language-server") else {
    // Handle missing server
    showInstallInstructions()
    return
}

// Use the resolved path
```

## See Also

- [LSP-Integration](integration.md)
