# Interaction Design Requirements: Better Design-Aware Spatial Conversational Workspace

These requirements extend the spatial, pane-based AI workspace pattern into a **design-agent operating environment**. The goal is to make the Better Design workflow visible, inspectable, and actionable inside the horizontal panel system, rather than hiding the design process inside a single chat response.

The workspace should support AI design sessions where chat, procedures, design context, generated artifacts, browser verification, audit findings, variations, and final deliverables coexist as durable panels. This builds on the existing spatial workspace prototype with chat, plan, file, diff, approval, context chips, lineage, and agent activity states. 

---

# 1. Core Product Concept

The workspace should treat the Better Design skill as a **visible design production pipeline**, not just a background prompt.

A user should be able to see:

```text
Brief → Procedure routing → Context gathering → Design system declaration
→ Artifact creation → Interaction/a11y/polish checks → Verified output
```

Each major phase should be represented as a panel, task card, artifact, checklist, or run state.

The product should help the user answer:

```text
What is the agent designing?
What procedure is it following?
What context did it use?
What files or assets did it inspect?
What assumptions did it make?
What artifact did it create?
Was it verified in a browser?
What still needs review?
```

---

# 2. Design-Agent Workspace Model

## Requirement BD-1: Better Design sessions must be first-class workspace objects

A Better Design run should have its own durable session object.

Each design run should include:

```text
Run ID
User brief
Selected procedure
Loaded references
Input files
Generated artifacts
Verification status
Review findings
Open decisions
Final deliverables
```

Example:

```text
Design Run #18
Type: Interactive prototype
Procedure chain: discovery → make-a-prototype → interaction-states-pass → polish-pass
Status: Awaiting browser verification
Artifacts: prototype.html, tokens.css, review-notes.md
```

The user should be able to reopen any past design run and recover its panels, artifacts, assumptions, and verification status.

---

## Requirement BD-2: The workspace should expose the skill’s procedural structure

The Better Design skill includes a procedure router. The UI should make that router visible when relevant.

When the user asks for design work, the agent should classify the request into one or more procedure tracks:

| User Intent               | Workspace Procedure     |
| ------------------------- | ----------------------- |
| Ambiguous design request  | Discovery questions     |
| Greenfield hi-fi          | Aesthetic direction     |
| Prototype / mockup / demo | Make a prototype        |
| Deck / presentation       | Make a deck             |
| Visual options            | Generate variations     |
| Live tweakable design     | Make tweakable          |
| Token extraction          | Design system extract   |
| Component inventory       | Component extract       |
| Accessibility review      | Accessibility audit     |
| Visual quality review     | Polish pass             |
| Interaction state review  | Interaction states pass |
| Hierarchy / rhythm review | Hierarchy rhythm review |
| AI-slop removal           | AI slop check           |

The selected procedure should appear in the run header, plan panel, or procedure panel.

Example:

```text
Procedure selected:
Make a prototype

Chained checks:
Interaction states pass
Polish pass
Browser verification
```

---

## Requirement BD-3: Procedure routing should be reviewable before execution

When the agent chooses a workflow, the user should be able to inspect or override it.

Example UI:

```text
The agent selected:
Prototype workflow

Because:
- User asked for a clickable HTML prototype
- Existing design context is available
- Interaction states need verification

Procedure chain:
1. make-a-prototype
2. interaction-states-pass
3. polish-pass

[Proceed] [Change procedure] [Add accessibility audit] [Skip polish]
```

The workflow should not feel like a hidden decision.

---

# 3. Better Design Run Lifecycle

## Requirement BD-4: Design runs should use explicit lifecycle states

A Better Design run should move through visible stages:

```text
Intake
Context gathering
Procedure routing
Design system declaration
Drafting
Artifact generation
Interaction wiring
Verification
Review / audit
Revision
Delivery
```

Each stage should have a status:

```text
Not started
In progress
Blocked
Needs user input
Completed
Skipped
Failed
```

Example:

```text
Design Run #18
✓ Brief understood
✓ Existing prototype inspected
✓ Procedure selected: make-a-prototype
✓ Design system declared
● Browser verification running
○ Polish pass pending
```

---

## Requirement BD-5: The run lifecycle should be spatially represented

The default panel sequence for a Better Design run should be:

```text
[Chat] [Design Brief] [Procedure Plan] [Artifact] [Verification] [Review Findings]
```

For larger runs, panels may branch:

```text
[Chat]
  → [Discovery Questions]
  → [Design System]
  → [Prototype]
      → [Interaction States]
      → [Accessibility Audit]
      → [Browser Verification]
  → [Final Summary]
```

The user should be able to move horizontally through the design process, not just scroll through a long chat transcript.

---

# 4. Composer and Context Requirements

## Requirement BD-6: Composer must distinguish target from context

The Better Design workflow relies heavily on knowing what the agent is working from. The composer should separate:

```text
Send to:
Using:
Procedure:
Output:
```

Example:

```text
Send to: Design Run #18
Using: spatial-workspace-modern.html, Better Design skill, current prototype screenshot
Procedure: polish-pass
Output: chat requirements
```

For artifact editing:

```text
Send to: prototype.html
Using: design-system declaration, interaction-state checklist, browser console output
Procedure: interaction-states-pass
```

This prevents the user from wondering whether the agent is acting on the chat, the artifact, the selected panel, the full workspace, or the skill procedure.

---

## Requirement BD-7: Skill procedures should appear as context chips

When a procedure is active, the composer should show it as a removable context chip.

Examples:

```text
Procedure · make-a-prototype
Reference · react-babel.md
Reference · verification.md
Check · interaction-states-pass
Check · polish-pass
```

If the agent is relying on a specific Better Design reference file, that reference should be visible.

The user should be able to remove or add procedure context before submitting.

---

## Requirement BD-8: The user should be able to invoke procedures directly

The command palette and composer should support explicit procedure invocation.

Examples:

```text
/use make-a-prototype
/use polish-pass
/use accessibility-audit
/use generate-variations
/use make-tweakable
/use design-system-extract
```

Natural-language equivalents should also work:

```text
Run a polish pass on this prototype.
Make this tweakable.
Generate three visual directions.
Extract the design tokens from this file.
Audit the accessibility.
```

The UI should translate these into visible procedure chips and task states.

---

# 5. Discovery and Intake Requirements

## Requirement BD-9: Ambiguous requests should open a Discovery panel

When the design request lacks necessary context, the workspace should open a **Discovery Questions** panel instead of burying questions in chat.

The Discovery panel should include:

```text
Starting point
Output format
Fidelity
Platform / viewport
Variation count
Novelty level
Tweaks desired
Primary focus: flows / copy / visuals
Problem-specific questions
```

The panel should support structured inputs:

```text
Radio groups
Checkbox groups
Sliders
Text fields
File upload prompts
Reference links
```

The user should be able to answer all questions in one pass.

---

## Requirement BD-10: Discovery questions should be minimized when context already exists

If the user has already provided sufficient context, the agent should not ask generic kickoff questions.

The UI should show:

```text
Discovery skipped
Reason: user provided prototype, skill files, and desired output format
```

This creates trust that the agent actually read the provided materials.

---

## Requirement BD-11: Discovery output should become a reusable Brief panel

After questions are answered, the system should summarize them into a durable Brief panel.

Example:

```text
Brief
Output: Interaction design requirements
Audience: product/design team
Fidelity: requirements spec, not prototype
Source context: Better Design skill + spatial workspace prototype
Focus: workflow integration
Variation count: not applicable
Novelty: modern AI-native workspace patterns
```

The Brief panel should remain available as context for subsequent runs.

---

# 6. Fact Verification Requirements

## Requirement BD-12: Named products, companies, specs, or recent releases should trigger a Fact Verification stage

The Better Design skill requires current facts before designing around a named product, company, version, release, event, or spec.

When triggered, the UI should open a **Fact Verification** panel before design begins.

The panel should show:

```text
What needs verification
Sources searched
Authoritative sources consulted
Facts confirmed
Unverified claims
Date verified
```

Example:

```text
Fact Verification
Subject: DJI Pocket 4
Status: Verified
Sources: official product page, press release
Captured: May 8, 2026
```

---

## Requirement BD-13: Verified facts should be written into a Product Facts artifact

The system should create or update:

```text
product-facts.md
```

The artifact should be visible as a panel or generated file card.

Required fields:

```text
Verified date
Sources
Existence / release status
Current version
Availability
Key specs
Recent changes
```

The agent should not proceed to brand asset gathering or high-fidelity design until this stage is complete or explicitly skipped for a concept/internal product.

---

## Requirement BD-14: Fact verification skips must be explicit

If the user is designing for a fictional, internal, or concept product, the system should show:

```text
Fact verification skipped
Reason: user confirmed this is an internal/concept product
Facts source: user brief
```

This prevents accidental invention or outdated assumptions.

---

# 7. Brand and Asset Context Requirements

## Requirement BD-15: Brand-dependent work should open an Asset Checklist panel

When the work references a brand, company, product, or client, the workspace should surface the Better Design asset protocol.

The Asset Checklist panel should ask for:

```text
Logo
Product photography / renders
UI screenshots
Color palette
Typeface list
Brand guidelines
Design system / Figma / codebase
```

The panel should rank assets by importance.

Example:

```text
Required
✓ Logo
○ UI screenshots
○ Product renders

Optional
○ Colors
○ Fonts
○ Brand guide
```

---

## Requirement BD-16: Missing assets should be represented honestly

If key assets are unavailable, the workspace should not let the artifact silently use generic substitutes.

The generated design should include labeled placeholders such as:

```text
[Logo asset needed]
[Product screenshot placeholder · 1400×900]
[Brand UI screenshot needed]
```

The run summary should show:

```text
Asset gaps:
- No official logo provided
- No product screenshots available
- Used honest placeholder in prototype
```

