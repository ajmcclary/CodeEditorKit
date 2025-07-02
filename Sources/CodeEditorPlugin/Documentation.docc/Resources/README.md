# Documentation Resources

This directory contains resources for the CodeEditorPlugin documentation.

## Directory Structure

- `Images/` - Contains all image assets referenced in the documentation
- `Code/` - Contains code snippets referenced in tutorials

## Required Images

The following images are referenced in the documentation and need to be added:

### Tutorial Images
- `first-editor-intro.png` - Hero image for the first editor tutorial
- `editor-01-import.png` - Import statement screenshot
- `editor-02-state.png` - State property screenshot
- `editor-03-view.png` - CodeEditor view screenshot
- `editor-04-language.png` - Language setting screenshot
- `editor-05-styling.png` - Styled editor screenshot

### Syntax Highlighting Tutorial
- `syntax-highlighting-intro.png` - Syntax highlighting examples
- `language-detection.png` - Language detection demonstration
- `syntax-customization.png` - Theme customization options

### Configuration Tutorial
- `configuration-intro.png` - Configuration options overview
- `configuration-structure.png` - Configuration structure diagram
- `presets-overview.png` - Available presets showcase
- `config-03-result.png` - Configured editor result

### General Documentation
- `getting-started-hero.png` - Getting started hero image
- `platform-hero.png` - Multi-platform showcase
- `platform-integration-hero.png` - Platform integration features
- `advanced-features-hero.png` - Advanced features overview
- `basic-editor-preview.png` - Basic editor preview
- `configured-editor.png` - Configured editor example
- `xcode-add-package.png` - Xcode package addition
- `add-package-url.png` - Package URL entry
- `version-selection.png` - Version selection dialog

## Required Code Snippets

The following code files are referenced in tutorials:

### Creating Your First Editor
- `editor-01-import.swift`
- `editor-02-state.swift`
- `editor-03-view.swift`
- `editor-04-language.swift`
- `editor-05-styling.swift`

### Syntax Highlighting
- `syntax-01-basic.swift`
- `syntax-02-detection.swift`
- `syntax-03-dynamic.swift`
- `syntax-04-theme.swift`
- `syntax-05-performance.swift`

### Configuration
- `config-01-default.swift`
- `config-02-display.swift`
- `config-03-layout.swift`
- `config-04-behavior.swift`
- `config-05-performance.swift`
- `preset-01-minimal.swift`
- `preset-02-readonly.swift`
- `preset-03-presentation.swift`

### Getting Started
- `setup-01-package.swift`
- `config-01-create.swift`
- `config-02-settings.swift`
- `config-03-apply.swift`

## Adding Resources

To add these resources:

1. Place image files in the `Images/` directory
2. Place code snippet files in the `Code/` directory
3. Ensure file names match exactly as referenced above
4. Images should be in PNG format
5. Code files should be in Swift format with proper syntax

## Generating Documentation

To build the documentation:

```bash
swift package generate-documentation
```

Or in Xcode:
1. Product → Build Documentation
2. The documentation will open in Xcode's documentation viewer