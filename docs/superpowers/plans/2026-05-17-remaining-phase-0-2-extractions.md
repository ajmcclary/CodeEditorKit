# Remaining Phase 0–2 Extractions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the phase 0–2 restructure by extracting the four remaining internal-only SPM library targets (`CodeEditorTextModel`, `CodeEditorConfiguration`, `CodeEditorPlatform`, `CodeEditorTheming`) from the monolithic `CodeEditorPlugin` umbrella, without changing the umbrella's name or its public consumer-facing API.

**Architecture:** Three phases. Phase A is a single upfront commit that scans the five future-target source dirs (`Text/`, `Documents/`, `Configuration/`, `Platform/`, `Theming/`), identifies `internal`/unmarked declarations referenced from outside their own dir, and promotes them to `package` (Swift 5.9+ cross-target visibility without exposing them as public API). Phase B is four target extractions, each a single commit consisting of `git mv` + `Package.swift` edits + adding `import <Target>` to umbrella files that newly need to name the target. Phase C is final verification.

**Tech Stack:** Swift 6.3, SwiftPM, SwiftLint (strict mode), XCTest + Swift Testing, `package` access modifier (Swift 5.9+).

**Spec:** [`docs/superpowers/specs/2026-05-17-remaining-phase-0-2-extractions-design.md`](../specs/2026-05-17-remaining-phase-0-2-extractions-design.md)

**Prior work in this session:**
- Pre-flight cleanup: commit `cb9cb2e6`
- CodeEditorCommon extraction: commit `f0c438f1`

**Real numbers from recon (2026-05-17):**
- `Text/`: 51 files, 145 unmarked indented declarations
- `Documents/`: 2 files, 0 unmarked indented declarations
- `Configuration/`: 7 files, 9 unmarked indented declarations
- `Platform/`: 34 files, 93 unmarked indented declarations
- `Theming/`: 31 files, 63 unmarked indented declarations
- **Total:** 125 files, ~310 candidate declarations before cross-dir filtering. After filtering, expect 50–150 actual promotion candidates.

---

## File Structure

### Files modified in Phase A (Task 1)

50–150 files in `Sources/CodeEditorPlugin/{Text,Documents,Configuration,Platform,Theming}/` get one or more `package` (or `public`) modifier additions on existing declaration lines. No file moves, no new files, no `Package.swift` changes.

### Files created in Phase B

| Task | Created | Contents |
|---|---|---|
| 2 | `Sources/CodeEditorTextModel/` | Move of `Text/` (51 files) + `Documents/` (2 files) |
| 3 | `Sources/CodeEditorConfiguration/` | Move of `Configuration/` (7 files) |
| 4 | `Sources/CodeEditorPlatform/` | Move of `Platform/` (34 files) |
| 5 | `Sources/CodeEditorTheming/` | Move of `Theming/` (31 files) + `Resources/Themes/` JSON |

### Files modified in Phase B

| File | Modified by Tasks |
|---|---|
| `Package.swift` | Tasks 2, 3, 4, 5 (add `.target(...)` entries + umbrella deps + test target deps) |
| Umbrella files referencing new targets' types | Tasks 2, 3, 4, 5 (add `import <Target>` at top — compiler-driven) |

---

## Task 1: Phase A — `package`-promotion pass (single commit)

**Files:**
- Modify: 50–150 files under `Sources/CodeEditorPlugin/{Text,Documents,Configuration,Platform,Theming}/`
- Create (temporary): `/tmp/manifest.txt`, `/tmp/manifest-script.sh`
- No `Package.swift` changes

This task is iterative within itself. Build green between iterations; ship one commit at the end.

- [ ] **Step 1.1: Verify clean working tree on `main`**

```bash
git status
git branch --show-current
```

Expected: `nothing to commit, working tree clean`, on `main`.

- [ ] **Step 1.2: Capture the post-Task-2 test baseline**

```bash
swift test --parallel 2>&1 | grep -E "Test run with|tests in.*passed"
```

Expected: matches the baseline `Test run with 465 tests in 116 suites passed after ... seconds with 1 known issue.` Record the exact line — the end-of-Phase-A verification (Step 1.10) must match this.

- [ ] **Step 1.3: Write the manifest-building script**

Create `/tmp/manifest-script.sh`:

```bash
#!/bin/bash
# Emits one line per (file, symbol) pair where the symbol is unmarked
# (internal-by-default) AND referenced from outside its own dir.

set -euo pipefail

ROOT="Sources/CodeEditorPlugin"
DIRS=(Text Documents Configuration Platform Theming)

for dir in "${DIRS[@]}"; do
  find "$ROOT/$dir" -name "*.swift" -type f | while read -r file; do
    # Extract unmarked declarations:
    #   4-space indent + keyword + name
    # Keywords we look for: func, var, let, init, static let/var/func, class, struct, enum, typealias, protocol, actor, subscript, mutating func
    grep -nE "^    (func|var|let|init|class|struct|enum|typealias|protocol|actor|subscript|mutating\s+func|static\s+(let|var|func))\b" "$file" \
      | grep -v -E "^[0-9]+:    (public|private|fileprivate|internal|package)\b" \
      | while IFS= read -r match; do
          line_no="${match%%:*}"
          # Extract identifier after the keyword
          # Pattern: `    keyword <name>` or `    keyword <name>(`...
          symbol=$(echo "$match" | sed -E 's/^[0-9]+:    (mutating\s+)?(static\s+)?(func|var|let|init|class|struct|enum|typealias|protocol|actor|subscript)\s+([_A-Za-z][_A-Za-z0-9]*).*/\4/')
          # Skip empty/garbage matches
          [ -z "$symbol" ] && continue
          [ "$symbol" = "$match" ] && continue
          # Check if symbol is referenced from outside this dir
          if grep -rnq --include="*.swift" "\b${symbol}\b" "$ROOT" --exclude-dir="$dir" 2>/dev/null; then
            echo "${file}:${line_no}:${symbol}"
          fi
        done
  done
done
```

Then make it executable:

```bash
chmod +x /tmp/manifest-script.sh
```

- [ ] **Step 1.4: Run the script and save the manifest**

```bash
/tmp/manifest-script.sh > /tmp/manifest.txt
wc -l /tmp/manifest.txt
head -30 /tmp/manifest.txt
```

Expected: `/tmp/manifest.txt` contains 50–150 lines in the form `path/to/file.swift:42:symbolName`. If the count exceeds 200, the script is over-matching — investigate before proceeding (most likely cause: regex catching nested declarations inside types like `enum Inner { let x = 0 }`).

- [ ] **Step 1.5: Hand-review the manifest for `public` candidates**

Open `/tmp/manifest.txt` in an editor. For each entry, decide:
- If the symbol is referenced from `docs/*.md` as part of the documented API surface, **mark it `public`** by editing the line to append ` PUBLIC` at the end: `Sources/CodeEditorPlugin/Configuration/EditorConfiguration.swift:42:applyConfiguration PUBLIC`.
- Otherwise leave it (default = `package`).

Conservative default: leave everything as `package`. Only mark `PUBLIC` if you're certain the symbol is documented external API. The vast majority of entries will be `package`.

Verify the marking:

```bash
echo "PUBLIC count:"
grep -c "PUBLIC$" /tmp/manifest.txt || echo "0"
echo "package (default) count:"
grep -vc "PUBLIC$" /tmp/manifest.txt
```

- [ ] **Step 1.6: Apply promotions**

Run this perl one-liner:

```bash
while IFS=: read -r file line_no symbol_with_flag; do
  symbol="${symbol_with_flag% PUBLIC}"
  if [[ "$symbol_with_flag" == *" PUBLIC" ]]; then
    modifier="public"
  else
    modifier="package"
  fi
  # Insert the modifier before the keyword on the specified line.
  # Patterns to match: leading 4 spaces, then optional `mutating ` or `static `, then keyword.
  perl -i -pe '
    if ($. == '"$line_no"') {
      s/^(    )((?:mutating\s+|static\s+)?)((?:func|var|let|init|class|struct|enum|typealias|protocol|actor|subscript)\b)/$1'"$modifier"' $2$3/;
    }
  ' "$file"
done < /tmp/manifest.txt

echo "Promotions applied. Diff stats:"
git diff --stat | tail -5
```

- [ ] **Step 1.7: Build and triage caveat failures**

```bash
swift build 2>&1 | grep -E "error:" | head -30
```

Three known caveat patterns and their fixes:

1. **"`'package' modifier cannot be used in protocols"`** — the script promoted a protocol member. Find the line, revert to no modifier:

   ```bash
   # For each such error, identify the file and line, then:
   perl -i -pe 'if ($. == <line>) { s/^(    )package /$1/; }' <file>
   ```

2. **"`method cannot be declared package because its parameter uses an internal type"`** or **"`property cannot be declared package because its type uses an internal type`"** — the signature references an `internal` type. Two valid responses:
   - Revert the promotion (keep the method `internal`): same `perl -i -pe` pattern as above.
   - Also promote the referenced type: find it in the source, add a manual entry to `/tmp/manifest.txt`, re-apply Step 1.6 for just that entry. Use this option only if the parameter type is also defined in a future-target dir and is itself genuinely needed cross-target.

3. **"`'public' modifier cannot be used in protocols"`** — same as caveat 1 (same revert).

Iterate Step 1.7 until `swift build` succeeds.

- [ ] **Step 1.8: SwiftLint clean**

```bash
swiftlint --fix 2>&1 | tail -3
swiftlint 2>&1 | tail -3
```

Expected: `Done linting! Found 0 violations, 0 serious in <N> files.`

If `missing_docs` violations appear on `public` declarations (not `package`), revisit Step 1.5 — either revert the symbol back to `package` if it doesn't really need to be public, or add minimal doc comments.

- [ ] **Step 1.9: Run full test suite**

```bash
swift test --parallel 2>&1 | tail -3
```

Expected: matches the baseline from Step 1.2 — 465 tests in 116 suites pass.

- [ ] **Step 1.10: Commit**

```bash
git add -A
git status --short | wc -l
# Confirm: 30-60 files modified, no files moved, no new files
git commit -m "$(cat <<'EOF'
Promote cross-boundary symbols to package for upcoming extractions

Single upfront access-modifier pass for the four remaining
phase 0-2 target extractions (TextModel, Configuration, Platform,
Theming). Promotes internal/unmarked declarations in those source
dirs to `package` if they're referenced from outside their own
dir, using a scripted scan of Sources/CodeEditorPlugin/ + grep
for cross-dir references. `public` reserved for genuinely
user-facing API (verified via docs/ grep).

The intent is to make subsequent target extractions near-mechanical
moves rather than the ~30-promotion exercise that Task 2 turned
into for CodeEditorCommon.

No file moves, no Package.swift changes, no public-API additions.

Spec: docs/superpowers/specs/2026-05-17-remaining-phase-0-2-extractions-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"

git log --oneline -1
```

---

## Task 2: Phase B — Extract `CodeEditorTextModel`

**Files:**
- Move: `Sources/CodeEditorPlugin/Text/` (51 files) → `Sources/CodeEditorTextModel/Text/`
- Move: `Sources/CodeEditorPlugin/Documents/` (2 files) → `Sources/CodeEditorTextModel/Documents/`
- Modify: `Package.swift` (add `.target` entry, add umbrella + test target deps)
- Modify: ~30–60 umbrella files (add `import CodeEditorTextModel` at top)

- [ ] **Step 2.1: Move `Text/` and `Documents/` directories**

```bash
mkdir -p Sources/CodeEditorTextModel
git mv Sources/CodeEditorPlugin/Text Sources/CodeEditorTextModel/Text
git mv Sources/CodeEditorPlugin/Documents Sources/CodeEditorTextModel/Documents
ls Sources/CodeEditorTextModel/
ls Sources/CodeEditorPlugin/ | grep -E "^(Text|Documents)$" && echo "ERROR: dirs still in umbrella" || echo "OK"
```

Expected: `ls Sources/CodeEditorTextModel/` shows `Text/` and `Documents/`. Umbrella no longer contains those dirs.

- [ ] **Step 2.2: Add `CodeEditorTextModel` target to `Package.swift`**

Open `Package.swift`. Find the `CodeEditorCommon` target entry (added in Task 2 of the prior plan, commit `f0c438f1`). After it, insert:

```swift
        .target(
            name: "CodeEditorTextModel",
            dependencies: ["CodeEditorCommon"],
            swiftSettings: swiftSettings
        ),
```

In the `CodeEditorPlugin` target's `dependencies:` array, add `"CodeEditorTextModel"` (preserve alphabetical order):

```swift
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorDesignTokens",
                "CodeEditorTextModel",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
```

- [ ] **Step 2.3: First build — surface the import additions**

```bash
swift build 2>&1 | grep -oE "/Users/ajmcclary[^[:space:]]+\.swift" | sort -u > /tmp/textmodel-import-files.txt
wc -l /tmp/textmodel-import-files.txt
head -10 /tmp/textmodel-import-files.txt
```

Expected: 20–60 unique file paths. These are umbrella files that reference types now living in `CodeEditorTextModel` and need `import CodeEditorTextModel` added.

If the count is 0, the build succeeded — skip Step 2.4 and go to Step 2.5.

- [ ] **Step 2.4: Add `import CodeEditorTextModel` to each file**

```bash
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if grep -q "^import CodeEditorTextModel" "$f" 2>/dev/null; then continue; fi
  awk 'BEGIN{a=0} /^import / && a==0 {print; print "import CodeEditorTextModel"; a=1; next} {print}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done < /tmp/textmodel-import-files.txt

echo "Imports added. Rebuilding..."
swift build 2>&1 | grep -E "error:" | head -10
```

Expected: build succeeds, or shows a smaller set of follow-up errors. Iterate by rerunning Step 2.3 + 2.4 until clean.

If errors persist beyond import-missing, see Section "Failure-mode handling" at the end of this plan.

- [ ] **Step 2.5: Update test target deps**

Test files that use `@testable import CodeEditorPlugin` see CodeEditorPlugin internals but NOT the new target's internals. If any test uses internal types from `CodeEditorTextModel`, it needs:
- `CodeEditorTextModel` added to its target's `dependencies:` in `Package.swift`, AND
- `@testable import CodeEditorTextModel` at the top of the failing file (only if the test references *internal* types — for `package` and `public` types, just `import CodeEditorTextModel` is enough).

Run tests to find failures:

```bash
swift test --parallel 2>&1 | grep -E "error: cannot find" | head -10
```

If failures surface, identify the test target by file path (e.g. `Tests/CodeEditorPluginTests/...` → `CodeEditorPluginTests`), then edit `Package.swift` to add `"CodeEditorTextModel"` to that test target's `dependencies:`:

```swift
        .testTarget(
            name: "CodeEditorPluginTests",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorPlugin",
                "CodeEditorTextModel",
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            ...
        ),
```

And for each failing test file, add `import CodeEditorTextModel` (or `@testable import CodeEditorTextModel` if internal-access is needed):

```bash
swift test --parallel 2>&1 | grep -oE "/Users/ajmcclary[^[:space:]]+\.swift" | sort -u | while read f; do
  if grep -q "^import CodeEditorTextModel\|^@testable import CodeEditorTextModel" "$f" 2>/dev/null; then continue; fi
  awk 'BEGIN{a=0} /^import / && a==0 {print; print "import CodeEditorTextModel"; a=1; next} {print}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done

swift test --parallel 2>&1 | tail -3
```

Expected: 465 tests in 116 suites pass.

- [ ] **Step 2.6: SwiftLint clean**

```bash
swiftlint --fix 2>&1 | tail -2
swiftlint 2>&1 | tail -3
```

Expected: `Found 0 violations`.

- [ ] **Step 2.7: Commit**

```bash
git add -A
git status --short | head -10
git commit -m "$(cat <<'EOF'
Extract CodeEditorTextModel target (phase 1)

Moves Text/ (51 files) and Documents/ (2 files) to a new
internal-only SPM target depending on CodeEditorCommon. Phase A's
package-promotion pass made the cross-boundary symbols reachable
without per-extraction access-modifier surgery. Per-target work
in this commit is git mv + Package.swift + import additions.

Spec: docs/superpowers/specs/2026-05-17-remaining-phase-0-2-extractions-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Phase B — Extract `CodeEditorConfiguration`

**Files:**
- Move: `Sources/CodeEditorPlugin/Configuration/` (7 files) → `Sources/CodeEditorConfiguration/`
- Modify: `Package.swift`
- Modify: ~10–25 umbrella files (add `import CodeEditorConfiguration`)

- [ ] **Step 3.1: Move `Configuration/`**

```bash
git mv Sources/CodeEditorPlugin/Configuration Sources/CodeEditorConfiguration
ls Sources/CodeEditorConfiguration/
```

Expected: 7 files.

- [ ] **Step 3.2: Add target to `Package.swift`**

After the `CodeEditorTextModel` entry:

```swift
        .target(
            name: "CodeEditorConfiguration",
            dependencies: ["CodeEditorCommon", "CodeEditorTextModel"],
            swiftSettings: swiftSettings
        ),
```

In `CodeEditorPlugin`'s `dependencies:`, add `"CodeEditorConfiguration"`:

```swift
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDesignTokens",
                "CodeEditorTextModel",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
```

- [ ] **Step 3.3: Build and add imports**

```bash
swift build 2>&1 | grep -oE "/Users/ajmcclary[^[:space:]]+\.swift" | sort -u > /tmp/config-import-files.txt
wc -l /tmp/config-import-files.txt

while IFS= read -r f; do
  [ -z "$f" ] && continue
  if grep -q "^import CodeEditorConfiguration" "$f" 2>/dev/null; then continue; fi
  awk 'BEGIN{a=0} /^import / && a==0 {print; print "import CodeEditorConfiguration"; a=1; next} {print}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done < /tmp/config-import-files.txt

swift build 2>&1 | grep -E "error:" | head -10
```

Iterate until build is clean.

- [ ] **Step 3.4: Update test target deps and run tests**

Same pattern as Step 2.5 — add `"CodeEditorConfiguration"` to the `CodeEditorPluginTests` target's `dependencies:` (and `CodeEditorSampleTests` if relevant), and add `import CodeEditorConfiguration` to any failing test file.

```bash
swift test --parallel 2>&1 | tail -3
```

Expected: 465 tests pass.

- [ ] **Step 3.5: SwiftLint clean**

```bash
swiftlint --fix 2>&1 | tail -2
swiftlint 2>&1 | tail -3
```

- [ ] **Step 3.6: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Extract CodeEditorConfiguration target (phase 1)

Moves Configuration/ (7 files) to a new internal-only SPM target
depending on CodeEditorCommon and CodeEditorTextModel.

Spec: docs/superpowers/specs/2026-05-17-remaining-phase-0-2-extractions-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Phase B — Extract `CodeEditorPlatform`

**Files:**
- Move: `Sources/CodeEditorPlugin/Platform/` (34 files) → `Sources/CodeEditorPlatform/`
- Modify: `Package.swift`
- Modify: ~20–40 umbrella files (add `import CodeEditorPlatform`)

Per the flipped graph from the prior spec (gap #3), Platform depends on Configuration (not the reverse).

- [ ] **Step 4.1: Move `Platform/`**

```bash
git mv Sources/CodeEditorPlugin/Platform Sources/CodeEditorPlatform
ls Sources/CodeEditorPlatform/ | wc -l
```

Expected: 34 files.

- [ ] **Step 4.2: Add target to `Package.swift`**

After the `CodeEditorConfiguration` entry:

```swift
        .target(
            name: "CodeEditorPlatform",
            dependencies: ["CodeEditorConfiguration"],
            swiftSettings: swiftSettings
        ),
```

(Common reaches Platform via transitive linkage through Configuration.)

In `CodeEditorPlugin`'s `dependencies:`, add `"CodeEditorPlatform"`:

```swift
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDesignTokens",
                "CodeEditorPlatform",
                "CodeEditorTextModel",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
```

- [ ] **Step 4.3: Build and add imports**

```bash
swift build 2>&1 | grep -oE "/Users/ajmcclary[^[:space:]]+\.swift" | sort -u > /tmp/platform-import-files.txt
wc -l /tmp/platform-import-files.txt

while IFS= read -r f; do
  [ -z "$f" ] && continue
  if grep -q "^import CodeEditorPlatform" "$f" 2>/dev/null; then continue; fi
  awk 'BEGIN{a=0} /^import / && a==0 {print; print "import CodeEditorPlatform"; a=1; next} {print}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done < /tmp/platform-import-files.txt

swift build 2>&1 | grep -E "error:" | head -10
```

Iterate until clean.

- [ ] **Step 4.4: Update test target deps and run tests**

Same pattern as Step 2.5. Run `swift test --parallel`.

Expected: 465 tests pass.

- [ ] **Step 4.5: SwiftLint clean**

```bash
swiftlint --fix 2>&1 | tail -2
swiftlint 2>&1 | tail -3
```

- [ ] **Step 4.6: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Extract CodeEditorPlatform target (phase 2)

Moves Platform/ (34 files) to a new internal-only SPM target.
Per the flipped graph from the prior spec, CodeEditorPlatform
depends on CodeEditorConfiguration (Common is transitive).

Spec: docs/superpowers/specs/2026-05-17-remaining-phase-0-2-extractions-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Phase B — Extract `CodeEditorTheming`

**Files:**
- Move: `Sources/CodeEditorPlugin/Theming/` (31 files) → `Sources/CodeEditorTheming/`
- Move: `Sources/CodeEditorPlugin/Resources/Themes/` JSON → `Sources/CodeEditorTheming/Resources/Themes/`
- Modify: `Package.swift` (add target, remove umbrella `resources:` entry, add it to new target)
- Modify: ~20–40 umbrella files (add `import CodeEditorTheming`)

- [ ] **Step 5.1: Move `Theming/` and `Resources/Themes/`**

```bash
mkdir -p Sources/CodeEditorTheming/Resources
git mv Sources/CodeEditorPlugin/Theming/* Sources/CodeEditorTheming/ 2>/dev/null
# Handle subdirs of Theming/ that git mv may not move atomically
[ -d Sources/CodeEditorPlugin/Theming ] && rmdir Sources/CodeEditorPlugin/Theming 2>/dev/null || true
git mv Sources/CodeEditorPlugin/Resources/Themes Sources/CodeEditorTheming/Resources/Themes
[ -d Sources/CodeEditorPlugin/Resources ] && rmdir Sources/CodeEditorPlugin/Resources 2>/dev/null || true

ls Sources/CodeEditorTheming/ | head -20
ls Sources/CodeEditorTheming/Resources/Themes/
```

Expected: `CodeEditorTheming/` contains the 31 Theming files (plus subdirs `Bridges/`, `Internal/`, `Loader/`). `Resources/Themes/zed-trek.json` exists at the new path.

If `Sources/CodeEditorPlugin/Theming/` still exists (because git mv with a wildcard leaves subdirs):

```bash
git mv Sources/CodeEditorPlugin/Theming/Bridges Sources/CodeEditorTheming/Bridges
git mv Sources/CodeEditorPlugin/Theming/Internal Sources/CodeEditorTheming/Internal
git mv Sources/CodeEditorPlugin/Theming/Loader Sources/CodeEditorTheming/Loader
rmdir Sources/CodeEditorPlugin/Theming
```

- [ ] **Step 5.2: Add `CodeEditorTheming` target and remove umbrella's `resources:` entry**

In `Package.swift`, after the `CodeEditorPlatform` entry, insert:

```swift
        .target(
            name: "CodeEditorTheming",
            dependencies: ["CodeEditorDesignTokens"],
            resources: [
                .process("Resources/Themes")
            ],
            swiftSettings: swiftSettings
        ),
```

In the `CodeEditorPlugin` target block, **remove** the existing `resources:` entry:

```swift
            // REMOVE this block:
            resources: [
                .process("Resources/Themes")
            ],
```

In `CodeEditorPlugin`'s `dependencies:`, add `"CodeEditorTheming"`:

```swift
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDesignTokens",
                "CodeEditorPlatform",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
```

- [ ] **Step 5.3: Build and add imports**

```bash
swift build 2>&1 | grep -oE "/Users/ajmcclary[^[:space:]]+\.swift" | sort -u > /tmp/theming-import-files.txt
wc -l /tmp/theming-import-files.txt

while IFS= read -r f; do
  [ -z "$f" ] && continue
  if grep -q "^import CodeEditorTheming" "$f" 2>/dev/null; then continue; fi
  awk 'BEGIN{a=0} /^import / && a==0 {print; print "import CodeEditorTheming"; a=1; next} {print}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done < /tmp/theming-import-files.txt

swift build 2>&1 | grep -E "error:" | head -10
```

Iterate until clean.

- [ ] **Step 5.4: Sample-app smoke test (theme loading)**

This is the critical runtime check. `Bundle.module` resolves to whichever target's bundle the calling file lives in. After this move, theme loading code in `CodeEditorTheming/Loader/` resolves to `CodeEditorTheming.bundle`, but any code outside that target loading themes via its own `Bundle.module` will load from the wrong bundle.

```bash
swift run CodeEditorSample &
SAMPLE_PID=$!
sleep 5
# Check the app started; the human operator then visually verifies themes load
kill -0 $SAMPLE_PID 2>/dev/null && echo "Sample app running (PID $SAMPLE_PID); manually verify themes render in the running window, then ctrl-C / kill the process"
```

The operator opens the running sample app and:
- Confirms the default theme renders (gutter color, syntax colors visible).
- Switches to each other bundled theme via the theme picker.
- Verifies each theme's colors change visibly.

If themes fail to load (e.g. plain black-on-white text with no syntax colors), there's a `Bundle.module` resolution bug — likely in code outside `CodeEditorTheming` that loads themes itself.

**Fix path if it fails:** find every `Bundle.module` reference in the codebase, route all theme loading through a `CodeEditorTheming`-public `themesBundle: Bundle` accessor that returns `Bundle.module` from within the new target. Files outside `CodeEditorTheming` call that accessor instead of their own `Bundle.module`.

- [ ] **Step 5.5: Update test target deps and run tests**

Same pattern as Step 2.5. Pay particular attention to `Tests/CodeEditorPluginTests/Theming/` — these snapshot tests are the strongest signal that theme loading is intact.

```bash
swift test --parallel 2>&1 | tail -3
```

Expected: 465 tests pass.

If snapshot tests fail (visible diffs in `Tests/CodeEditorPluginTests/Theming/__Snapshots__/`), **do not** re-record. The failure indicates a real theme-loading regression. Diagnose before continuing.

- [ ] **Step 5.6: SwiftLint clean**

```bash
swiftlint --fix 2>&1 | tail -2
swiftlint 2>&1 | tail -3
```

- [ ] **Step 5.7: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Extract CodeEditorTheming target (phase 2)

Moves Theming/ (31 files) and Resources/Themes/ JSON to a new
internal-only SPM target depending on CodeEditorDesignTokens
(Theming is a true leaf - the prior spec's claim that it depends
on Platform was unsubstantiated by any actual code references).

Umbrella's resources: entry removed; CodeEditorTheming owns the
bundle. Sample app smoke-tested via swift run.

Spec: docs/superpowers/specs/2026-05-17-remaining-phase-0-2-extractions-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Phase C — Final verification

**Files:** none modified — verification only.

- [ ] **Step 6.1: Confirm directory structure**

```bash
ls Sources/
```

Expected output (10 entries, alphabetical):

```
CodeEditorCommon
CodeEditorConfiguration
CodeEditorDesignTokens
CodeEditorPlatform
CodeEditorPlugin
CodeEditorSample
CodeEditorTextModel
CodeEditorTheming
CodeEditorTreeSitterLanguages
CodeEditorUI
```

```bash
ls Sources/CodeEditorPlugin/
```

Expected: no `Text/`, `Documents/`, `Configuration/`, `Platform/`, `Theming/`, or `Resources/`. Remaining dirs should be roughly: `Annotations/`, `Completion/`, `Core/`, `Features/`, `LSP/`, `Layout/`, `Performance/`, `Search/`, `SwiftUI/`, `SyntaxHighlighting/`, `Workspace/`, plus `CodeEditorPlugin.swift` and `Info.plist`.

- [ ] **Step 6.2: Full parallel test run**

```bash
swift test --parallel 2>&1 | tail -3
```

Expected: 465 tests pass.

- [ ] **Step 6.3: Final SwiftLint pass**

```bash
swiftlint --fix 2>&1 | tail -2
swiftlint 2>&1 | tail -3
```

Expected: 0 violations.

- [ ] **Step 6.4: Confirm package shape**

```bash
swift package describe 2>&1 | grep -E "Module:|Target:" | sort -u
```

Expected: 10 modules / targets visible.

- [ ] **Step 6.5: Confirm commit count**

```bash
git log --oneline -10
```

Expected: at least 5 new commits since `f0c438f1` (Task 1 promotion + Tasks 2–5 extractions). If a Phase A or Phase B fix-up commit was inserted, the count is 6+.

- [ ] **Step 6.6: Optional cleanup commit**

If during the session any small cleanup landed unstaged (lint-fix artifacts, etc.), commit it:

```bash
git status
# If staged:
git commit -m "$(cat <<'EOF'
Final cleanup after phase 0-2 target extractions

Spec: docs/superpowers/specs/2026-05-17-remaining-phase-0-2-extractions-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Otherwise skip.

---

## Failure-mode handling

These are responses to scenarios where the plan's happy path doesn't land cleanly.

### F1 — Phase A's bulk promotion has too many caveat failures

Symptom: Step 1.7 surfaces 20+ caveat errors that can't be cleanly reverted.

Fix: stop. Revert all unstaged changes (`git restore --staged --worktree Sources/`). Re-brainstorm whether `package` is the right modifier, or whether a coarser bulk approach (promote ALL unmarked decls in the dirs) is necessary.

### F2 — A Phase B extraction surfaces missed promotions from Phase A

Symptom: during Step 2.4 / 3.3 / 4.3 / 5.3, errors persist beyond "add an import" — typically `'X' is inaccessible due to 'internal' protection level`.

Fix: identify the inaccessible symbol(s). Insert a **new commit** (not an amendment) BEFORE the extraction:

```bash
# Edit the source file to promote the symbol manually (Edit tool).
git add <file>
git commit -m "Promote <symbol> for upcoming extraction (Phase A miss)"
```

Then redo the extraction's Steps from 2.3 / 3.3 / 4.3 / 5.3.

### F3 — A Phase B extraction surfaces cross-target leaks

Symptom: during Step 2.3 / 3.3 / 4.3 / 5.3, errors say `cannot find type 'X' in scope` and `X` is defined in a still-umbrella dir that the extracting dir is now separated from.

Fix: move the offending file in the extracting target back to umbrella, in its semantic home (Core/, Layout/, etc.). Same pattern as Task 2's surgery. Re-run the extraction's Steps.

### F4 — A Phase B extraction exceeds 30 file edits beyond imports

Symptom: the surgical pattern (F2 + F3) accumulates more than 30 file edits in a single extraction.

Fix: stop the session. The upfront Phase A pass was insufficient and the design assumption ("near-mechanical moves") doesn't hold for this target. Bring findings back to brainstorm.

### F5 — Theme JSON bundle resolution silently broken after Task 5

Symptom: Step 5.4 sample-app smoke test shows themes don't render correctly even though the build is green and tests pass.

Fix: see the "Fix path if it fails" guidance in Step 5.4. If unable to resolve in <30 minutes, roll back Task 5's commit:

```bash
git reset --hard HEAD~1
```

and stop. Tasks 1–4 (CodeEditorCommon, TextModel, Configuration, Platform extractions) are independently complete and shippable.

---

## Self-review notes

The plan was self-reviewed before saving:

- **Spec coverage:** Each spec section maps to plan tasks. §1 (why this spec exists) → no task needed; §2 (architecture) → Tasks 1–6 collectively; §3 (Phase A) → Task 1; §4 (Phase B) → Tasks 2–5; §5 (testing) → per-task verification steps; §6 (risks) → Failure-mode handling F1–F5 (R1↔F2, R2↔F3, R3↔F5, R4 handled in-step via `@testable import`, R5 handled in-step in Task 1, R6 inherited from prior spec); §7 (exit criteria) → Task 6; §8 (out of scope) → no task needed (documented).
- **Placeholder scan:** No TBDs, TODOs, "implement later" markers. Manifest examples in Task 1 Step 1.3 are concrete bash script content, not placeholders.
- **Type consistency:** All target names (`CodeEditorTextModel`, `CodeEditorConfiguration`, `CodeEditorPlatform`, `CodeEditorTheming`) are used consistently across plan tasks. `import` statement form (`import <Target>`) is consistent. `package` and `public` modifier usage matches spec.
- **Cumulative dependency order in `Package.swift`:** Each task's `CodeEditorPlugin` `dependencies:` array shows the FULL cumulative list, not just the new entry, so the engineer doesn't need to track running state.
- **Cleanup of intermediate state:** Each commit leaves `swift build`, `swift test`, and `swiftlint` green; no commit forces follow-up cleanup before the next can start.