---

## Requirement BD-17: Brand findings should become a Brand Spec artifact

When brand context is gathered, the system should generate:

```text
brand-spec.md
```

The artifact should include:

```text
Captured date
Sources
Completeness
Logo paths
Product shots
UI screenshots
Color palette
Typography
Vibe keywords
Completeness notes
Fallback decisions
```

The artifact should be available as a panel and attachable as context to future design runs.

---

# 8. Design System Declaration Requirements

## Requirement BD-18: Every hi-fi artifact should begin with a visible design system declaration

Before generating or revising hi-fi work, the agent should create a **Design System Declaration** panel.

It should include:

```text
Aesthetic direction
Typography
Color logic
Spacing scale
Density
Radius
Shadow/elevation
Component style
Motion language
Key interaction rules
```

Example:

```text
System: Spatial AI Workbench
Type: Geist Sans + Geist Mono
Palette: dark-neutral with single orange operational accent
Spacing: 4/8px scale
Density: compact professional
Motion: quiet state transitions, no ornamental animation
Interaction rule: active context and required decisions must dominate hierarchy
```

The declaration should also be embedded as a comment in generated HTML when applicable.

---

## Requirement BD-19: The design system declaration should be editable

The user should be able to modify the declaration before artifact generation.

Examples:

```text
Change density to comfortable.
Use warmer neutrals.
Make this less Star Trek, more Linear.
Increase type scale for presentation mode.
Remove all decorative gradients.
```

Once edited, the design system declaration should update all downstream panels and artifacts as context.

---

## Requirement BD-20: Off-system values should be flagged

If the generated artifact introduces colors, spacing, fonts, or radii outside the declared system, the review panels should flag them.

Example:

```text
Rhythm finding:
Found off-scale spacing values: 7px, 13px, 18px.
Recommended: snap to 4/8px scale.
```

This requirement turns “design craft” into a visible system-level constraint.

---

# 9. Procedure Plan Panel Requirements

## Requirement BD-21: The Procedure Plan panel should show the selected workflow chain

The Procedure Plan panel should display:

```text
Selected procedure
Why selected
Input requirements
Expected artifact type
Dependent procedures
Verification requirements
User approvals needed
```

Example:

```text
Procedure Chain
1. make-a-prototype
2. interaction-states-pass
3. accessibility-audit
4. polish-pass
5. browser verification

Why:
The user asked for a clickable prototype and final UX review.
```

---

## Requirement BD-22: Procedure chains should be modifiable

The user should be able to add, remove, or reorder checks.

Example interactions:

```text
Add accessibility audit
Skip deck generation
Run polish before variations
Generate variations first
Make this tweakable after prototype
```

The UI should warn if the user removes a safety-critical step.

Example:

```text
Removing browser verification means the prototype may not have been tested in a real browser.
[Remove anyway] [Keep verification]
```

---

# 10. Artifact Panel Requirements

## Requirement BD-23: HTML artifacts should be first-class editable panels

Generated HTML prototypes, decks, canvases, and animations should open as durable artifact panels.

Each artifact panel should show:

```text
File name
Output format
Procedure that created it
Design system used
Verification status
Last modified by user / agent
Open issues
Actions
```

Example:

```text
prototype.html
Created by: make-a-prototype
System: Spatial AI Workbench
Status: Needs browser verification
Last changed: Agent Run #18
```

Actions:

```text
Preview
Edit source
Run verification
Run polish pass
Make tweakable
Duplicate
Export
Close
```

---

## Requirement BD-24: Output format should determine artifact behavior

The Better Design skill defines multiple production formats. Each should have a specialized panel type.

| Output Format         | Panel Behavior                                             |
| --------------------- | ---------------------------------------------------------- |
| Interactive prototype | Live preview, state controls, click-through verification   |
| Design canvas         | Side-by-side variation grid, labels, compare controls      |
| Slide deck            | Fixed 1920×1080 stage, slide nav, speaker notes, print/PDF |
| Timeline animation    | Play/pause, scrubber, duration, keyframe inspection        |
| Wireframe/storyboard  | Low-fi frames, annotations, variation comparison           |
| Tweakable design      | Floating tweak panel, edit-mode status, persisted values   |

The panel should not treat all HTML as generic documents.

---

## Requirement BD-25: Artifacts should carry provenance

Every artifact should expose:

```text
Created from brief
Procedure used
References loaded
Source files inspected
Agent run ID
Design system declaration
Verification history
Review passes applied
```

This should be accessible through a panel inspector or header menu.

---

# 11. Design Variations Requirements

## Requirement BD-26: Variation requests should open a Design Canvas panel

When the user asks for options, alternatives, or multiple directions, the workspace should create a **Design Canvas** panel.

The canvas should display variations side by side.

Each variation must include:

```text
Variant name
Design intent
Axis of variation
What changed
Recommended use case
Preview
```

Example:

