// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

/// CodeEditorKit Package Configuration
///
/// This package provides a production-ready code editor component for Swift applications
/// with comprehensive syntax highlighting, code completion, and cross-platform support.
///
/// ## Requirements
///
/// - **Swift**: 6.3 or later
/// - **Platforms** (intentional — targets the current Apple OS family):
///   - macOS 27.0+
///   - iOS: **not declared.** The floor was `.iOS("26.0")` until the macOS 27
///     migration; it was removed rather than raised because the
///     `CodeEditorWorkspace` product cannot build for iOS. See the comment on
///     `platforms:` below for the failing symbols and the measured scope —
///     every other product does build for iOS 27.
///
/// Mac Catalyst is **not supported.** The framework went pure SwiftUI +
/// native AppKit/UIKit in 0.2.0 — see `CHANGELOG.md` for the rationale.
///
/// Consumers on older OS releases should pin a future LTS tag rather than expect
/// the floor to be lowered. See `docs/README.md` § Platform Requirements.
///
/// ## Installation
///
/// Add to your `Package.swift`:
/// ```swift
/// dependencies: [
///     .package(url: "https://github.com/ajmcclary/CodeEditorKit.git", from: "0.1.0")
/// ]
/// ```
///
/// ## License
///
/// MIT — see `LICENSE` at the repo root.
///
/// ## Dependencies
///
/// - **SwiftSyntax**: For Swift language AST-based syntax highlighting
///
/// ## Build Configuration
///
/// - Strict concurrency checking enabled for Swift 6 compatibility
/// - Optimized for both debug and release builds

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    // Enable strict concurrency checking for Swift 6 compatibility
    .enableExperimentalFeature("StrictConcurrency")
]

