# Interaction Design Requirements: Spatial Conversational Workspace / Horizontally Stacked Agent Panels

## 1. Pattern Definition

The interface should support a **spatial conversational workspace** in which the primary chat thread and related work surfaces coexist as horizontally stacked panels.

The user should not experience the AI conversation as a single linear sidebar. Instead, the system should treat every meaningful output, artifact, file, diff, task, tool result, or sub-conversation as a **persistent work context** that can open beside the chat thread.

The core interaction model is:

> A user converses with an AI agent in a primary thread. As the conversation produces work artifacts or requires inspection of related context, panels open horizontally next to the thread. Each panel has its own identity, state, history, and relationship to the conversation.

This pattern is especially appropriate for AI-native developer tools, design tools, research tools, data tools, workflow automation products, and other environments where the user needs to inspect, compare, approve, and iterate across multiple parallel contexts.

---

# 2. Core UX Principles

## 2.1 Conversation Is the Anchor

The chat thread should remain the conceptual anchor of the workspace.

Even when the user is working inside a panel, the user should understand:

* which conversation produced the panel,
* which agent action created it,
* which prompt or message it is related to,
* whether the panel is current, stale, running, or completed,
* and whether follow-up prompts will apply to that panel, the whole workspace, or another selected context.

The chat thread does not have to remain fully visible at all times, but it must remain easily recoverable.

---

## 2.2 Panels Are Work Contexts, Not Popovers

Panels should not behave like temporary overlays.

A panel should be treated as a durable workspace object with:

* a title,
* a type,
* a source,
* a lifecycle state,
* an origin relationship,
* optional unsaved changes,
* optional agent activity,
* and a recoverable history.

Panels should persist until the user explicitly closes, collapses, archives, or replaces them.

---

## 2.3 Horizontal Space Represents Parallel Thought

The horizontal stack should communicate that the user is moving across related contexts, not descending into a hidden modal flow.

Left-to-right order should generally imply:

```text
Conversation → Related output → Supporting detail → Deeper inspection → Action/review
```

The user should be able to visually reconstruct how they arrived at the current panel.

---

## 2.4 The System Should Avoid Panel Explosion

The interface should make it easy to open useful contexts without creating an unmanageable pile of panes.

The system should provide:

* reuse behavior for already-open panels,
* preview states,
* collapse behavior,
* workspace summaries,
* overflow navigation,
* panel search,
* and clear close/archive controls.

Opening a panel should feel powerful, not chaotic.

---

# 3. Information Architecture Requirements

## IA-1: Workspace Structure

The workspace must be composed of the following conceptual regions:

```text
Global Navigation
└── Project / Session / Workspace
    └── Primary Conversation Thread
        ├── Message
        │   ├── Artifact Reference
        │   ├── Tool Result Reference
        │   ├── File Reference
        │   └── Agent Action
        └── Panel Stack
            ├── Panel 1
            ├── Panel 2
            ├── Panel 3
            └── Overflow / Collapsed Panels
```

The system must preserve the relationship between the conversation and the panels it generates.

---

## IA-2: Panel Types

The design should support at least the following panel types:

| Panel Type                     | Purpose                                                       |
| ------------------------------ | ------------------------------------------------------------- |
| **Chat thread**                | Primary conversation and command surface                      |
| **Artifact panel**             | Generated document, code, prototype, plan, or output          |
| **File panel**                 | Existing source file or project resource                      |
| **Diff panel**                 | Before/after comparison, proposed change, review surface      |
| **Preview panel**              | Rendered app, web page, document, diagram, or design preview  |
| **Terminal / execution panel** | Command execution, logs, test output, build result            |
| **Task panel**                 | Agent task status, checklist, subtasks, background work       |
| **Inspector panel**            | Metadata, references, permissions, context, variables         |
| **Search / results panel**     | Search results, citations, references, retrieved context      |
| **Approval panel**             | Confirmation for risky, irreversible, or external actions     |
| **Settings / context panel**   | Agent rules, selected files, memory, environment, permissions |

Each panel type should have a distinct icon, header treatment, and state vocabulary.

---

## IA-3: Panel Identity

Every panel must have a stable identity.

A panel identity should include:

* unique panel ID,
* human-readable title,
* panel type,
* source object ID, when applicable,
* originating message ID,
* originating agent action ID,
* creation timestamp,
* active/stale status,
* dirty/unsaved status,
* parent panel ID, when applicable,
* and close/archive state.

The UI should never rely only on visible position to define a panel.

---

## IA-4: Parent-Child Relationships

Panels should preserve parent-child relationships.

For example:

```text
Chat prompt
└── Plan panel
    └── File change panel
        └── Diff panel
            └── Test output panel
```

The user should be able to see this relationship through breadcrumbs, hover previews, subtle connector lines, or message-level references.

---

# 4. Layout Requirements

## L-1: Primary Layout

The default desktop layout should use a horizontal stack.

Recommended structure:

```text
[Conversation] [Panel A] [Panel B] [Panel C]
```

The conversation thread should open at the left edge of the stack by default.

The newest or most recently opened panel should appear to the right of the panel that initiated it.

---

## L-2: Panel Widths

Panels should have type-specific preferred widths.

Recommended defaults:

| Panel Type    | Minimum Width | Preferred Width | Maximum Useful Width |
| ------------- | ------------: | --------------: | -------------------: |
| Chat thread   |        360 px |      440–520 px |               680 px |
| Text artifact |        420 px |      560–720 px |               900 px |
| Code file     |        480 px |      640–840 px |              1100 px |
| Diff          |        640 px |     800–1100 px |              1400 px |
| Preview       |        480 px |     720–1200 px |              1600 px |
| Terminal/logs |        480 px |      640–900 px |              1200 px |
| Inspector     |        320 px |      360–440 px |               560 px |
| Approval      |        420 px |      520–640 px |               760 px |