```text
Variant A · Conventional
Axis: safer layout, familiar workflow

Variant B · Refined
Axis: stronger hierarchy, same structure

Variant C · Novel
Axis: different interaction model, bolder visual metaphor
```

---

## Requirement BD-27: Variations should differ substantively

The UI should discourage purely cosmetic variation sets.

If the agent produces three options that only differ by color, the review panel should flag:

```text
Variation quality issue:
Variants are too similar. They differ primarily by color, not layout, hierarchy, interaction, or concept.
```

The workspace should encourage variation across:

```text
Layout
Hierarchy
Interaction model
Density
Typography
Tone
Metaphor
Color logic
```

---

## Requirement BD-28: The user should be able to combine variation decisions

The canvas should support “select this part” interactions.

Example:

```text
Use layout from Variant A
Use type scale from Variant B
Use interaction model from Variant C
```

The selected decisions should become context chips:

```text
Chosen layout · Variant A
Chosen typography · Variant B
Chosen interaction · Variant C
```

These chips should flow into the next artifact generation.

---

# 12. Tweakable Design Requirements

## Requirement BD-29: Tweakable artifacts should expose a controlled tweak surface

When the user asks to make something tweakable, the artifact panel should include a **Tweaks** mode.

Tweaks should support:

```text
Color
Typography
Density
Layout variant
Component style
Copy
Feature flags
```

The tweak panel should remain hidden when not active.

The artifact should look final when Tweaks mode is off.

---

## Requirement BD-30: Tweak controls should be limited and meaningful

The system should avoid exposing every possible CSS value.

Recommended range:

```text
3–8 controls
```

Example:

```text
Primary accent
Density: compact / comfortable / spacious
Panel style: flat / outlined / elevated
Composer position: inside chat / global / active panel
Decision banner: on / off
```

The tweak panel should show why each control matters.

---

## Requirement BD-31: Tweak changes should persist

When a user changes tweak values, the workspace should preserve them across reloads or sessions.

The artifact should show:

```text
Tweaks modified
3 values changed from defaults
[Reset] [Save as version] [Apply to system]
```

If host-level persistence is available, the UI should indicate:

```text
Saved to artifact defaults
```

If only local persistence is available:

```text
Saved locally in this preview
```

---

# 13. Prototype Requirements

## Requirement BD-32: Prototype generation should include a Flow Map panel

Before building a prototype, the workspace should show:

```text
Screens
Entry point
Goal state
Navigation paths
State variables
Validation rules
Loading states
Error states
Persistence rules
```

Example:

```text
Flow Map
1. Workspace opens
2. User selects active panel
3. Composer target updates
4. User submits prompt
5. Artifact panel opens
6. Verification panel runs
```

The Flow Map should be editable before generation.

---

## Requirement BD-33: Prototypes must include real interaction states

The Interaction States panel should inventory all interactive elements:

```text
Buttons
Links
Inputs
Toggles
Cards
Navigation items
Breadcrumbs
Panel headers
Resize handles
Command palette items
Artifact cards
Approval actions
```

For each, the panel should track:

```text
Default
Hover
Active / pressed
Focus
Disabled
Loading
Success / error feedback where applicable
```

Missing states should appear as findings.

---

## Requirement BD-34: Prototype panels should support click-through verification

A prototype panel should include a verification mode that lets the agent or user walk through the primary path.

The verification panel should show:

```text
CTA clicked
Screen advanced
Input accepted
Validation triggered
Loading state appeared
Success/error shown
No console errors
Focus remained visible
```

If the prototype cannot be verified, the system should say so explicitly.

---

# 14. Deck Requirements

## Requirement BD-35: Deck artifacts should use a fixed-size stage panel

When generating a deck, the workspace should use a slide-stage panel with:

```text
1920×1080 canvas by default
Viewport scaling
Letterboxing
Keyboard navigation
Slide counter
Slide labels
Print-to-PDF support
Optional speaker notes
```

Each slide should be a distinct artifact sub-object.

Example:

```text
Slide 01 · Title
Slide 02 · Problem
Slide 03 · Proposed Pattern
Slide 04 · Requirements
```

---

## Requirement BD-36: Deck verification should check slide-specific issues

The deck verification panel should inspect:

```text
Slide scaling
Keyboard navigation
Slide counter
Text size floor
Overflow
Print behavior
Speaker note sync
```

Findings should reference exact slide labels.

Example:

```text
Slide 04 · Requirements
Issue: body text appears below 24px equivalent.
Action: increase text size or split slide.
```

---

# 15. Wireframe Requirements

## Requirement BD-37: Wireframe mode should intentionally reduce visual fidelity

When the selected procedure is wireframe/storyboard, the workspace should prevent accidental hi-fi styling.

Wireframe panels should default to:

```text
Greyscale
System font
Box placeholders
Sparse annotations
No brand color unless required
No shadows or polish
```

The panel should label itself clearly:

```text
Low-fidelity wireframe
Not final visual design
```

---

## Requirement BD-38: Wireframes should include annotations

Every wireframe variation should include concise annotations explaining:

