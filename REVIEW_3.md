# Documentation.docc Review 3

**Outdated file counts and language support**

The README and multiple documentation pages still reference _53 test files_, _333 source files_, and _17+ languages_.  
Current counts are 66 test files and roughly 376 Swift source files (excluding DocC examples) supporting 20 languages. Examples of the outdated statements:

  * README headers show the outdated badge counts and feature bullet points

  * Production reliability section mentions 53 test files and 333 source files

  * Architecture overview notes 53 tests and 333 source files

  * The getting started guide repeats the 17‑language/53‑tests claim

  * Syntax highlighting documentation also states “17+ programming languages”

**Incomplete preset documentation**

The “Configuration Presets” article only lists five presets and omits the `.platformOptimized`, `.iOS`, `.catalyst`, and `.macOS` presets found in `EditorConfiguration+PresetsExtensions.swift`. Other documents (e.g., `SwiftUI-Integration.md` and `QuickStart.md`) demonstrate `.platformOptimized`, so the presets article should be expanded accordingly.

**Summary**

Documentation should be updated to match the current codebase:

  * Adjust counts (tests, source files, supported languages) across README and DocC pages.

  * Extend “Configuration Presets” to include `.platformOptimized` and platform‑specific presets.

  * Ensure related guides reflect the larger language set and increased test coverage.
