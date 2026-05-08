#if canImport(AppKit)
// LSP functionality is only available on macOS

import Foundation

/// Utility for resolving Language Server Protocol (LSP) server executable paths
/// 
/// `LSPPathResolver` provides flexible path resolution for language server executables,
/// supporting both absolute paths and executable name resolution via system PATH,
/// environment variables, and common installation locations.
///
/// ## Path Resolution Strategy
///
/// 1. **Absolute Paths**: If the path starts with "/", use it directly
/// 2. **Environment Variables**: Check for `LSP_<EXECUTABLE>_PATH` environment variable
/// 3. **System PATH**: Search for executable in system PATH directories
/// 4. **Common Locations**: Check standard installation directories
///
/// ## Example Usage
///
/// ```swift
/// let resolver = LSPPathResolver()
/// 
/// // Resolve from executable name
/// if let path = resolver.resolvePath("typescript-language-server") {
///     logger.debug("Found at: \(path)")
/// }
/// 
/// // Use absolute path directly
/// let absolutePath = resolver.resolvePath("/usr/local/bin/pylsp")
/// ```
///
/// ## Environment Variable Support
///
/// Set environment variables to override default paths:
/// - `LSP_TYPESCRIPT_LANGUAGE_SERVER_PATH`
/// - `LSP_PYLSP_PATH`
/// - `LSP_RUST_ANALYZER_PATH`
/// - `LSP_GOPLS_PATH`
///
/// - SeeAlso: ``LSPManager``, <doc:LSPManager/Language-Server-Configuration>
@available(macOS 10.15, iOS 13.0, *)
public struct LSPPathResolver: Sendable {
    // MARK: - Configuration

    /// Common installation directories to search for language servers
    private static let commonInstallationPaths: [String] = [
        "/usr/local/bin",
        "/opt/homebrew/bin",  // Apple Silicon Homebrew
        "/usr/bin",
        "/bin",
        "/usr/local/sbin",
        "/opt/local/bin",     // MacPorts
        "/usr/local/share/npm/bin", // npm global installs
        "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin", // Xcode tools
        "/Applications/Xcode.app/Contents/Developer/usr/bin", // Xcode developer tools
        System.getenv("HOME").map { "\($0)/.local/bin" } ?? "",
        System.getenv("HOME").map { "\($0)/.cargo/bin" } ?? "", // Rust installs
        System.getenv("HOME").map { "\($0)/go/bin" } ?? "" // Go installs
    ].filter { !$0.isEmpty }

    // MARK: - Public Methods

    /// Resolve the full path to a language server executable
    ///
    /// This method uses a multi-step resolution process:
    /// 1. Return absolute paths as-is (if they exist)
    /// 2. Check environment variable overrides
    /// 3. Search system PATH
    /// 4. Search common installation directories
    ///
    /// - Parameter serverPath: Either an absolute path or executable name
    /// - Returns: The resolved absolute path to the executable, or nil if not found
    public func resolvePath(_ serverPath: String) -> String? {
        // Step 1: If it's already an absolute path, verify it exists
        if serverPath.hasPrefix("/") {
            return FileManager.default.isExecutableFile(atPath: serverPath) ? serverPath : nil
        }

        // Step 2: Check for environment variable override
        if let envPath = resolveFromEnvironment(serverPath) {
            return envPath
        }

        // Step 3: Search in system PATH
        if let pathResult = findExecutableInPath(serverPath) {
            return pathResult
        }

        // Step 4: Search common installation directories
        if let commonPath = findInCommonLocations(serverPath) {
            return commonPath
        }

        return nil
    }