let package = Package(
    name: "CodeEditorKit",
    // macOS ONLY — the former `.iOS("26.0")` line is not restated here because
    // it cannot be backed for the package as a whole.
    //
    // The `CodeEditorWorkspace` product is an `@_exported import WorkspaceKit`
    // shim (workspace decomposition step 5). WorkspaceKit 0.1.0-beta.10
    // declares `platforms: [.macOS("27.0")]` and no iOS floor at all — its own
    // manifest records that `WorkspaceFileSystem`'s `FileSystemService` uses
    // the FSEvents C API unguarded, which does not exist on iOS. Because that
    // package declares no iOS minimum, an iOS build of it trips the default
    // (very old) iOS deployment target and fails on availability before it
    // ever reaches the FSEvents symbols. Verified with `.iOS("27.0")` still
    // declared here:
    //   xcodebuild -scheme CodeEditorKit-Package \
    //     -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
    // failed (3 failures) with, in WorkspaceKit's checkout:
    //   Sources/WorkspaceIgnore/GitignoreCompiler.swift:81:31:
    //     error: 'Mutex' is only available in iOS 18.0 or newer
    //     error: 'init(_:)' is only available in iOS 18.0 or newer
    //   Sources/WorkspaceIgnore/IgnoreRules.swift:70:21:
    //     error: 'Mutex' is only available in iOS 18.0 or newer
    //   Sources/WorkspaceIgnore/PatternPool.swift:18:36:
    //     error: 'Mutex' is only available in iOS 18.0 or newer
    //     error: 'init(_:)' is only available in iOS 18.0 or newer
    // and `-scheme CodeEditorWorkspace` (different build order, same edge)
    // failed with:
    //   Sources/WorkspaceSearch/PathSearchIndex.swift:46:5:
    //     error: isolated deinit is only available in iOS 18.4.0 or newer
    //
    // Scope of the blocker, measured: every product EXCEPT
    // `CodeEditorWorkspace` builds for iOS 27. With `.iOS("27.0")` declared,
    // these four schemes each reported `** BUILD SUCCEEDED **` for
    // 'generic/platform=iOS', and between them their target closures cover the
    // other 18 products: CodeEditorLSPIntegration (transitively Common,
    // Platform, TextModel, Configuration, Languages, Instrumentation,
    // Diagnostics, Completion, Annotations, Folding, Symbols,
    // HighlightingCore, Layout, SyntaxHighlighting, View, SwiftUI, LSP),
    // CodeEditorUI, CodeEditorKit, and CodeEditorSearch.
    // CodeEditorLSP's ProcessTransport is already `#if canImport(AppKit)`-
    // gated, and DesignKit 2.0.0 / LanguageKit 0.2.0 / ProcessKit
    // 0.1.0-beta.5 all declare `.iOS("27.0")`.
    //
    // NOT covered by that evidence: `CodeEditorSmartEditing`, which is not
    // productized and therefore has no scheme of its own. The only run that
    // would have built it — the `CodeEditorKit-Package` scheme — failed at
    // WorkspaceIgnore before reaching it. Its iOS status is unverified, not
    // known-good.
    //
    // Restoring an iOS floor requires platform-gating WorkspaceKit's
    // FSEvents-backed `WorkspaceFileSystem` upstream first; the alternative —
    // dropping the `CodeEditorWorkspace` product — is a public API break.
    //
    // Consequence, also measured: omitting the floor does not leave iOS
    // "unspecified but working" — it makes the whole package unbuildable for
    // iOS, one step earlier than before. With no iOS minimum declared, these
    // targets default to iOS 15.0, and `-scheme CodeEditorKit` /
    // `-scheme CodeEditorLSPIntegration` for 'generic/platform=iOS' now fail
    // at graph validation, before any compilation, with:
    //   error: The package product 'DesignKitThemes-product' requires minimum
    //   platform version 27.0 for the iOS platform, but this target supports
    //   15.0
    // (reported for CodeEditorAnnotations, CodeEditorFolding, CodeEditorKit,
    // CodeEditorLayout, CodeEditorSwiftUI, CodeEditorSymbols,
    // CodeEditorSyntaxHighlighting, and the scheme's own root target).
    // So this omission is a statement that the package is macOS-only today,
    // not a neutral silence.
    //
    // NOTE: `swift build --triple arm64-apple-ios27.0` is NOT a valid check —
    // it reports success while emitting macOS objects unless it is also given
    // `-Xswiftc -sdk -Xswiftc "$(xcrun --sdk iphoneos --show-sdk-path)"`.
    // Only xcodebuild with an iOS destination actually cross-compiles.
    platforms: [.macOS("27.0")],
    products: [
        .library(
            name: "CodeEditorAnnotations",
            targets: ["CodeEditorAnnotations"]
        ),
        .library(
            name: "CodeEditorCommon",
            targets: ["CodeEditorCommon"]
        ),
        .library(
            name: "CodeEditorCompletion",
            targets: ["CodeEditorCompletion"]
        ),
        .library(
            name: "CodeEditorConfiguration",
            targets: ["CodeEditorConfiguration"]
        ),
        .library(
            name: "CodeEditorDiagnostics",
            targets: ["CodeEditorDiagnostics"]
        ),
        .library(
            name: "CodeEditorHighlightingCore",
            targets: ["CodeEditorHighlightingCore"]
        ),
        .library(
            name: "CodeEditorInstrumentation",
            targets: ["CodeEditorInstrumentation"]
        ),
        .library(
            name: "CodeEditorKit",
            targets: ["CodeEditorKit"]
        ),
        .library(
            name: "CodeEditorLSP",
            targets: ["CodeEditorLSP"]
        ),
        .library(
            name: "CodeEditorLSPIntegration",
            targets: ["CodeEditorLSPIntegration"]
        ),
        .library(
            name: "CodeEditorLanguages",
            targets: ["CodeEditorLanguages"]
        ),
        .library(
            name: "CodeEditorLayout",
            targets: ["CodeEditorLayout"]
        ),
        .library(
            name: "CodeEditorPlatform",
            targets: ["CodeEditorPlatform"]
        ),
        .library(
            name: "CodeEditorSearch",
            targets: ["CodeEditorSearch"]
        ),
        .library(
            name: "CodeEditorSwiftUI",
            targets: ["CodeEditorSwiftUI"]
        ),
        .library(
            name: "CodeEditorTextModel",
            targets: ["CodeEditorTextModel"]
        ),
        .library(
            name: "CodeEditorUI",
            targets: ["CodeEditorUI"]
        ),
        .library(
            name: "CodeEditorView",
            targets: ["CodeEditorView"]
        ),
        .library(
            name: "CodeEditorWorkspace",
            targets: ["CodeEditorWorkspace"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/ajmcclary/DesignKit.git", from: "2.0.0"),
        .package(url: "https://github.com/ajmcclary/LanguageKit.git", .upToNextMinor(from: "0.2.0")),
        // Neutral POSIX process primitives (spawn/lifecycle/ordered byte
        // streams) — the ProcessKit "proof-of-two" shared with RepoPrompt.
        // Prerelease lower bound named explicitly (SwiftPM only resolves
        // prerelease tags when the requirement itself names one).
        .package(url: "https://github.com/ajmcclary/ProcessKit.git", .upToNextMinor(from: "0.1.0-beta.3")),
        // Workspace file-tree contracts + macOS adapter, promoted out of this
        // package's CodeEditorWorkspace target (workspace decomposition
        // step 5) — that target is now an @_exported re-export shim.
        // Prerelease lower bound named explicitly (same rule as ProcessKit).
        .package(url: "https://github.com/ajmcclary/WorkspaceKit.git", .upToNextMinor(from: "0.1.0-beta.1")),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        // Test-only dependency. Upstream 1.19.3 builds cleanly under the
        // Apple Swift 6.4 / Xcode 27 toolchain this workspace targets; the
        // former ajmcclary/swift-snapshot-testing@fix-swift-6.3-attachable
        // fork was only needed on the open-source swift-6.3-RELEASE toolchain
        // (cross-import-overlay Attachable conformances). Version-pinned so
        // this package stays consumable by stable-version dependents.
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.19.3"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.0.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0")
    ],
    targets: [
        .target(
            name: "CodeEditorCommon",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorHighlightingCore",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorTextModel",
            dependencies: ["CodeEditorCommon", "CodeEditorPlatform"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorPlatform",
            dependencies: ["CodeEditorCommon"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorConfiguration",
            dependencies: ["CodeEditorCommon", "CodeEditorPlatform", "CodeEditorTextModel"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorLanguages",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorPlatform",
                "CodeEditorTextModel",
                .product(name: "LanguageKit", package: "LanguageKit")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorInstrumentation",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorLanguages",
                "CodeEditorPlatform"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorDiagnostics",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorInstrumentation",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
            path: "Sources/CodeEditorDiagnostics",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorSyntaxHighlighting",
            dependencies: [
                "CodeEditorCommon",
                .product(name: "DesignKitTokens", package: "DesignKit"),
                "CodeEditorInstrumentation",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorTextModel",
                .product(name: "DesignKitThemes", package: "DesignKit"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax")
            ],
            path: "Sources/CodeEditorSyntaxHighlighting",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorAnnotations",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorPlatform",
                .product(name: "DesignKitThemes", package: "DesignKit")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorCompletion",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorInstrumentation",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorTextModel"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorFolding",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorLanguages",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorLSP",
            dependencies: [
                .product(name: "ProcessKit", package: "ProcessKit"),
                "CodeEditorCommon",
                "CodeEditorCompletion",
                "CodeEditorInstrumentation",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorTextModel"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorLayout",
            dependencies: [
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                .product(name: "DesignKitTokens", package: "DesignKit"),
                "CodeEditorPlatform",
                "CodeEditorSyntaxHighlighting",
                .product(name: "DesignKitThemes", package: "DesignKit")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorSearch",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorSymbols",
            dependencies: [
                "CodeEditorLanguages",
                "CodeEditorSyntaxHighlighting"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorView",
            dependencies: [
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorCompletion",
                "CodeEditorConfiguration",
                .product(name: "DesignKitTokens", package: "DesignKit"),
                "CodeEditorInstrumentation",
                "CodeEditorFolding",
                "CodeEditorHighlightingCore",
                "CodeEditorLanguages",
                "CodeEditorLayout",
                "CodeEditorPlatform",
                "CodeEditorSymbols",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel",
                .product(name: "DesignKitThemes", package: "DesignKit"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorLSPIntegration",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorHighlightingCore",
                "CodeEditorLSP",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorSwiftUI",
                "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel",
                "CodeEditorView"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorWorkspace",
            dependencies: [
                .product(name: "WorkspaceKit", package: "WorkspaceKit")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorSmartEditing",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorPlatform",
                "CodeEditorTextModel",
                "CodeEditorView"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorSwiftUI",
            dependencies: [
                "CodeEditorAnnotations",
                "CodeEditorCommon",
                "CodeEditorCompletion",
                "CodeEditorConfiguration",
                "CodeEditorDiagnostics",
                "CodeEditorHighlightingCore",
                "CodeEditorLanguages",
                "CodeEditorLayout",
                "CodeEditorPlatform",
                "CodeEditorTextModel",
                .product(name: "DesignKitThemes", package: "DesignKit"),
                "CodeEditorView"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorKit",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorLanguages",
                "CodeEditorSwiftUI",
                .product(name: "DesignKitThemes", package: "DesignKit"),
                "CodeEditorView"
            ],
            exclude: [
                "Info.plist"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CodeEditorUI",
            dependencies: [
                "CodeEditorConfiguration",
                .product(name: "DesignKitTokens", package: "DesignKit"),
                "CodeEditorLanguages",
                "CodeEditorSwiftUI",
                "CodeEditorSymbols",
                .product(name: "DesignKitThemes", package: "DesignKit"),
                "CodeEditorView"
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorKitTests",
            dependencies: [
                "CodeEditorConfiguration",
                "CodeEditorDiagnostics",
                "CodeEditorKit",
                "CodeEditorSwiftUI",
                .product(name: "DesignKitThemes", package: "DesignKit"),
                "CodeEditorView",
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            exclude: [
                "__Snapshots__",
                "Theming/__Snapshots__",
                "Layout/__Snapshots__"
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorCommonTests",
            dependencies: ["CodeEditorCommon", "CodeEditorDiagnostics"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorHighlightingCoreTests",
            dependencies: ["CodeEditorHighlightingCore"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorTextModelTests",
            dependencies: ["CodeEditorCommon", "CodeEditorTextModel"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorCompletionTests",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorCompletion",
                "CodeEditorDiagnostics",
                "CodeEditorLSP",
                "CodeEditorLanguages",
                "CodeEditorTextModel"
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorLSPTests",
            dependencies: ["CodeEditorCommon", "CodeEditorDiagnostics", "CodeEditorLSP"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorLSPIntegrationTests",
            dependencies: [
                "CodeEditorDiagnostics",
                "CodeEditorLSP",
                "CodeEditorLSPIntegration",
                "CodeEditorLanguages",
                "CodeEditorView"
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorViewTests",
            dependencies: [
                "CodeEditorAnnotations", "CodeEditorCommon", "CodeEditorCompletion",
                "CodeEditorConfiguration", .product(name: "DesignKitTokens", package: "DesignKit"), "CodeEditorDiagnostics",
                "CodeEditorFolding", "CodeEditorHighlightingCore", "CodeEditorLSP", "CodeEditorLanguages", "CodeEditorLayout",
                "CodeEditorPlatform", "CodeEditorSearch", "CodeEditorSmartEditing",
                "CodeEditorSymbols", "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel", .product(name: "DesignKitThemes", package: "DesignKit"), "CodeEditorView",
                .product(name: "CustomDump", package: "swift-custom-dump")
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorSwiftUITests",
            dependencies: [
                "CodeEditorAnnotations", "CodeEditorCommon", "CodeEditorCompletion",
                "CodeEditorConfiguration", "CodeEditorDiagnostics", "CodeEditorFolding",
                "CodeEditorHighlightingCore",
                "CodeEditorLSP", "CodeEditorLanguages", "CodeEditorLayout", "CodeEditorPlatform",
                "CodeEditorSwiftUI", "CodeEditorSymbols", "CodeEditorSyntaxHighlighting",
                "CodeEditorTextModel", .product(name: "DesignKitThemes", package: "DesignKit"), "CodeEditorView",
                .product(name: "CustomDump", package: "swift-custom-dump")
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorUITests",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                .product(name: "DesignKitTokens", package: "DesignKit"),
                "CodeEditorLanguages",
                "CodeEditorKit",
                "CodeEditorSwiftUI",
                "CodeEditorSymbols",
                .product(name: "DesignKitThemes", package: "DesignKit"),
                "CodeEditorUI",
                "CodeEditorView",
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            exclude: [
                "Snapshots/__Snapshots__"
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "CodeEditorHygieneTests",
            swiftSettings: swiftSettings
        )
    ]
)
