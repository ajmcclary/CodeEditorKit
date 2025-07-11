//
//  PlatformBuildHelpers.swift
//  CodeEditorPlugin
//
//  Created on 1/8/25.
//

import Foundation

// MARK: - Platform Build Helpers

// Platform check documentation to simplify repeated platform conditionals.
//
// Throughout the codebase, use these simplified patterns:
//
// For Native AppKit (macOS, not Catalyst):
// #if canImport(AppKit) && !targetEnvironment(macCatalyst) // NATIVE_APPKIT
//
// For UIKit (iOS or Catalyst):
// #if canImport(UIKit)
//
// For Mac Catalyst Only:
// #if targetEnvironment(macCatalyst)
//
// For runtime platform detection, use `PlatformCapabilities.shared` instead.
//
// Since Swift doesn't support custom build flags without modifying the build system,
// we'll provide helper functions that can be used where appropriate.

/// Returns true if running on native macOS (AppKit, not Catalyst)
@inlinable
internal func isNativeAppKit() -> Bool {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    return true
    #else
    return false
    #endif
}

/// Returns true if running on UIKit (iOS or Catalyst)
@inlinable
internal func isUIKit() -> Bool {
    #if canImport(UIKit)
    return true
    #else
    return false
    #endif
}

/// Returns true if running on Mac Catalyst
@inlinable
internal func isCatalyst() -> Bool {
    #if targetEnvironment(macCatalyst)
    return true
    #else
    return false
    #endif
}