The system should not compress panels below their minimum usable width. When space is insufficient, it should introduce overflow behavior rather than creating unusable narrow columns.

---

## L-3: Horizontal Overflow

When the panel stack exceeds available viewport width, the system should provide horizontal navigation.

Acceptable overflow behaviors include:

* horizontal scroll with snap points,
* a panel rail,
* collapsed panel chips,
* an overview map,
* keyboard navigation,
* or a “show all panels” switcher.

The user must always be able to answer:

* Where am I?
* What panels are open?
* Which panel is active?
* What is offscreen?
* How do I return to the chat?

---

## L-4: Panel Stack Order

Panel order should be deterministic.

Default behavior:

1. The chat thread is the leftmost anchor.
2. A panel opened from the chat appears immediately to the right of the chat.
3. A panel opened from another panel appears immediately to the right of that panel.
4. If there are existing child panels to the right, the new panel should either:

   * replace the descendant branch, or
   * insert after the parent and push descendants right,
     depending on the product’s chosen navigation model.
5. The system must make this behavior consistent.

For most AI workspaces, the recommended model is:

> Opening a new child panel from a parent should preserve existing panels unless the new action is explicitly a replacement.

This better supports parallel comparison.

---

## L-5: Active Panel

Only one panel should be considered the **active panel** at a time.

The active panel should determine:

* which context appears in the chat composer,
* which keyboard shortcuts apply,
* which object receives agent instructions,
* which panel-level actions are shown,
* and which state is announced to assistive technology.

The active panel must have a clear visual state.

Recommended active indicators:

* stronger header treatment,
* subtle border emphasis,
* active breadcrumb state,
* active panel chip in the rail,
* and context chip in the chat composer.

Avoid relying on color alone.

---

## L-6: Resizing

Users should be able to resize panels horizontally.

Resize requirements:

* Each panel boundary should have a draggable resize handle.
* Resize handles should have visible hover and active states.
* Resize should snap to meaningful widths.
* Double-clicking a resize handle may reset adjacent panels to preferred widths.
* Keyboard resizing must be supported.
* Minimum widths must be enforced.
* Resizing one panel should not unpredictably collapse another panel.

Recommended keyboard behavior:

| Shortcut                 | Behavior                   |
| ------------------------ | -------------------------- |
| `Alt/Option + [`         | Narrow active panel        |
| `Alt/Option + ]`         | Widen active panel         |
| `Shift + Alt/Option + [` | Narrow in larger increment |
| `Shift + Alt/Option + ]` | Widen in larger increment  |

---

## L-7: Collapse

Users should be able to collapse panels without closing them.

Collapsed panels should remain represented in the UI as:

* rail items,
* chips,
* icons,
* tabs,
* or entries in a panel switcher.

Collapsed panels should retain:

* title,
* type,
* dirty state,
* running state,
* error state,
* unread/new activity state,
* and relationship to parent panel.

Collapsed panels should be restorable with one click or keyboard action.

---

## L-8: Close

Users should be able to close panels.

Closing behavior must respect state:

| Panel State              | Close Behavior                                             |
| ------------------------ | ---------------------------------------------------------- |
| Clean, idle panel        | Close immediately                                          |
| Unsaved changes          | Confirm or offer save/discard                              |
| Running task             | Confirm cancel, keep running in background, or detach task |
| Waiting for approval     | Confirm dismissal                                          |
| Error state              | Allow close, but preserve error in history                 |
| Generated artifact       | Offer archive or keep in conversation history              |
| Parent with child panels | Explain whether children will close, remain, or reparent   |

The system should support undo for accidental close.

Recommended behavior:

> Show a temporary “Panel closed — Undo” toast for 5–8 seconds.

---

# 5. Panel Opening Requirements

## O-1: Opening From Chat

The user should be able to open a panel from any message-level artifact or reference.

Common triggers:

* clicking a generated file,
* clicking a proposed diff,
* clicking a citation,
* clicking a task,
* clicking a preview,
* clicking a tool result,
* clicking “Open in panel,”
* or asking the agent to “show me.”

Default behavior:

```text
Chat message → New panel opens to the right of chat
```

The originating message should show that its artifact is currently open.

---

## O-2: Opening From Another Panel

When a user opens related content from inside a panel, the new panel should appear immediately to the right of the initiating panel.

Example:

```text
[Chat] [Plan] [File] [Diff]
```

If the user opens test output from the diff panel:

```text
[Chat] [Plan] [File] [Diff] [Test Output]
```

The user should not be teleported away from the originating context.

---

## O-3: Reopen Existing Panel

If the user opens an item that is already open, the system should focus the existing panel rather than duplicate it.

This applies when the source object and context are identical.

Example:

```text
User clicks app.tsx reference.
app.tsx is already open.
System scrolls/focuses the existing app.tsx panel.
```

The system may show a small confirmation animation or highlight to indicate the target panel.

---

## O-4: Allow Intentional Duplicate Panels

The user should be able to intentionally open a duplicate panel when comparison is useful.

Examples:

* same file at two scroll positions,
* same file on two branches,
* before/after versions,
* two generated alternatives,
* two search results from the same source,
* two previews with different parameters.

The system should distinguish duplicate panels with labels such as:

```text
app.tsx
app.tsx · Compare
app.tsx · Previous
app.tsx · Branch: feature/nav
```

---

## O-5: Preview Before Full Open

For lightweight or uncertain references, the system should support a preview state.

Preview panels may be used for:

* citations,
* search results,
* variable references,
* short logs,
* metadata,
* quick definitions,
* image previews,
* dependency details.