    /// Get all available paths for a given executable name
    ///
    /// This method returns all locations where the executable is found,
    /// useful for debugging or providing user choices.
    ///
    /// - Parameter executableName: Name of the executable to find
    /// - Returns: Array of absolute paths where the executable was found
    public func findAllPaths(for executableName: String) -> [String] {
        var foundPaths: [String] = []

        // Check environment variable
        if let envPath = resolveFromEnvironment(executableName) {
            foundPaths.append(envPath)
        }

        // Check all PATH directories
        let pathDirectories = getPathDirectories()
        for directory in pathDirectories {
            let fullPath = "\(directory)/\(executableName)"
            if FileManager.default.isExecutableFile(atPath: fullPath) {
                foundPaths.append(fullPath)
            }
        }

        // Check common installation directories
        for directory in Self.commonInstallationPaths {
            let fullPath = "\(directory)/\(executableName)"
            if FileManager.default.isExecutableFile(atPath: fullPath) && !foundPaths.contains(fullPath) {
                foundPaths.append(fullPath)
            }
        }

        return foundPaths
    }

    /// Check if a language server executable is available
    ///
    /// - Parameter serverPath: Either an absolute path or executable name
    /// - Returns: True if the server can be resolved and is executable
    public func isAvailable(_ serverPath: String) -> Bool {
        resolvePath(serverPath) != nil
    }

    // MARK: - Private Methods

    /// Resolve path from environment variable
    ///
    /// Checks for environment variables in the format: LSP_<EXECUTABLE>_PATH
    /// where <EXECUTABLE> is the uppercase, underscore-separated executable name.
    ///
    /// Examples:
    /// - "typescript-language-server" -> "LSP_TYPESCRIPT_LANGUAGE_SERVER_PATH"
    /// - "rust-analyzer" -> "LSP_RUST_ANALYZER_PATH"
    /// - "pylsp" -> "LSP_PYLSP_PATH"
    ///
    /// - Parameter executableName: Name of the executable
    /// - Returns: Path from environment variable if found and executable
    private func resolveFromEnvironment(_ executableName: String) -> String? {
        let envVarName = "LSP_\(executableName.uppercased().replacingOccurrences(of: "-", with: "_"))_PATH"

        guard let envPath = ProcessInfo.processInfo.environment[envVarName] else {
            return nil
        }

        return FileManager.default.isExecutableFile(atPath: envPath) ? envPath : nil
    }

    /// Find executable in system PATH
    ///
    /// - Parameter executableName: Name of the executable to find
    /// - Returns: First matching path found in PATH directories
    private func findExecutableInPath(_ executableName: String) -> String? {
        let pathDirectories = getPathDirectories()

        for directory in pathDirectories {
            let fullPath = "\(directory)/\(executableName)"
            if FileManager.default.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }

        return nil
    }

    /// Find executable in common installation locations
    ///
    /// - Parameter executableName: Name of the executable to find
    /// - Returns: First matching path found in common directories
    private func findInCommonLocations(_ executableName: String) -> String? {
        for directory in Self.commonInstallationPaths {
            let fullPath = "\(directory)/\(executableName)"
            if FileManager.default.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }

        return nil
    }

    /// Get directories from system PATH environment variable
    ///
    /// - Returns: Array of directory paths from PATH
    private func getPathDirectories() -> [String] {
        let pathVar = ProcessInfo.processInfo.environment["PATH"] ?? ""
        return pathVar.split(separator: ":").map(String.init).filter { !$0.isEmpty }
    }
}

// MARK: - System Environment Utilities

private enum System {
    /// Get environment variable value safely
    ///
    /// - Parameter name: Environment variable name
    /// - Returns: Environment variable value or nil if not set
    static func getenv(_ name: String) -> String? {
        guard let value = ProcessInfo.processInfo.environment[name] else {
            return nil
        }
        return value.isEmpty ? nil : value
    }
}

// MARK: - FileManager Extensions

extension FileManager {
    /// Check if a file exists and is executable
    ///
    /// - Parameter path: Path to check
    /// - Returns: True if file exists and has execute permissions
    func isExecutableFile(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileExists(atPath: path, isDirectory: &isDirectory) else {
            return false
        }

        // Must be a file, not a directory
        guard !isDirectory.boolValue else {
            return false
        }

        // Check execute permissions using POSIX access()
        return access(path, X_OK) == 0
    }
}

#endif
