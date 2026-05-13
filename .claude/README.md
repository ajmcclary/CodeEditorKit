# CodeEditorPlugin Claude Workflows

This directory contains Claude Code workflows designed to streamline development of the CodeEditorPlugin project. These workflows are based on real development patterns used during the project's evolution.

## Available Workflows

### 🔧 Quality & Testing
- **`swift-quality-check`** - Most used: lint fix → lint → build → test pipeline
- **`swift6-validation`** - Swift 6 strict concurrency compliance validation
- **`performance-analysis`** - Memory leak detection and performance benchmarking
- **`cross-platform-test`** - macOS and iOS / iPadOS compatibility testing

### 🚀 Development Pipelines
- **`swift-full-pipeline`** - Complete development workflow from code to release
- **`sample-app-workflow`** - CodeEditorSample-specific operations and validation
- **`release-preparation`** - Complete release checklist and quality gates

### 📝 Documentation & Git
- **`documentation-update`** - Update READMEs with latest metrics and achievements
- **`git-commit-push`** - Intelligent commit creation and pushing

## Quick Commands

### Core Development
- **`q`** - Quick quality check (alias for quality)
- **`build`** - Build main package and sample app
- **`test`** - Run the complete SwiftPM test suite
- **`lint`** - Fix and check SwiftLint violations
- **`sample`** - CodeEditorSample operations

### Advanced Operations
- **`swift6`** - Swift 6 concurrency compliance check
- **`platform`** - Cross-platform compatibility testing
- **`arch`** - Architecture-specific builds (arm64, x86_64)
- **`perf`** - Performance analysis workflow
- **`docs`** - Documentation update workflow

## Quick Start

The most commonly used workflow is `swift-quality-check`:

```
@swift-quality-check
```

This runs the complete quality pipeline that we use regularly during development.

## Workflow Chaining

Many workflows can be chained together for complex operations:

```
@swift-quality-check
@swift6-validation
@documentation-update  
@git-commit-push
```

For development with new features:
```
@q              # Quick quality check
@swift6         # Verify Swift 6 compliance
@platform       # Test cross-platform compatibility
@docs           # Update documentation
```

## Project Context

These workflows are specifically designed for:
- **Swift 6** projects with actor-based concurrency
- **Cross-platform** development (native macOS and iOS / iPadOS)
- **SwiftLint** strict compliance (zero violations)
- **Comprehensive testing** (4 test targets, 116 `*Tests.swift` files)
- **Production-ready** quality standards

## Current Project Status

- **116 Test Files**: 4 SwiftPM test targets across plugin, UI, design tokens, and sample coverage
- **Zero Violations Goal**: SwiftLint strict mode over the configured `Sources` and `Tests` paths
- **Swift 6.3 Ready**: Strict-concurrency package configuration
- **Cross-Platform**: Native macOS and iOS / iPadOS support; Mac Catalyst is retired
- **Production Quality**: Zero tolerance for quality issues

## Enhanced Features

### Swift 6 Leadership
- Full strict concurrency compliance
- Actor-based background processing
- MainActor UI isolation
- Sendable data structures

### Advanced Testing
- Comprehensive test coverage across 116 `*Tests.swift` files
- Cross-platform validation
- Performance benchmarking
- Architecture-specific builds

### Development Excellence
- Zero-violation quality standards
- Automated workflow chaining
- MCP tool integration
- Real-time validation

Each workflow includes error handling, success criteria, and related workflow suggestions for optimal development experience.