A preview panel should be visually distinct from a committed panel.

Possible behavior:

* single click opens preview,
* double click or “Open” promotes to full panel,
* interacting deeply inside preview promotes it automatically,
* navigating away dismisses preview unless pinned.

---

## O-6: Agent-Initiated Panels

The agent may suggest or open panels, but the system should avoid excessive automatic panel creation.

Agent-initiated panel creation should follow these rules:

* Open automatically only for primary outputs or required approvals.
* Use inline references for secondary outputs.
* Batch related outputs into a single task or result panel when possible.
* Do not open more than one or two panels at once without clear reason.
* When multiple panels are created, explain why.

Example:

```text
I created a plan and opened the proposed diff beside it.
```

---

# 6. Chat Thread Requirements

## C-1: Persistent Thread Anchor

The chat thread should remain the primary place for:

* user prompts,
* agent responses,
* high-level task state,
* generated artifact references,
* approvals,
* and follow-up instructions.

The thread may be collapsible, but it should never become inaccessible.

---

## C-2: Message-to-Panel References

Messages that create panels should show persistent references.

A message might include:

```text
Created:
[Plan.md] [Diff: 3 files] [Preview] [Test output]
```

Each reference should indicate whether it is:

* unopened,
* open,
* active,
* collapsed,
* stale,
* updated,
* failed,
* or closed.

---

## C-3: Context Chips in Composer

The chat composer should make the current target context explicit.

Examples:

```text
Ask about: Entire workspace
Ask about: Active panel — Diff: navigation.tsx
Ask about: Selected text — lines 42–88
Ask about: Plan + Preview
Ask about: Files: app.tsx, routes.ts
```

The user should be able to remove or add context chips before submitting.

This is critical. The user must not have to guess what the agent will use as context.

---

## C-4: Follow-Up Targeting

When the user sends a prompt, the system should determine the target context using clear rules.

Recommended order of precedence:

1. Explicit context chips in composer.
2. Current text selection.
3. Active panel.
4. Recent panel created by the last agent action.
5. Entire conversation/workspace.

The selected target should be visible before submission.

---

## C-5: Inline vs Panel Output

The agent should decide whether to answer inline or create/open a panel based on content type.

Use inline response for:

* short explanations,
* confirmations,
* simple answers,
* brief summaries,
* small suggestions.

Use panel output for:

* long documents,
* code files,
* structured plans,
* diffs,
* previews,
* logs,
* tables,
* multi-step tasks,
* reviewable artifacts,
* anything requiring editing.

The system should let the user override with commands like:

```text
Open this in a panel.
Keep this inline.
Make this a separate artifact.
Compare side by side.
```

---

# 7. Panel Header Requirements

Every panel should have a consistent header.

## H-1: Required Header Elements

Each panel header should include:

* panel type icon,
* title,
* status indicator,
* parent/source indicator,
* primary actions,
* overflow menu,
* collapse control,
* close control.

Example:

```text
[File icon] navigation.tsx  · Modified · From “Update nav layout”
[Accept] [Revert] [⋯] [Collapse] [Close]
```

---

## H-2: Status Vocabulary

Panels should use a consistent status vocabulary.

Recommended statuses:

| Status        | Meaning                                     |
| ------------- | ------------------------------------------- |
| **Loading**   | Panel content is being fetched or generated |
| **Ready**     | Content is available and stable             |
| **Active**    | Panel is currently focused                  |
| **Modified**  | User or agent changed content               |
| **Unsaved**   | Changes are not persisted                   |
| **Running**   | Agent/tool/task is actively working         |
| **Waiting**   | Needs user input or approval                |
| **Blocked**   | Cannot continue due to missing dependency   |
| **Error**     | Action failed                               |
| **Stale**     | Source changed since panel was opened       |
| **Completed** | Task or output finished                     |
| **Archived**  | No longer active but recoverable            |

---

## H-3: Origin Disclosure

Users should be able to inspect why a panel exists.

The panel header or info menu should answer:

* What opened this panel?
* Which message created it?
* Which file/artifact does it represent?
* Which agent action last modified it?
* Is this content generated, retrieved, edited, or external?
* Is it current?

Example origin text:

```text
Opened from message: “Refactor the dashboard navigation”
Generated by Agent Run #14
Last updated 3 minutes ago
Source: /src/components/Navigation.tsx
```

---

# 8. Panel Lifecycle Requirements

## P-1: Lifecycle States

Panels should move through clear lifecycle states.

Recommended lifecycle:

```text
Created → Loading → Ready → Active/Inactive → Modified → Saved/Completed → Closed/Archived
```

Exceptional states:

```text
Ready → Stale
Ready → Error
Running → Waiting for approval
Running → Cancelled
Modified → Conflict
```

The user should understand the state without reading logs.

---

## P-2: Dirty State

A panel with unsaved or unapplied changes must show dirty state.

Dirty state should be visible in:

* panel header,
* panel rail/chip,
* close confirmation,
* workspace overview,
* and chat message reference.

Examples:

```text
● navigation.tsx
Unsaved changes
3 proposed changes
Not applied
```

---

## P-3: Stale State

A panel becomes stale when its underlying source changes outside the panel.

Examples:

* file changed on disk,
* agent regenerated a newer version,
* dependency changed,
* test output no longer matches the current code,
* preview is based on an old build.

Stale panels should show:

* what changed,
* when it changed,
* what action the user can take.

Recommended actions:

```text
Refresh
Compare with latest
Keep old version
Open latest in new panel
```

---

## P-4: Running State

When a panel represents an active process, it must show progress.

Running panels should show:

* current step,
* elapsed time,
* cancellability,
* logs or expandable details,
* whether the task continues if the panel is closed,
* and whether user input is needed.

