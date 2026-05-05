# Installation

@Metadata {
    @PageKind(article)
    @PageColor(blue)
}

Add CodeEditorPlugin to your project using Swift Package Manager.

## Swift Package Manager

### Using Xcode

1. In Xcode, select **File → Add Package Dependencies**
2. Enter the repository URL:
   ```
   https://github.com/ajmcclary/CodeEditorPlugin.git
   ```
3. Select your version requirements:
   - **Up to Next Major Version**: `1.0.0 < 2.0.0` (Recommended)
   - **Up to Next Minor Version**: `1.0.0 < 1.1.0` 
   - **Exact Version**: `1.0.0`
   - **Branch**: `main` (for latest development)
4. Click **Add Package**

### Using Package.swift

Add the dependency to your `Package.swift` file:

```swift
// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [
        .macOS("26.3"),
        .iOS("26.3"),
        .macCatalyst("26.3")
    ],
    dependencies: [
        .package(url: "https://github.com/ajmcclary/CodeEditorPlugin.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "MyApp",
            dependencies: ["CodeEditorPlugin"]
        )
    ]
)
```

## Importing

After installation, import the module in your Swift files:

```swift
import CodeEditorPlugin
```

## Dependencies

CodeEditorPlugin depends on a small set of Swift packages:

- **swift-syntax** (602.0.0+): Used for Swift language syntax highlighting
- **swift-dependencies**: Dependency injection and test overrides
- **xctest-dynamic-overlay / IssueReporting**: Developer-visible runtime issue reporting

These dependencies are automatically managed by Swift Package Manager.

## Platform Requirements

Ensure your project meets these minimum requirements:

- **Swift**: 6.3 or later
- **Xcode**: 26.3 or later
- **Deployment Targets**:
  - macOS 26.3+
  - iOS 26.3+
  - Mac Catalyst 26.3+

## Troubleshooting

### Package Resolution Failed

If you encounter package resolution issues:

1. Clean build folder: **Product → Clean Build Folder** (⇧⌘K)
2. Reset package caches: **File → Packages → Reset Package Caches**
3. Update to latest version of Xcode

### Missing swift-syntax

If swift-syntax fails to resolve:

1. Ensure you're using Xcode 26.3 or later
2. Try specifying the exact swift-syntax version in your Package.swift

## See Also

- <doc:GettingStarted>
- <doc:QuickStart>
- <doc:SwiftUI-Integration>
