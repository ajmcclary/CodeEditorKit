# Git Commit and Push Workflow

**Intelligent commit creation and pushing** - Analyzes changes and creates meaningful commits

## Description
Creates well-structured commits by analyzing staged and unstaged changes, following the project's commit message conventions, and safely pushing to the remote repository.

## Usage
```
@git-commit-push
```

## Workflow Steps

### 1. Analyze Current State
```bash
git status
git diff --staged
git diff
git log --oneline -5
```

### 2. Stage Relevant Changes
Stage files based on change analysis:
```bash
# Quality improvements
git add .swiftlint.yml
git add Sources/ Tests/

# Documentation updates
git add README.md docs/ CLAUDE.md AGENTS.md .claude/ .agents/

# Configuration changes
git add Package.swift .claude/
```

### 3. Generate Commit Message
Create structured commit following project conventions:

#### Commit Message Format
```
{type}: {description}

{detailed_body}

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

#### Commit Types
- **feat**: New features or capabilities
- **fix**: Bug fixes and error corrections
- **refactor**: Code restructuring without functionality changes
- **docs**: Documentation updates
- **test**: Test additions or modifications
- **perf**: Performance improvements
- **style**: Code style and formatting
- **chore**: Maintenance and tooling

### 4. Create Commit with HEREDOC
```bash
git commit -m "$(cat <<'EOF'
{type}: {description}

{detailed_explanation}
- Key changes and improvements
- Impact on functionality
- Quality metrics updates

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### 5. Push to Remote
```bash
git push origin main
```

## Commit Message Examples

### Quality Improvements
```
fix: Complete CodeEditorSample integration and update documentation

- Fix EditorConfigurationBuilder method names in sample app
  - .editable() → .isEditable()
  - .annotations() → .enableAnnotations()
  - .hardwareAcceleration() → .useHardwareAcceleration()
- Update test counts and quality metrics  
- Add status badges to both READMEs

All requested SwiftPM tests passing
All linting clean for configured Sources and Tests paths

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Feature Additions
```
feat: Add comprehensive Claude Code workflow system

- Create .claude/workflows directory with 8 workflows
- Add swift-quality-check for daily development
- Add swift-full-pipeline for release preparation
- Add sample-app-workflow for demo validation
- Add documentation-update for metric synchronization

Workflows streamline development process and ensure quality standards

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Documentation Updates
```
docs: Update README metrics and add Sample Application section

- Update test-file count badge from live `rg --files Tests -g '*Tests.swift'`
- Update quality metrics from live SwiftLint output
- Add comprehensive Sample Application showcase section
- Sync achievement callouts across all documentation

Documentation now accurately reflects project quality and capabilities

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Change Analysis Patterns

### Code Quality Changes
Look for:
- SwiftLint configuration changes
- Test modifications or additions
- Linting violation fixes
- Build configuration updates

### Feature Development
Look for:
- New source files
- API additions or modifications
- Configuration system changes
- Sample app updates

### Documentation Updates
Look for:
- README modifications
- Documentation file changes
- Comment and inline doc updates
- Metric synchronization

### Refactoring and Cleanup
Look for:
- File reorganization
- Method signature changes
- Import statement updates
- Deprecation removals

## Success Criteria
- ✅ Relevant files staged for commit
- ✅ Commit message follows project conventions
- ✅ Detailed explanation of changes provided
- ✅ Impact and metrics included where relevant
- ✅ Successfully pushed to remote repository

## Error Handling

### Unstaged Changes
If important changes aren't staged:
1. Review `git status` output
2. Stage additional relevant files
3. Re-run commit creation

### Commit Message Issues
If commit message doesn't meet standards:
1. Follow project conventions more closely
2. Include more detail about changes
3. Ensure proper formatting and structure

### Push Failures
If push fails:
1. Check remote repository status
2. Pull latest changes if needed: `git pull --rebase`
3. Resolve any conflicts
4. Retry push

### Merge Conflicts
If conflicts occur:
1. Review conflicting files
2. Resolve conflicts maintaining code quality
3. Re-run quality checks after resolution
4. Create new commit for conflict resolution

## Pre-Commit Validation

### Quality Gates
Before committing, ensure:
- All tests pass (run `@swift-quality-check`)
- No linting violations
- Documentation is current
- Build succeeds on all platforms

### Change Review
Verify changes include:
- Proper error handling
- Appropriate test coverage
- Documentation updates
- Quality improvements

## Integration Points

### With Quality Workflows
Run quality checks before committing:
```
@swift-quality-check
@git-commit-push
```

### With Documentation
Sync docs before committing:
```
@documentation-update
@git-commit-push
```

### With Release Process
For release commits:
```
@swift-full-pipeline
@git-commit-push
```

## Repository Information
- **Remote**: origin (https://github.com/ajmcclary/CodeEditorKit.git)
- **Main Branch**: main
- **Commit Standards**: Conventional commits with detailed bodies
- **Push Strategy**: Direct to main (ensure quality first)

## Notes
This workflow ensures:
- Meaningful commit history
- Proper change attribution
- Project convention compliance
- Safe remote repository updates

Always run quality checks before committing to maintain the project's zero-violation, 100% pass rate standards.