Example:

```text
Running tests…
Step 3 of 5: npm test
Elapsed: 00:42
[View logs] [Cancel]
```

---

## P-5: Error State

Errors should be shown in context, not only as global toasts.

An error panel or error state should explain:

* what failed,
* where it failed,
* whether partial output exists,
* what the user can do next,
* and whether retrying is safe.

Good error actions:

```text
Retry
Retry with more context
Open logs
Revert changes
Ask agent to diagnose
Copy error
```

---

# 9. Navigation Requirements

## N-1: Panel Rail

The workspace should include a compact panel rail or switcher when more than two panels are open.

The rail should show:

* panel order,
* panel type,
* title,
* active state,
* dirty state,
* running state,
* error state,
* collapsed state,
* and unread/new activity.

The rail can appear:

* above the stack,
* below the stack,
* as a left/right edge strip,
* or inside the global navigation region.

---

## N-2: Breadcrumbs

Panels should support breadcrumbs when there is a meaningful parent-child path.

Example:

```text
Chat → Plan → navigation.tsx → Diff → Test Output
```

Breadcrumb interactions:

* clicking a breadcrumb focuses that panel,
* hovering may preview the panel,
* right-click or overflow menu may expose close/collapse options,
* stale/error states should be indicated in breadcrumb items.

---

## N-3: Back and Forward

Back/forward behavior must be carefully defined.

Recommended model:

* Browser/app Back should navigate workspace history, not randomly close panels.
* Panel-level Back should navigate within the active panel.
* Workspace Back should return focus to the previously active panel.
* Closing a panel should be explicit, not the default result of Back.

Avoid making Back destructive.

---

## N-4: Keyboard Navigation

The user should be able to navigate the panel stack entirely by keyboard.

Recommended shortcuts:

| Shortcut                   | Behavior                             |
| -------------------------- | ------------------------------------ |
| `Cmd/Ctrl + Alt + ←`       | Focus panel to the left              |
| `Cmd/Ctrl + Alt + →`       | Focus panel to the right             |
| `Cmd/Ctrl + Alt + ↑`       | Focus parent panel                   |
| `Cmd/Ctrl + Alt + ↓`       | Focus child/most recent descendant   |
| `Cmd/Ctrl + Shift + P`     | Open command palette                 |
| `Cmd/Ctrl + K`             | Open workspace search/switcher       |
| `Cmd/Ctrl + W`             | Close active panel                   |
| `Cmd/Ctrl + Shift + W`     | Close panel group or branch          |
| `Esc`                      | Exit nested focus or dismiss preview |
| `Cmd/Ctrl + Enter`         | Submit prompt to active context      |
| `Cmd/Ctrl + Shift + Enter` | Submit prompt to whole workspace     |

Shortcuts should be customizable in advanced products.

---

## N-5: Command Palette

The product should provide a command palette for panel actions.

Required commands:

```text
Open panel
Close active panel
Collapse active panel
Focus chat
Focus next panel
Focus previous panel
Show all panels
Search open panels
Open related artifacts
Compare with…
Pin panel
Unpin panel
Duplicate panel
Archive completed panels
Close clean panels
```

---

## N-6: Workspace Search

The user should be able to search across open panels.

Search scope options:

* current panel,
* open panels,
* current conversation,
* workspace/session,
* project files,
* generated artifacts,
* logs.

Search results should indicate where matches live.

Example:

```text
navigation.tsx — Panel 3 — 4 matches
Diff: nav refactor — Panel 4 — 2 matches
Chat thread — 7 matches
```

---

# 10. Context and Selection Requirements

## CTX-1: Explicit Context Scope

The system must make context scope visible before the user submits a prompt.

The composer should never leave the user uncertain whether they are asking about:

* the current panel,
* selected text,
* the whole conversation,
* the whole project,
* a file,
* a diff,
* a preview,
* or a task.

---

## CTX-2: Selection-Aware Prompts

If the user selects content inside a panel, the composer should recognize that selection.

Example:

```text
Selected: navigation.tsx lines 42–88
```

The user should be able to submit a prompt against only the selected content.

Example prompts:

```text
Explain this.
Refactor this.
Add tests for this.
Why did this fail?
Compare this with the previous version.
```

---

## CTX-3: Multi-Panel Context

Users should be able to include multiple panels as context.

Interaction options:

* drag panels into composer,
* select panel chips,
* use “Add to prompt context,”
* use checkboxes in panel switcher,
* mention panel names with `@`.

Example:

```text
Context: Plan.md + Diff: Navigation + Test Output
Prompt: Update the plan based on the failing tests.
```

---

## CTX-4: Context Size Disclosure

When context is large, the system should disclose what will be included.

Example:

```text
Using:
- Active diff
- 3 changed files
- Latest test output
- Current conversation summary

Not included:
- Full repository
- Archived panels
```

This is especially important in AI products where context limits, hidden summarization, or retrieval can affect output quality.

---

## CTX-5: Context Mutation

If the agent changes the context during execution, the system should disclose it.

Examples:

```text
Added test output to context.
Loaded related file: routes.ts.
Excluded archived panel: Old Nav Proposal.
```

This disclosure may be inline, expandable, or visible in an activity log.

---

# 11. Agent Interaction Requirements

## A-1: Agent Activity Should Be Spatially Grounded

When the agent is working on a specific panel, that panel should show activity.

Examples:

* spinner in panel header,
* streaming changes inside artifact,
* highlighted modified lines,
* task status in header,
* progress stepper,
* live logs.

The user should not have to infer activity only from the chat thread.

---

## A-2: Agent Must Not Silently Modify Hidden Panels

If the agent modifies a panel that is offscreen or collapsed, the system must notify the user.

Notification should include:

* which panel changed,
* what changed,
* whether the change is saved/applied,
* and how to view it.

Example:

```text
Updated collapsed panel: Diff — Navigation refactor
[View] [Undo]
```

---

## A-3: Proposed vs Applied Changes

The UI must clearly distinguish proposed changes from applied changes.

For code/design/document workflows, there should be separate states for:

* generated suggestion,
* proposed change,
* staged change,
* applied change,
* saved change,
* committed/published change.

Do not collapse these into one ambiguous “done” state.

---

## A-4: Approval Gates

The agent must request approval before:

* editing user-owned files,
* deleting content,
* running destructive commands,
* committing or publishing,
* sending external messages,
* changing permissions,
* installing dependencies,
* spending money,
* exposing private data,
* or making irreversible changes.

Approval panels should show:

* exact action,
* affected resources,
* risk level,
* expected result,
* rollback option,
* and primary/secondary actions.

Example:

```text
Approve file changes?

Files affected:
- src/components/Navigation.tsx
- src/routes/index.ts
- tests/navigation.test.ts

Risk:
- Updates routing behavior
- May affect sidebar layout

[Apply changes] [Review diff] [Cancel]
```

---

## A-5: Interruptibility

Users should be able to interrupt agent work.

Required controls:

```text
Stop
Pause
Resume
Cancel task
Revise instruction
Continue from here
```

If stopping loses work, the system must explain what will be preserved.

---

## A-6: Agent Run History

Each agent run should be inspectable.

The user should be able to see:

* prompt,
* context used,
* tools called,
* files read,
* files modified,
* outputs created,
* approvals requested,
* errors,
* duration,
* and final state.

This can live in a task panel, activity drawer, or panel inspector.

---

# 12. Editing Requirements

## E-1: Direct Manipulation

Where possible, users should be able to directly edit panel content.

Examples:

* editing generated text,
* modifying code,
* adjusting a plan,
* changing task names,
* annotating diffs,
* editing prompt context.

The agent should be able to incorporate these edits in subsequent prompts.

---

## E-2: Agent-Aware Edits

If the user edits an artifact that the agent generated, the system should track the distinction between:

* agent-generated content,
* user-edited content,
* externally changed content,
* and regenerated content.

If regeneration might overwrite user edits, the system must warn the user.

Example:

```text
Regenerating this artifact may overwrite your edits.
[Regenerate and preserve edits] [Create new version] [Cancel]
```

---

## E-3: Inline Comments

Panels should support comments or annotations where review is central.

Comment requirements:

* comments attach to specific lines, blocks, regions, or elements,
* comments can be resolved,
* comments can be referenced in chat,
* agent can respond to comments,
* comments persist across versions when possible.

---

## E-4: Versioning

Generated artifacts and significant panel changes should support version history.

Minimum requirements:

* view previous version,
* compare versions,
* restore version,
* duplicate version,
* name version.

Recommended labels:

```text
Version 1 — Initial generation
Version 2 — After user edits
Version 3 — Agent revision from prompt
Version 4 — Applied diff
```

---

# 13. Diff and Review Requirements

## D-1: Diff Panels

Diff panels should be first-class citizens in the stack.

They should show:

* files changed,
* additions,
* deletions,
* modified sections,
* comments,
* conflicts,
* approval state,
* and apply/reject controls.

---

## D-2: Granular Accept/Reject

Users should be able to accept or reject changes at multiple levels:

* entire diff,
* file,
* section,
* hunk,
* line,
* generated suggestion.

The UI should make the scope of each action explicit.

Example:

```text
Accept this hunk
Reject this file
Apply all safe changes
```

---

## D-3: Review Summary

Large diffs should include a summary.

Summary should include:

* number of files changed,
* type of change,
* risk areas,
* tests affected,
* generated rationale,
* and unresolved comments.

Example:

```text
3 files changed
12 additions, 6 deletions
Primary change: sidebar route handling
Risk: route matching order changed
Tests: 1 failing, 6 passing
```

---

## D-4: Diff-to-Chat Interaction

The user should be able to ask questions about specific parts of a diff.

Examples:

```text
Why did you change this line?
Can we avoid touching this file?
Explain this hunk.
Add a test for this case.
Revert only this section.
```

The prompt should automatically include the relevant diff region.

---

# 14. Task and Background Work Requirements

## T-1: Task Panels

Long-running work should appear in a task panel.

A task panel should show:

* objective,
* current step,
* completed steps,
* pending steps,
* blocked steps,
* outputs created,
* approvals needed,
* logs,
* cancel/pause controls,
* and final summary.

---

## T-2: Background Continuation

If a user closes or collapses a panel with a running task, the system must clearly state what happens.

Options:

```text
Keep running in background
Cancel task
Pause task
Move task to activity center
```

There should be no ambiguous close behavior.

---

## T-3: Completion Notification

When a background task completes, the user should receive a visible notification.

Notification should include:

* task name,
* outcome,
* affected panels,
* primary next action,
* and error/warning state if applicable.

Example:

```text
Navigation refactor complete.
Created: Diff panel, Test Output panel
1 test failed.
[Review diff] [Open tests]
```

---

# 15. Pinning, Grouping, and Workspace Management

## W-1: Pinning

Users should be able to pin important panels.

Pinned panels should:

* resist auto-collapse,
* remain visible during cleanup actions,
* be visually marked,
* and appear first in switchers or rail sections.

---

## W-2: Panel Groups

The system should support grouping related panels.

Groups may be created automatically or manually.

Example group:

```text
Navigation Refactor
- Plan
- navigation.tsx
- Diff
- Preview
- Test Output
```

Group actions:

```text
Collapse group
Close group
Archive group
Rename group
Summarize group
Share group
```