```text
What this layout tests
Primary user path
Tradeoff
Risk
```

Example:

```text
Variation B · Progressive disclosure
Tests whether panel complexity can be introduced one decision at a time.
Tradeoff: lower initial overwhelm, more interaction steps.
```

---

# 16. Browser Verification Requirements

## Requirement BD-39: Browser verification must be a visible gate before delivery

The Better Design skill requires opening HTML in a real browser before claiming it is ready.

The workspace should include a **Browser Verification** panel with explicit checks:

```text
Page loads
Console has no red errors
No 404s
No React warnings
Fonts load
Primary path works
Viewport scaling works
Hover/focus/active states visible
No unexpected overflow
```

The final delivery state should not say “Ready” until verification passes or is explicitly skipped.

---

## Requirement BD-40: Verification failures should produce actionable findings

The Verification panel should show:

```text
Finding
Severity
Source
Observed behavior
Recommended fix
Status
```

Example:

```text
Console error
Severity: Blocker
Source: app.jsx
Observed: React is undefined
Likely cause: script integrity mismatch
Action: restore pinned React/Babel script tags
```

---

## Requirement BD-41: Verification skip must be explicit

If the environment cannot run a browser verification, the run summary should say:

```text
Browser verification not completed
Reason: no browser preview available
Risk: layout and console behavior unverified
```

The system should not imply the artifact is fully ready.

---

# 17. Accessibility Audit Requirements

## Requirement BD-42: Accessibility audits should be structured into four passes

The Accessibility panel should mirror the Better Design procedure:

```text
Pass 1: Contrast and color
Pass 2: Semantic HTML and structure
Pass 3: Keyboard navigation and focus
Pass 4: Motion, forms, and misc
```

Each pass should show:

```text
Checks completed
Issues found
Issues fixed
Remaining issues
```

---

## Requirement BD-43: Accessibility findings should be specific and measurable

Contrast findings should include actual ratios where possible.

Example:

```text
Text contrast issue
Element: secondary label
Foreground: #687282
Background: #0D1018
Ratio: 3.2:1
Required: 4.5:1
Status: Needs fix
```

Keyboard findings should identify exact elements.

Example:

```text
Focus issue
Element: panel close icon
Problem: visible focus state missing
Action: add :focus-visible ring
```

---

## Requirement BD-44: Accessibility fixes should be traceable

When the agent fixes issues, the panel should update from:

```text
Open
```

to:

```text
Fixed
Needs review
Skipped
Out of scope
```

The user should be able to inspect what changed.

---

# 18. Polish Pass Requirements

## Requirement BD-45: Polish pass should combine multiple review panels

The Polish Pass panel should aggregate:

```text
Accessibility audit
AI slop check
Hierarchy and rhythm review
Interaction states pass
```

Findings should be deduplicated and prioritized as:

```text
Blockers
Quality issues
Polish recommendations
Open decisions
```

---

## Requirement BD-46: Polish pass should produce a concise verdict

The final polish panel should output one of:

```text
Ready to ship
Ready after review
Needs more iteration
Blocked
```

Example:

```text
Verdict: Ready after review

Fixed:
- 4 focus-state issues
- 3 spacing-scale inconsistencies
- 2 unclear button labels

Open decisions:
- Confirm whether compact density is acceptable
- Replace placeholder product screenshot
```

---

## Requirement BD-47: Polish findings should map back to panels and artifacts

Each finding should link to the relevant artifact, section, component, or line.

Example:

```text
Finding: Primary CTA hierarchy too weak
Artifact: prototype.html
Panel: Approval
Element: Apply changes button
```

Clicking the finding should focus the relevant panel or artifact region.

---

# 19. AI Slop Check Requirements

## Requirement BD-48: The workspace should detect generic AI-design tropes

The AI Slop panel should scan for:

```text
Aggressive gradients
Decorative emoji
Generic rounded cards with left accent borders
Fake SVG product illustrations
Generic font defaults
Pure #000 / #fff harshness
Invented color values
Off-scale spacing
Decorative data visualization
Filler content
```

The panel should distinguish between:

```text
Actual issue
Allowed because brand/system uses it
Out of scope
```

---

## Requirement BD-49: AI slop fixes should preserve the chosen design system

The system should not “fix” a trope by introducing a new unrelated style.

Example:

```text
Issue: too many invented accent colors
Fix: consolidate into declared accent + semantic status colors
```

Not:

```text
Fix: replace with unrelated blue gradient
```

The fix should reference the design system declaration.

---

# 20. Hierarchy and Rhythm Requirements

## Requirement BD-50: Hierarchy review should identify the intended visual path

For each major artifact or screen, the review panel should state:

```text
Primary element
Secondary element
Tertiary element
Primary action
Potential confusion
```

Example:

```text
Screen: Approval panel
Primary: Authorization required
Secondary: Files affected
Tertiary: Risk areas
Primary action: Review failing test / Apply changes
Issue: Apply CTA competes with unresolved test failure
```

---

