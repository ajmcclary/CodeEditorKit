# CodeEditorPlugin Claude Workflows

This directory contains Claude Code workflows designed to streamline development of the CodeEditorPlugin project. These workflows are based on real development patterns used during the project's evolution.

## Available Workflows

### 🔧 Quality & Testing
- **`swift-quality-check`** - Most used: lint fix → lint → build → test pipeline
- **`performance-analysis`** - Memory leak detection and performance benchmarking
- **`cross-platform-test`** - macOS, iOS, and Catalyst compatibility testing

### 🚀 Development Pipelines
- **`swift-full-pipeline`** - Complete development workflow from code to release
- **`sample-app-workflow`** - CodeEditorSample-specific operations and validation
- **`release-preparation`** - Complete release checklist and quality gates

### 📝 Documentation & Git
- **`documentation-update`** - Update READMEs with latest metrics and achievements
- **`git-commit-push`** - Intelligent commit creation and pushing

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
@documentation-update  
@git-commit-push
```

## Project Context

These workflows are specifically designed for:
- **Swift 6** projects with actor-based concurrency
- **Cross-platform** development (macOS, iOS, Mac Catalyst)
- **SwiftLint** strict compliance (zero violations)
- **Comprehensive testing** (322 automated tests)
- **Production-ready** quality standards

Each workflow includes error handling, success criteria, and related workflow suggestions for optimal development experience.