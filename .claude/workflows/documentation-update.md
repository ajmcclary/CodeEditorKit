# Documentation Update Workflow

**Sync documentation with current project state** - Updates READMEs, metrics, workflow docs, and status badges.

## Description

Maintains documentation consistency by checking project metrics against the current package layout. The sample app is a SwiftPM target, not a separate package, so all commands run from the repository root.

## Usage

```
@documentation-update
```

## Update Operations

### 1. Collect Current Metrics

```bash
# Markdown inventory
find . -path './.git' -prune -o -path './.build' -prune -o -name '*.md' -print | wc -l

# Source counts
rg --files Sources/CodeEditorKit -g '*.swift' | wc -l
rg --files Sources -g '*.swift' | wc -l
rg --files Tests -g '*Tests.swift' | wc -l

# Test enumeration and quality gates
swift test list | wc -l
swiftlint --fix
swiftlint
swift test --parallel
```

### 2. Update Public Docs

Update these files when metrics or package shape changes:

- `/Users/ajmcclary/Dev/CodeEditor/CodeEditorKit/README.md`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEditorKit/docs/README.md`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEditorKit/AGENTS.md`
- `/Users/ajmcclary/Dev/CodeEditor/CodeEditorKit/CLAUDE.md`

Current stable facts:

- Swift 6.3+, Xcode 26.3+
- Platforms: native macOS 26.0+ and iOS / iPadOS 26.0+
- Mac Catalyst is retired
- Language catalog: 25 concrete languages plus plain text
- Sample app target: `CodeEditorSample`

### 3. Update Assistant Workflow Docs

Keep `.claude/` and `.agents/` Markdown aligned with project commands:

```bash
swift build
swift build --target CodeEditorSample
swiftlint --fix
swiftlint
swift test --parallel
swift test --filter CodeEditorSampleTests
swift run CodeEditorSample
```

Avoid hard-coding total test counts unless they are freshly collected in the same pass. Prefer test-file counts or commands that compute live totals.

### 4. Validate Links

Check local Markdown links after edits:

```bash
python3 - <<'PY'
from pathlib import Path
import re, urllib.parse

root = Path('.').resolve()
mds = [p for p in root.rglob('*.md') if '.git' not in p.parts and '.build' not in p.parts]
link_re = re.compile(r'(?<!!)' + r'\[[^\]]+\]\(([^)]+)\)')
missing = []

for path in mds:
    text = path.read_text(errors='ignore')
    for raw in link_re.findall(text):
        url = raw.strip().strip('<>')
        if not url or url.startswith('#') or re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:', url):
            continue
        target_path = urllib.parse.unquote(url.split('#', 1)[0])
        if target_path and not (path.parent / target_path).resolve().exists():
            missing.append((path.relative_to(root), raw))

if missing:
    for path, raw in missing:
        print(f'{path}: {raw}')
    raise SystemExit(1)
print(f'Checked {len(mds)} Markdown files; no missing local links.')
PY
```

## Success Criteria

- All public metrics match live commands.
- Markdown links resolve locally.
- Active docs do not describe Mac Catalyst as supported.
- Sample-app commands use the `CodeEditorSample` target from the package root.
- Archived superpowers notes (now in the workspace superproject under `docs/archive/package/CodeEditorKit/superpowers/`) are clearly marked as historical when referenced.