## Requirement BD-51: Rhythm review should enforce scale discipline

The panel should inspect:

```text
Spacing scale
Type scale
Color palette discipline
Component repetition
Strategic variation
Alignment
Section structure
```

Findings should include exact values when possible.

Example:

```text
Spacing issue:
Found gap: 13px
System scale: 4 / 8 / 12 / 16 / 24 / 32
Recommended: use 12px or 16px
```

---

# 21. Component and Token Extraction Requirements

## Requirement BD-52: Design System Extract should create a Tokens panel

When extracting a design system, the workspace should create a Tokens panel with:

```text
Colors
Typography
Spacing
Radii
Shadows
Motion
Breakpoints
Z-index
Container widths
```

Each token should include:

```text
Name
Value
Source
Usage
Confidence
```

Example:

```text
--accent
#FF9933
Source: spatial prototype CSS
Usage: primary operational action, active indicator
Confidence: high
```

---

## Requirement BD-53: Component Extract should create a Component Inventory panel

The Component Inventory panel should group components by:

```text
Foundations
Atoms
Molecules
Organisms
Templates
```

For each component, show:

```text
Purpose
Variants
Sizes
States
Tokens used
Composition
Accessibility notes
Do / Don’t
```

Example:

```text
Component: PanelHeader
Purpose: Identifies panel type, origin, state, and actions.
Variants: chat, file, diff, approval, verification
States: default, active, stale, modified, error, running
```

---

## Requirement BD-54: Inconsistencies should become review findings

If extraction finds near-duplicate components or off-token values, the system should flag them.

Example:

```text
Component inconsistency:
Three button styles differ only by padding and border color.
Recommended: consolidate into Button / primary, secondary, ghost, danger.
```

---

# 22. Reference and Procedure Source Requirements

## Requirement BD-55: Loaded references should be visible

When the agent uses Better Design reference files, the workspace should show them in a **Reference Context** panel or composer chips.

Examples:

```text
reference · output-formats.md
reference · react-babel.md
reference · verification.md
reference · design-principles.md
```

Each reference should include:

```text
Why loaded
What it contributes
Whether it is required or optional
```

Example:

```text
react-babel.md
Loaded because artifact uses inline React + Babel.
Contributes: pinned scripts, Babel traps, no scrollIntoView rule.
```

---

## Requirement BD-56: The agent should not overload the run with irrelevant references

The Better Design skill says to load only references needed for the request.

The UI should discourage excessive context loading.

Example:

```text
Reference skipped:
brand-context.md
Reason: no named brand or brand asset work in this request.
```

This helps keep the agent’s context scoped and explainable.

---

# 23. Better Design-Specific Panel Types

The workspace should support these additional panel types.

## 23.1 Brief Panel

Purpose:

```text
Summarizes the user’s design request, constraints, audience, output, and focus.
```

Required fields:

```text
User goal
Output format
Fidelity
Audience
Known constraints
Input files
Open questions
Assumptions
```

---

## 23.2 Procedure Plan Panel

Purpose:

```text
Shows the selected workflow and chained procedures.
```

Required fields:

```text
Selected procedure
Why selected
Procedure chain
Expected outputs
Required checks
Approval gates
```

---

## 23.3 Design System Panel

Purpose:

```text
Declares the visual and interaction system before artifact generation.
```

Required fields:

```text
Type
Color
Spacing
Density
Radius
Motion
Component rules
Interaction principles
```

---

## 23.4 Asset Checklist Panel

Purpose:

```text
Tracks whether the run has the real brand/product/UI assets needed.
```

Required fields:

```text
Asset type
Required / optional
Provided / missing
Source
Usage
Fallback
```

---

## 23.5 Variation Canvas Panel

Purpose:

```text
Displays multiple design directions or UX options side by side.
```

Required fields:

```text
Variant label
Axis of variation
Preview
Rationale
Risk
Recommended use
```

---

## 23.6 Tweak Panel

Purpose:

```text
Lets users adjust selected design parameters live.
```

Required fields:

```text
Control name
Value
Default
Scope
Persistence status
Reset action
```

---

## 23.7 Verification Panel

Purpose:

```text
Shows browser, console, layout, scaling, and interaction verification.
```

Required fields:

```text
Check
Status
Evidence
Issue
Fix
Re-test result
```

---

## 23.8 Audit Findings Panel

Purpose:

```text
Aggregates accessibility, interaction, hierarchy, rhythm, and AI slop findings.
```

Required fields:

```text
Category
Severity
Location
Finding
Recommendation
Fix status
```

---

## 23.9 Delivery Panel

Purpose:

```text
Summarizes final artifacts, caveats, verification status, and next steps.
```

Required fields:

```text
Artifacts delivered
Verified / unverified
Placeholder assets
Open decisions
Recommended next action
Download / open links
```

---

# 24. Approval and Safety Requirements

## Requirement BD-57: The system should gate destructive or high-impact design actions

Approval should be required before:

```text
Overwriting user-edited artifact content
Deleting generated files
Replacing a chosen variation
Discarding tweak changes
Removing verification steps
Publishing or exporting externally
Running commands with external effects
```

Approval copy should be explicit.

Example:

```text
Replace prototype.html?
This will overwrite your manual edits from 14:32.

[Create new version] [Overwrite] [Cancel]
```

---

## Requirement BD-58: Regeneration should protect user edits

If the agent regenerates an artifact that the user has edited, the UI should offer:

```text
Preserve user edits
Create a new version
Compare versions
Overwrite
Cancel
```

The default should favor preservation or versioning.

---

## Requirement BD-59: Verification and polish skips should require acknowledgement

Skipping verification, accessibility, or polish should create a visible caveat in the delivery summary.

Example:

```text
Caveat:
Browser verification was skipped, so console errors and responsive layout behavior are unverified.
```

The final state should not silently claim readiness.

---

# 25. Search, Command Palette, and Procedure Commands

## Requirement BD-60: Command palette should support design-agent operations

The command palette should include Better Design commands:

```text
Start design run
Choose procedure
Run discovery questions
Declare design system
Generate variations
Make prototype
Make deck
Make tweakable
Run accessibility audit
Run interaction states pass
Run AI slop check
Run hierarchy/rhythm review
Run polish pass
Verify in browser
Extract tokens
Extract components
Show run history
Show open decisions
```

Commands should work on:

```text
Active panel
Selected artifact
Entire workspace
Selected text/range
Specific procedure run
```

---

## Requirement BD-61: Search should include design artifacts and findings

Workspace search should return:

```text
Open panels
Generated HTML files
Procedure runs
Review findings
Design tokens
Component inventory
Verification results
Discovery answers
Brand specs
Product facts
```

Example search result:

```text
“focus ring”
- Interaction States Pass · 4 findings
- prototype.html · Button focus styles
- Accessibility Audit · keyboard navigation
```

---

# 26. Status and Telemetry Requirements

## Requirement BD-62: Status bar should prioritize design-run truth

The status bar should emphasize:

```text
Active procedure
Active artifact
Current blocker
Verification state
Open findings
Approval state
```

Example:

```text
Run #18 · polish-pass · prototype.html · 3 findings · browser verified
```

Avoid over-prioritizing internal or low-value telemetry unless the user explicitly needs it.

Less useful as persistent status:

```text
Raw memory percentage
Internal version number
Generic token count
```

More useful:

```text
Context: 3 files + selected panel
Verification: console clean
Open: 1 decision required
```

---

## Requirement BD-63: Current blocker should be globally visible

If the run is blocked, the workspace should show the blocker near the top or composer.

Examples:

```text
Needs user input: choose variation
Needs approval: overwrite artifact
Needs asset: logo missing
Needs verification: browser not run
Needs fix: console error
```

The blocker should link to the relevant panel.

---

# 27. Responsive Requirements

## Requirement BD-64: Desktop should support full spatial workflow

On desktop, the ideal layout is:

```text
[Chat / Composer] [Brief or Plan] [Artifact] [Verification or Audit]
```

The user should be able to keep the design artifact and review findings visible at the same time.

---

## Requirement BD-65: Tablet should use active artifact + panel switcher

On tablet, the system should avoid squeezing many panels.

Recommended layout:

```text
Top: design run status + panel switcher
Main: active panel
Bottom: composer / current blocker
```

The user should still see:

```text
Procedure
Artifact
Verification status
Open decisions
```

---

## Requirement BD-66: Mobile should collapse to task-based navigation

On mobile, use a route/card model:

```text
Brief
Procedure
Artifact
Review
Delivery
```

The user should be able to approve, review, or answer discovery questions, but complex side-by-side comparison can be deferred or simplified.

---

# 28. Accessibility Requirements for the Workspace Itself

## Requirement BD-67: Panels should be exposed as named regions

Screen readers should announce:

```text
Region: Design Brief panel
Region: Procedure Plan panel
Region: Prototype artifact panel
Region: Browser Verification panel
Region: Accessibility Findings panel
```

Each panel should announce:

```text
Panel type
Title
Position
State
Open findings
```

Example:

```text
Panel 4 of 6, Browser Verification, 2 issues found.
```

---

## Requirement BD-68: Procedure status must not rely only on color

Statuses such as:

```text
Completed
Blocked
Failed
Needs input
Verified
Unverified
```

must include labels, icons, and ARIA state where appropriate.

Do not rely on green/yellow/red dots alone.

---

## Requirement BD-69: Review findings should be keyboard navigable

The user should be able to:

```text
Move through findings
Open affected artifact
Mark finding reviewed
Apply fix
Skip finding
Return to findings panel
```

without mouse input.

---

# 29. Delivery Requirements

## Requirement BD-70: Final response should reflect the actual run state

When the agent delivers work, the final summary should include:

```text
What was created
What procedure was used
What was verified
What was not verified
What placeholders remain
What decisions need user review
Links to artifacts
```

Example:

```text
Created:
- prototype.html
- tokens.css
- polish-findings.md

Verified:
- Browser loaded
- Console clean
- Primary flow clicked through

Needs review:
- Placeholder logo
- Chosen density
```

---

## Requirement BD-71: Delivery should not over-explain completed work

The Better Design skill emphasizes brief final summaries. The delivery panel and chat response should avoid re-describing the whole artifact.

The summary should focus on:

```text
Caveats
Open decisions
Next useful action
Artifact links
```

---

# 30. Suggested Default Workflow Templates

## 30.1 New Prototype Workflow

```text
Chat
→ Discovery Questions
→ Brief
→ Design System Declaration
→ Flow Map
→ Prototype Artifact
→ Interaction States Pass
→ Browser Verification
→ Polish Pass
→ Delivery
```

---

## 30.2 Existing Prototype Review Workflow

```text
Chat
→ Artifact: existing prototype
→ Design System Observation
→ UX Review Findings
→ Interaction States Pass
→ Accessibility Audit
→ Polish Recommendations
→ Delivery
```

---

## 30.3 Visual Variations Workflow

```text
Chat
→ Brief
→ Design System Declaration
→ Variation Strategy
→ Design Canvas
→ User Selection
→ Chosen Direction Artifact
→ Polish Pass
→ Delivery
```

---

## 30.4 Deck Workflow

```text
Chat
→ Brief
→ Deck Outline
→ Layout System
→ Deck Artifact
→ Slide Verification
→ Hierarchy/Rhythm Review
→ Delivery
```

---

## 30.5 Brand-Grounded Design Workflow

```text
Chat
→ Fact Verification
→ Asset Checklist
→ Brand Spec
→ Design System Extract
→ Artifact
→ Browser Verification
→ Polish Pass
→ Delivery
```

---

# 31. Acceptance Criteria

## AC-BD-1: Procedure routing is visible

Given a user asks for a design artifact,
when the agent selects a Better Design procedure,
then the workspace shows the selected procedure, why it was selected, and the expected artifact type.

---

## AC-BD-2: Ambiguous requests trigger discovery

Given the user asks for a new design without enough context,
when the run starts,
then the workspace opens a Discovery Questions panel before generating hi-fi output.

---

## AC-BD-3: Context is explicit

Given a design run is active,
when the composer is visible,
then it shows the target artifact, included context, and active Better Design procedure.

---

## AC-BD-4: Design system is declared before hi-fi

Given the agent is creating a high-fidelity artifact,
when artifact generation begins,
then a Design System Declaration exists and is attached to the run.

---

## AC-BD-5: Generated artifacts have provenance

Given the agent creates an artifact,
when the user opens its inspector,
then the user can see the procedure, brief, references, design system, source inputs, and verification history.

---

## AC-BD-6: Browser verification gates readiness

Given an HTML artifact is generated,
when delivery is attempted,
then the system indicates whether browser verification passed, failed, or was skipped.

---

## AC-BD-7: Review findings link to artifact locations

Given an audit or polish pass finds an issue,
when the user selects the finding,
then the workspace focuses the relevant artifact, panel, component, or line.

---

## AC-BD-8: Tweakable artifacts persist changes

Given a user changes tweak values,
when the artifact is reloaded,
then the changed values persist or the UI clearly states that persistence is local only.

---

## AC-BD-9: User edits are protected

Given a user has edited an artifact,
when the agent attempts to regenerate or overwrite it,
then the system offers preserve, version, compare, overwrite, and cancel options.

---

## AC-BD-10: Final delivery includes caveats

Given a run completes with skipped checks or placeholder assets,
when the final summary is shown,
then those caveats are explicitly listed.

---

# 32. Anti-Patterns to Avoid

## Do not hide the design process inside chat

The Better Design workflow is procedural. If the user cannot see the procedure, context, checks, and verification, the workspace is not taking advantage of the spatial model.

---

## Do not generate hi-fi work without declaring a system

A design system declaration is required before high-fidelity output. Otherwise, the artifact risks becoming visually inconsistent or generic.

---

## Do not treat verification as a chat note

Verification should be a panel with checks, results, and evidence, not a vague statement like:

```text
Looks good.
```

---

## Do not ask generic discovery questions when the user already provided context

The agent should read the current workspace and only ask what is missing.

---

## Do not create fake assets to satisfy layout needs

Use real assets, verified assets, or honest placeholders. Do not invent logos, product shots, UI screenshots, data, or testimonials.

---

## Do not let “done” mean too many things

Use precise states:

```text
Drafted
Generated
Previewed
Verified
Audited
Fixed
Ready for review
Ready to deliver
```

Avoid ambiguous states like:

```text
Done
Finished
Complete
```

unless the required checks truly passed.

---

# 33. One-Sentence Requirement

The spatial workspace must make the Better Design skill’s workflow visible as a pane-based production system, where every design run exposes its brief, procedure, context, design system, artifacts, verification, review findings, and delivery status alongside the primary conversation.