---

## W-3: Branches

The user should be able to maintain multiple alternative work branches.

Examples:

```text
Approach A: Minimal sidebar fix
Approach B: Full navigation redesign
Approach C: Routing-first refactor
```

Branches should preserve their own panels, artifacts, and agent history.

The system should make it clear which branch is active.

---

## W-4: Cleanup

The workspace should offer cleanup actions.

Recommended actions:

```text
Close clean panels
Collapse inactive panels
Archive completed task panels
Close panels from this branch
Keep only pinned panels
Summarize and close
```

Cleanup actions must not discard unsaved or unapplied work without confirmation.

---

# 16. Responsive Behavior Requirements

## R-1: Large Desktop

On wide screens, the full horizontal stack should be available.

Expected behavior:

```text
[Chat] [Panel] [Panel] [Panel]
```

The user can resize, scroll horizontally, collapse, and pin.

---

## R-2: Standard Laptop

On medium screens, the system should prioritize the active panel and adjacent context.

Possible behavior:

```text
[Chat] [Active Panel] [peek of next panel]
```

Offscreen panels should remain accessible through the rail or switcher.

---

## R-3: Tablet

On tablet widths, the system may shift to a hybrid model:

```text
[Panel switcher]
[Active panel]
[Composer docked below or side]
```

The chat thread may become a collapsible panel.

Panel relationships must remain visible.

---

## R-4: Mobile

On mobile, horizontal stacking should collapse into a card, tab, or route-based model.

Recommended mobile structure:

```text
Workspace
├── Chat
├── Open Panels
├── Active Panel
└── Activity
```

Mobile must preserve:

* panel identity,
* parent-child relationship,
* dirty/running/error state,
* context targeting,
* and ability to return to chat.

Do not attempt to squeeze multiple full panels side by side on mobile.

---

# 17. Accessibility Requirements

## AX-1: Semantic Structure

Panels should be exposed to assistive technology as named regions.

Example announcements:

```text
Region: Chat thread
Region: Panel 2 of 5, Diff: navigation.tsx, modified
Region: Panel 3 of 5, Test Output, error
```

---

## AX-2: Keyboard Access

All panel actions must be keyboard accessible.

Required keyboard-accessible actions:

* focus panel,
* open panel,
* close panel,
* collapse panel,
* resize panel,
* move between panels,
* open panel menu,
* select context,
* submit prompt,
* approve action,
* reject action,
* inspect origin,
* undo close.

---

## AX-3: Focus Management

Focus behavior must be predictable.

When a panel opens:

* focus should move to the panel header or first meaningful control,
* screen readers should announce the new panel,
* the originating element should be remembered,
* closing the panel should restore focus to the logical origin.

When a panel updates in the background:

* do not steal focus,
* announce politely if relevant,
* use assertive announcements only for urgent failures or approvals.

---

## AX-4: Resize Accessibility

Panel resizing must not require pointer input.

Accessible resizing should support:

* keyboard shortcuts,
* numeric width controls in panel menu,
* reset to default size,
* and screen reader announcements.

Example:

```text
Navigation.tsx panel width: 720 pixels.
Use arrow keys to resize.
```

---

## AX-5: Non-Color Indicators

Panel state must not rely only on color.

Dirty, running, stale, error, active, and collapsed states should use:

* icons,
* text labels,
* shape,
* position,
* motion where appropriate,
* and ARIA state.

---

# 18. Motion and Transition Requirements

## M-1: Panel Opening Motion

Opening a panel should communicate spatial relationship.

Recommended behavior:

* new panel slides in from the right of its parent,
* parent panel remains visually stable,
* stack adjusts smoothly,
* origin element may briefly highlight,
* focus moves after the transition completes or immediately if reduced motion is enabled.

---

## M-2: Reduced Motion

Users with reduced motion settings should receive instant or minimal transitions.

Do not use large sliding animations when reduced motion is active.

---

## M-3: State Change Motion

Motion may be used to show:

* panel created,
* panel focused,
* panel collapsed,
* panel restored,
* background task completed,
* stale state,
* dirty state.

Motion should never be the only indicator.

---

# 19. Empty, Loading, and Error States

## S-1: Empty Workspace

A new workspace should explain the interaction model.

Example:

```text
Start by asking the agent to create, inspect, or modify something.
Generated files, diffs, previews, and tasks will open as panels beside this thread.
```

Suggested actions:

```text
Create a plan
Inspect a file
Run tests
Summarize this project
Start a task
```

---

## S-2: Empty Panel

If a panel has no content yet, it should explain why.

Examples:

```text
Waiting for test output…
No preview available yet.
This file has not loaded.
The agent has not created a plan yet.
```

---

## S-3: Loading Panel

Loading panels should show progressive state.

Avoid generic infinite spinners when possible.

Better:

```text
Opening navigation.tsx…
Reading file…
Preparing diff…
Rendering preview…
```

---

## S-4: Broken References

If a panel source is missing, deleted, moved, or inaccessible, show a recoverable state.

Example:

```text
This file is no longer available.
It may have been deleted, moved, or permission-restricted.

[Find file] [Open last cached version] [Close panel]
```

---

# 20. Collaboration Requirements

If the product supports collaboration, panels should expose multi-user state.

## COL-1: Presence

Show who is viewing or editing a panel.

Example:

```text
Maya is viewing this diff.
Jordan is editing Plan.md.
```

---

## COL-2: Agent vs Human Activity

Distinguish clearly between human edits and agent edits.

Examples:

```text
Edited by AJ
Generated by Agent
Approved by Maya
Applied by System
```

---

## COL-3: Shared Panel Links

Users should be able to link directly to a panel or panel group.

Shared links should restore:

* workspace,
* conversation,
* panel stack,
* active panel,
* scroll position where appropriate,
* and selected context where safe.

---

# 21. Persistence Requirements

## PER-1: Session Restore

The workspace should restore open panels when the user returns.

Restore should include:

* open panel list,
* order,
* active panel,
* collapsed panels,
* panel widths,
* dirty states,
* running/completed task states,
* selected branch,
* and chat scroll position.

---

## PER-2: Cross-Device Restore

If cross-device use is supported, restore should adapt layout to the new device.

A four-panel desktop layout should not blindly recreate four side-by-side panels on mobile.

Instead:

```text
Desktop stack → Mobile panel list + active panel
```

---

## PER-3: Archive

Closed or completed panels may be archived.

Archived panels should remain accessible from:

* conversation message references,
* workspace history,
* artifact library,
* command palette,
* or activity log.

The user should be able to recover important generated work.

---

# 22. Permissions and Safety Requirements

## SAFE-1: Destructive Actions

Destructive actions must require explicit confirmation.

Examples:

* delete file,
* overwrite artifact,
* discard user edits,
* apply large diff,
* run destructive command,
* remove dependency,
* publish external content.

Confirmation must specify the exact scope.

Bad:

```text
Are you sure?
```

Good:

```text
Apply changes to 3 files?
This will overwrite your local edits in navigation.tsx.
[Review conflicts] [Apply anyway] [Cancel]
```

---

## SAFE-2: External Side Effects

Actions with external side effects should show destination and consequence.

Examples:

* creating pull request,
* sending message,
* publishing page,
* deploying app,
* charging account,
* modifying production data.

The approval panel should show:

* target environment,
* account,
* destination,
* payload summary,
* rollback option,
* and audit trail.

---

## SAFE-3: Agent Confidence

When the agent is uncertain, the UI should reflect that in the relevant panel.

Examples:

```text
Low confidence: test failure may be unrelated.
Needs review: route behavior changed.
Assumption: sidebar uses desktop-only breakpoint.
```

Do not bury uncertainty only in chat prose.

---

# 23. Visual Design Requirements

## V-1: Panel Differentiation

Panels should feel related but distinguishable.

Use consistent structure with type-specific cues:

* icon,
* header label,
* subtle background,
* metadata row,
* action set,
* empty state,
* and status treatment.

Avoid making every panel look like a generic card.

---

## V-2: Depth and Separation

The horizontal stack should have enough visual separation to support scanning.

Recommended treatments:

* panel borders,
* header bands,
* shadows only if needed,
* clear gutters,
* resize handles,
* active panel emphasis.

The design should avoid heavy chrome that consumes too much horizontal space.

---

## V-3: Density Modes

Power users should be able to choose density.

Suggested modes:

| Mode        | Behavior                                           |
| ----------- | -------------------------------------------------- |
| Comfortable | Larger headers, more metadata, wider gutters       |
| Compact     | Shorter headers, condensed controls, smaller rail  |
| Focus       | Active panel emphasized, inactive panels minimized |
| Review      | Diff/task metadata prioritized                     |

---

# 24. Content-Specific Requirements

## CODE-1: Code Panels

Code panels should support:

* syntax highlighting,
* line numbers,
* minimap optional,
* file path,
* branch/version,
* dirty state,
* diagnostics,
* references,
* copy path,
* reveal in file tree,
* open related tests,
* ask agent about selection.

---

## CODE-2: Terminal Panels

Terminal panels should support:

* streaming output,
* command history,
* running state,
* exit code,
* copy output,
* search logs,
* collapse noisy sections,
* link errors to source files,
* rerun command,
* ask agent to explain failure.

---

## CODE-3: Preview Panels

Preview panels should support:

* refresh,
* viewport size controls,
* error overlay,
* inspect element or source reference,
* open console/logs,
* compare previous preview,
* capture screenshot,
* share preview where applicable.

---

## DOC-1: Document Panels

Document panels should support:

* edit mode,
* read mode,
* outline,
* comments,
* version history,
* export/copy,
* ask about section,
* regenerate section,
* compare versions.

---

## DATA-1: Table/Data Panels

Data panels should support:

* sorting,
* filtering,
* column resizing,
* row selection,
* schema inspection,
* export,
* chart preview,
* ask agent about selection,
* view source query or transformation.

---

# 25. Interaction Details and Microcopy

## MC-1: Panel Creation Labels

Use clear creation labels.

Examples:

```text
Opened preview
Created draft
Generated diff
Started task
Loaded file
Updated artifact
```

Avoid vague labels like:

```text
Done
Created thing
Output ready
```

---

## MC-2: Context Labels

Context labels should be plain and explicit.

Good:

```text
Using active panel: Navigation diff
Using selected lines 42–88
Using 3 open panels
Using entire workspace
```

Bad:

```text
Context attached
Smart context
Enhanced mode
```

---

## MC-3: Close Confirmation

Close confirmation should be state-specific.

Examples:

```text
Close this panel?
```

Only for clean panels, if confirmation is needed at all.

```text
Discard unsaved edits to Plan.md?
Your changes have not been saved.
[Save] [Discard] [Cancel]
```

```text
Close running task?
The task can continue in the background or be cancelled.
[Keep running] [Cancel task] [Go back]
```

---

# 26. Edge Case Requirements

## EC-1: Too Many Panels

When many panels are open, the system should intervene gently.

Possible behaviors:

* collapse inactive panels,
* suggest cleanup,
* group related panels,
* show panel overview,
* preserve pinned/dirty/running panels.

Example:

```text
You have 12 panels open.
[Collapse inactive] [Show overview] [Do nothing]
```

Do not forcibly close user work.

---

## EC-2: Conflicting Changes

If two panels edit the same source, the system must detect conflict.

