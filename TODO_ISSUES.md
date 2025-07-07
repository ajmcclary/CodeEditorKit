# TODO Issues for CodeEditorPlugin

This file tracks TODO items found in the codebase that should be converted to GitHub issues.

## Platform/CrossPlatformCoordinator+AppKit.swift

### 1. Keyboard Shortcuts Implementation
**Location:** Lines 35-38
**Description:** Implement keyboard shortcuts for:
- Cmd+D: Select next occurrence
- Cmd+L: Select line  
- Cmd+/: Toggle comment
**Priority:** Medium
**Labels:** enhancement, macOS

### 2. Context Menu Actions
**Location:** Lines 93-94, 107-118
**Description:** Implement context menu functionality:
- Toggle Comment
- Format Selection
- Go to Definition
- Find References
**Priority:** Medium
**Labels:** enhancement, macOS, context-menu

## Platform/CrossPlatformCoordinator+UIKit.swift

### 3. iOS Toolbar Actions
**Location:** Lines 44-48
**Description:** Implement toolbar buttons for:
- Undo
- Redo
- Find
**Priority:** Medium
**Labels:** enhancement, iOS, toolbar

### 4. iOS Find Functionality
**Location:** Lines 90-91
**Description:** Implement find functionality (Cmd+F) for iOS
**Priority:** Medium
**Labels:** enhancement, iOS

### 5. iOS Context Menu Actions
**Location:** Lines 153-157
**Description:** Implement context menu for:
- Toggle Comment
**Priority:** Low
**Labels:** enhancement, iOS, context-menu

## Recommended Actions

1. Create GitHub issues for each TODO item
2. Remove TODO comments from code and reference issue numbers instead
3. Prioritize based on user feedback and platform usage
4. Consider implementing basic versions of critical features (undo/redo, find)

## Template for GitHub Issues

```markdown
### [Feature] Implement [Feature Name] for [Platform]

**Description:**
[Detailed description from TODO]

**Location in Code:**
`[File path]:[Line numbers]`

**Acceptance Criteria:**
- [ ] Feature is implemented and working
- [ ] Tests are added
- [ ] Documentation is updated
- [ ] Cross-platform consistency is maintained

**Platform:** [macOS/iOS/Both]
**Priority:** [Low/Medium/High]
```