Conflict UI should show:

* which panels conflict,
* what changed in each,
* whether changes can be merged,
* recommended resolution,
* and manual compare option.

---

## EC-3: Same Artifact, New Version

If the agent regenerates an artifact that is already open, the system should ask or use a predictable default.

Recommended default:

```text
Create a new version inside the same panel.
```

Alternative actions:

```text
Replace current version
Open as new panel
Compare versions
Keep both
```

---

## EC-4: Lost Connection

If the workspace loses connection during agent work:

* preserve local panel state,
* show offline state,
* queue safe user edits,
* pause unsafe agent actions,
* retry when connected,
* and explain what was not completed.

---

## EC-5: Permission Denied

If a panel cannot access its source:

```text
Permission required
This panel needs access to repository X to continue.

[Request access] [Remove from context] [Close panel]
```

Do not silently omit inaccessible context from agent prompts.

---

# 27. Analytics and Measurement Requirements

The design should be instrumented to understand whether the pattern improves work or creates confusion.

Track:

* panels opened per session,
* panels closed per session,
* average active panels,
* panel reopen rate,
* collapse usage,
* rail/switcher usage,
* context chip edits,
* wrong-context prompt corrections,
* undo close usage,
* dirty panel abandonment,
* approval acceptance/rejection,
* agent task interruption,
* time from output creation to review,
* time from diff creation to apply,
* number of stale/conflict events,
* keyboard navigation usage,
* mobile panel switching frequency.

Important qualitative signals:

* “I lost where I was.”
* “I didn’t know what the agent was looking at.”
* “I didn’t know this changed.”
* “I had too many panels open.”
* “I couldn’t get back to the chat.”
* “I expected this to open beside the current thing.”

Those are the core failure modes of this pattern.

---

# 28. Acceptance Criteria

## AC-1: Basic Panel Opening

Given the user clicks an artifact in the chat,
when the artifact is not already open,
then it opens as a panel to the right of the chat,
and the originating message shows an open/active state.

---

## AC-2: Existing Panel Reuse

Given a file is already open in the stack,
when the user clicks the same file reference from chat,
then the existing file panel receives focus instead of creating a duplicate.

---

## AC-3: Intentional Duplication

Given a file is already open,
when the user chooses “Open duplicate” or “Open for comparison,”
then a second panel opens with a disambiguating label.

---

## AC-4: Context Visibility

Given the user focuses a panel,
when the composer is visible,
then the composer shows that the active panel is the current prompt target.

---

## AC-5: Selection Context

Given the user selects text in a panel,
when the composer receives focus,
then the composer shows a selected-context chip with the source and range.

---

## AC-6: Dirty Close Protection

Given a panel contains unsaved edits,
when the user attempts to close it,
then the system requires save, discard, or cancel.

---

## AC-7: Running Task Close Protection

Given a panel contains a running task,
when the user attempts to close it,
then the system offers to keep running, cancel, or return.

---

## AC-8: Horizontal Overflow

Given the panel stack exceeds viewport width,
when a new panel opens,
then the system preserves minimum panel widths and exposes offscreen panels through scrolling, rail, or switcher.

---

## AC-9: Keyboard Navigation

Given multiple panels are open,
when the user presses the next-panel shortcut,
then focus moves to the adjacent panel and the active state updates.

---

## AC-10: Screen Reader Announcement

Given a new panel opens,
when a screen reader is active,
then the system announces the panel title, type, position, and state.

---

## AC-11: Background Panel Update

Given a collapsed or offscreen panel changes,
when the update completes,
then the system indicates which panel changed and provides a way to view it.

---

## AC-12: Stale Panel Detection

Given the source of an open panel changes externally,
when the system detects the change,
then the panel shows stale state and offers refresh, compare, or keep-current actions.

---

# 29. Anti-Patterns to Avoid

## Avoid Modalizing Everything

Do not turn every artifact into a blocking modal.

This pattern works because panels are persistent, spatial, and comparable.

---

## Avoid Hidden Context

Do not let the agent silently decide what the user is asking about.

The composer must expose context.

---

## Avoid Auto-Opening Too Many Panels

Agent-created panel spam will make the workspace feel unstable.

Prefer:

* one primary panel,
* inline secondary references,
* expandable task details,
* user-controlled opening.

---

## Avoid Squeezed Columns

Do not compress panels until they are unusable.

Introduce overflow, collapse, or focus mode instead.

---

## Avoid Ambiguous Close Behavior

Closing should not secretly cancel work, discard edits, or lose generated artifacts.

---

## Avoid Treating Panels Like Tabs Only

Tabs hide relationships. This pattern needs spatial adjacency and lineage.

Tabs can supplement the pattern, but they should not erase parent-child context.

---

# 30. Recommended MVP Scope

For an MVP, build the smallest version that still preserves the mental model.

## MVP Must Include

* primary chat thread,
* horizontal panel stack,
* open artifact/file/diff as panel,
* active panel state,
* panel headers,
* close/collapse,
* dirty state,
* context chip in composer,
* basic keyboard navigation,
* panel switcher or rail,
* reopen existing panel behavior,
* and session restore.

## MVP Should Include

* preview panels,
* breadcrumbs,
* stale state,
* undo close,
* task/running state,
* diff review actions,
* multi-panel context selection.

## MVP Can Defer

* branching,
* full collaboration,
* advanced version history,
* cross-device restore,
* panel groups,
* complex layout customization,
* analytics dashboards,
* plugin-specific panel types.

---

# 31. One-Sentence Product Requirement

The product must allow users to move from conversation to work artifacts through a persistent horizontal panel stack, while making panel identity, state, origin, context scope, and agent activity explicit at every step.

That is the heart of the pattern.
