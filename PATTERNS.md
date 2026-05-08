Absolutely. A bunch of newer patterns are emerging right now, especially around AI-native tools, spatial workspaces, and “software that does work with you.” Many are not totally new inventions; they are older patterns recombined around agents, generated artifacts, persistent context, and human approval.

Your prototype already contains several of the stronger patterns: persistent panels, context chips, lineage breadcrumbs, artifact cards, a diff/review surface, stale state, and an approval gate. That puts it in the same design family as the newer agentic workspaces we’re seeing in coding, research, and creation tools. 

# 1. Artifact-first workspaces

This is the pattern where the conversation produces an artifact, and the artifact becomes the main object of interaction. The chat is no longer the whole product; it becomes the command, critique, and revision layer around a durable object.

Examples include ChatGPT Canvas, Claude Artifacts, Gemini Canvas, and Figma Make. OpenAI describes Canvas as a separate workspace for writing and coding projects that need editing and revision; Anthropic describes Artifacts as generated code, documents, and designs appearing in a dedicated window alongside the conversation; Figma Make lets users generate, edit, preview, and continue refining AI-created outputs inside a design/build environment. ([OpenAI][1])

**Interaction design implication:** treat generated things as first-class objects. They need titles, versions, edit state, provenance, comments, undo, export, sharing, and lifecycle states. “Here’s your answer” becomes “Here’s a thing we are now working on.”

For your prototype, this means `Plan.md`, `navigation.tsx`, `Diff`, and `Approval` should feel like durable workspace objects, not transient outputs.

---

# 2. Agent task inboxes

A newer pattern is the **agent task inbox**: instead of asking an assistant a question and waiting in the same thread, users delegate tasks that run as independent work items. Each task has status, scope, output, review, and handoff.

GitHub Copilot’s cloud agent can research a repository, create a plan, make code changes on a branch, and let the user review the diff and create a PR when ready. Cursor describes parallel agents running in isolated worktrees, and Claude Code supports multiple independent conversations with separate history and context. ([GitHub Docs][2])

**Interaction design implication:** AI work needs an inbox-like management layer:

```text
Task
├── Objective
├── Status
├── Files touched
├── Current step
├── Output
├── Blockers
├── Review
└── Resume / cancel / apply
```

This is adjacent to your sidebar’s “Activity” area. I would evolve that section into a proper **Agent Runs** or **Work Queue** surface.

---

# 3. Review-before-apply flows

A major modern pattern is the separation between:

```text
suggested → proposed → reviewed → approved → applied → committed/published
```

AI products are forcing this pattern because generated work often has consequences. Coding assistants now commonly expose diffs, review panels, command permissions, branch isolation, and approval gates before changes become real. GitHub Copilot’s agent workflow explicitly centers plan, branch, diff review, and PR creation; OpenAI’s agent and computer-use documentation also emphasizes tools, guardrails, and human review as agent workflows become more complex. ([GitHub Docs][2])

**Interaction design implication:** never let “done” be ambiguous. The UI should say exactly whether the agent has merely drafted, staged, applied, saved, committed, published, or sent something.

Your approval panel is already using this pattern well. I would just make the state language sharper:

```text
Generated
Unapplied
Needs review
Approved
Applied locally
Committed
Published
```

---

# 4. Context chips and visible prompt scope

This is one of the most important emerging AI UX patterns. The interface shows what the model is using as context before the user submits.

The pattern is showing up because AI tools can now connect to files, apps, data sources, tools, memories, canvases, screens, and selected regions. MCP is one of the infrastructure shifts behind this: Anthropic introduced Model Context Protocol as an open standard for secure two-way connections between AI apps and data/tools, and the MCP docs describe it as a standard way for AI apps to connect to files, databases, tools, workflows, and prompts. ([Anthropic][3])

**Interaction design implication:** the composer should expose two separate ideas:

```text
Send to: active panel / workspace / agent run
Using: selected lines / file / diff / sources / previous run
```

That distinction is huge. “Where my instruction goes” and “what evidence the AI sees” are not the same thing.

Your prototype already has context chips. I would push that further and make target/scope/context impossible to confuse.

---

# 5. Inspectable agent activity trails

Modern AI products are increasingly exposing process, not just output. Deep Research in ChatGPT, for example, shows a sidebar with steps taken and sources used while it runs; OpenAI’s help docs describe proposed research plans, progress visibility, interruptibility, citations, source sections, and activity history in the completed report. Google’s Deep Search similarly describes issuing many searches and producing fully cited reports. ([OpenAI][4])

**Interaction design implication:** users need to inspect what the AI did:

```text
Read files
Called tools
Opened sources
Changed files
Skipped files
Made assumptions
Hit errors
Requested approval
```

This is especially important in professional tools. It builds trust and makes debugging the agent’s behavior possible.

For your prototype, `Run #14 · streaming` could become clickable and open a run inspector.

---

# 6. Generated UI inside chat

A newer pattern is **generative UI**: the AI does not just answer with text; it renders a purpose-built component.

Vercel’s AI SDK documentation defines generative UI as allowing an LLM to go beyond text and generate interface components. OpenAI’s Apps SDK similarly supports interactive interfaces inside ChatGPT, and its component guidance frames UI components as the human-visible half of a connector that can keep prompt interactions and UI actions synchronized. ([AI SDK][5])

**Interaction design implication:** chat becomes a container for mini-apps:

```text
Comparison table
Calendar picker
Product carousel
Chart
Approval form
File diff
Task checklist
Configuration panel
```

The UX challenge is deciding when to stay inline versus when to promote something into a panel, canvas, or full-screen workspace.

For your prototype, artifact cards are a good start. Some could become richer inline widgets before opening a full panel.

---

# 7. Multimodal “show me” interfaces

Another fast-emerging pattern is the AI as a live visual collaborator. Users share camera, screen, image, or voice, then ask questions in real time.

ChatGPT’s voice-with-video feature lets users talk to ChatGPT about what they are seeing, with real-time video and interruptible conversation. Gemini Live supports camera and screen sharing with spoken responses, and Microsoft Copilot Vision lets Copilot see the user’s screen or mobile camera feed when activated. ([ChatGPT][6])

**Interaction design implication:** products need visible capture state:

```text
Seeing: screen
Seeing: camera
Seeing: selected window
Seeing: this browser tab
Not seeing: other apps
Recording: no
Session transcript: available
```

The trust problem is enormous here. The user needs persistent, unambiguous visibility into what the AI can currently perceive.

For a spatial workspace like yours, this could translate into “share active panel with agent,” “share visible stack,” or “share selected region.”

---

# 8. AI browsers and computer-use agents

A very recent class of products lets the AI operate existing graphical interfaces on the user’s behalf. OpenAI’s Operator was introduced as an agent for repetitive browser tasks like filling forms and ordering groceries, powered by a computer-using model trained to interact with GUI elements. Claude’s computer-use tool provides screenshot, mouse, and keyboard control for autonomous desktop interaction. ChatGPT Agent extends this idea into broader tasks using its own computer. ([OpenAI][7])

**Interaction design implication:** this creates a new pattern: **delegated direct manipulation**.

The AI is not calling an API behind the scenes; it is clicking, typing, scrolling, and navigating. That demands:

```text
Visible cursor ownership
Step-by-step action log
Pause button
Take control button
Sensitive-field masking
Before-submit confirmations
Domain/app permissions
Undo or rollback plan
```

This is relevant to your approval gate. The next step beyond “apply code” is “agent will operate an interface.” That needs even stronger supervision.

---

# 9. Progressive autonomy modes

AI tools are increasingly separating modes like:

```text
Ask
Edit
Agent
Autopilot
Background
```

GitHub’s Copilot blog distinguishes Ask, Edit, and Agent modes: Ask answers, Edit recommends changes across files, and Agent goes further by taking action based on the request. Claude Code uses slash commands for managing models, permissions, context, and workflows within a session. ([The GitHub Blog][8])

**Interaction design implication:** autonomy should be a visible mode, not a hidden behavior.

A user should always know:

```text
Will this only answer?
Will this draft changes?
Will this edit files?
Will this run commands?
Will this create a PR?
Will this contact another service?
```

This is a great pattern to add to your UI. Near the composer, you could have:

```text
Mode: Ask | Suggest | Edit | Agent
```

Then permissions and risk level can change based on the mode.

---

# 10. Branching alternatives

AI has made it cheap to generate multiple approaches, so interfaces are starting to support branching workstreams. This shows up in coding tools through worktrees and branches, in design tools through generated alternatives, and in chat tools through alternate responses or artifacts.

Cursor’s worktree model is a clear example: each agent can run in its own isolated set of files and changes, then the user can apply the finished result back to the working branch. ([Cursor][9])

**Interaction design implication:** users need to compare alternatives, not just accept one output.

Useful UI patterns:

```text
Approach A / Approach B
Branch cards
Compare outputs
Merge selected parts
Archive losing branch
Promote branch to main
```

For your panel stack, this could be powerful. Imagine:

```text
Nav refactor
├── Minimal route-order fix
├── Router primitive migration
└── Full IA cleanup
```

Each branch could have its own plan, diff, preview, and tests.

---

# 11. Source-grounded knowledge spaces

Research tools are moving from search boxes to **source workspaces**. Users gather sources, ask questions over them, generate summaries, and produce reports. NotebookLM is a strong example: Google describes it as a research and thinking partner grounded in trusted information, and its Audio Overview feature turns uploaded sources into deep-dive audio discussions. Perplexity Spaces is another example, organizing research and tasks into dedicated workspaces. ([Google NotebookLM][10])

**Interaction design implication:** the source list becomes part of the interface contract.

The user needs to know:

```text
Included sources
Excluded sources
Source freshness
Source credibility
Citation coverage
Conflicts between sources
Generated claims without source support
```

For your design, this maps nicely to a right-side inspector or panel-level “Context used” drawer.

---

# 12. Chat-to-app components

A newer pattern is that apps are no longer destinations you open separately. They can appear inside the conversational surface when needed.

OpenAI’s Apps SDK frames apps as interactive interfaces inside ChatGPT that can be discovered naturally in conversation or called by name; the SDK uses MCP servers and optional web components rendered inside ChatGPT. ([OpenAI][11])

**Interaction design implication:** apps become contextual tools summoned by intent.

Instead of:

```text
Open Jira → find issue → update field
```

The flow becomes:

```text
“Update the Jira ticket with this summary”
→ Jira component appears
→ user reviews fields
→ user confirms
```

The UX challenge is trust and containment: users must understand which app is acting, what account it uses, what data is sent, and what will happen on submit.

---

# 13. Spatial panels beyond desktop

Spatial computing is pushing panels, windows, and canvases into 3D environments. Apple’s visionOS guidance describes a limitless canvas with windows, volumes, and 3D objects; Android XR design guidance describes spatial panels as fundamental building blocks for XR apps. ([Apple Developer][12])

**Interaction design implication:** the same mental model behind your horizontal panel stack can extend into spatial layouts:

```text
Primary task in front
Supporting panels around it
Objects retain position
Depth implies relationship
Focus controls reduce clutter
```

Even on a normal desktop, this is influencing design. Products are becoming less page-based and more workspace-based.

---

# 14. Liquid, layered, morphing surfaces

Apple’s Liquid Glass design language is a recent high-profile example of interfaces becoming more material, layered, and dynamic. Apple describes Liquid Glass as a translucent material that reflects and refracts surroundings and dynamically transforms to help focus attention across controls, navigation, icons, widgets, and system surfaces. ([Apple][13])

**Interaction design implication:** visual surfaces are becoming more stateful and environmental.

This is not just a style trend. It supports patterns like:

```text
Floating controls
Contextual chrome
Depth-based hierarchy
Content-first navigation
Morphing panels
Transient toolbars
```

The caution: it can easily harm legibility. For dense tools like yours, I would borrow the layering and material logic, not the full glass aesthetic.

---

# 15. Persistent status bars and cockpit telemetry

Developer and AI tools are reviving the status bar as a serious interaction layer. It is no longer just decorative; it communicates active model, branch, task, permissions, selection, tests, context use, and runtime state.

Claude Code’s docs describe multiple sessions with independent history and context, status indicators for hidden tabs, slash commands, and workflow controls. Your prototype’s bottom status bar is very much in this family. ([Claude][14])

**Interaction design implication:** status bars are useful when they show operational truth, not random metrics.

Best use:

```text
Agent running
Active panel
Selected range
Unsaved changes
Tests failing
Approval needed
Current branch
```

Less useful unless contextually relevant:

```text
Memory 14%
Version number
Raw token count
Internal model stats
```

I’d make your status bar more “what needs attention?” and less “system dashboard.”

---

# 16. Promptable command palettes

The command palette is evolving into a hybrid of search, action launcher, AI prompt, and workflow runner.

Claude Code slash commands are one example: users type `/` to manage permissions, context, workflows, models, and session state. In broader product design, the palette is becoming the place where users can say either a precise command or a natural-language intent. ([Claude][15])

**Interaction design implication:** the command palette becomes the product’s universal verb layer.

For your workspace, `⌘K` could support:

```text
Open panel
Run tests
Summarize current branch
Compare P·03 and P·04
Ask about selected lines
Apply accepted hunks
Close inactive panels
Show approval gates
Switch agent mode
```

This is especially valuable for power users because it keeps complex spatial UIs from becoming mouse-heavy.

---

# 17. Interruptible long-running flows

Older software often treated waiting as passive. New AI tools need active waiting states because tasks may run for minutes, call tools, ask for approval, fail partially, or produce intermediate outputs.

Deep Research exposes progress and lets users interrupt or refine focus while running; ChatGPT voice/video emphasizes interruptible back-and-forth conversation; agent coding tools expose background task completion and review states. ([OpenAI Help Center][16])

**Interaction design implication:** every long-running action should answer:

```text
What is happening?
What step is it on?
Can I interrupt?
What will be preserved?
What changed so far?
What is blocked?
What happens next?
```

For your prototype, `Run #14 · streaming` should probably have a mini-progress panel, not just a pulse indicator.

---

# 18. Confidence, risk, and reversibility labels

This is becoming more important as interfaces become agentic. The UI has to tell users not just what will happen, but how risky and reversible it is.

Your approval panel already includes “Medium risk” and “Reversible · Yes · 1-click.” That is exactly the right instinct. The next generation of this pattern is more granular:

```text
Risk: low / medium / high
Confidence: high / uncertain
Reversibility: undoable / partially undoable / irreversible
Scope: local / external / production
Visibility: private / shared / published
```

**Interaction design implication:** risk metadata should sit near the action, not buried in logs.

A button should never say only:

```text
Apply
```

when it really means:

```text
Apply 3 file changes with 1 failing test
```

---

# 19. “Bring your own tools” interfaces

MCP and Apps SDK-style architectures are leading to products where users connect tools, data, workflows, and custom services. The interface pattern becomes a **connector control plane**.

MCP’s docs describe AI applications connecting to data sources, tools, and workflows; OpenAI’s Apps SDK builds on MCP to connect apps to ChatGPT, optionally rendering UI components inside the host experience. ([Model Context Protocol][17])

**Interaction design implication:** connector UX needs to be treated as part of the core product, not settings-page plumbing.

Users need to see:

```text
Connected tools
Allowed actions
Account identity
Data access level
Recent tool calls
Revocation controls
Per-tool permissions
```

For your workspace, this could become a panel inspector:

```text
This run used:
- GitHub: read files, create branch
- Local shell: run tests
- Filesystem: modify 3 files
```

---

# 20. “Working memory” as a visible UI object

AI products increasingly need to show what is remembered, summarized, or compressed. Your prototype includes `Memory 14%`, which gestures in this direction.

The pattern is still immature, but the core idea is strong: memory should be inspectable, editable, and scoped.

**Interaction design implication:** memory should not be an invisible magic bucket.

Useful controls:

```text
Remember this
Forget this
Use only this project
Do not use memory
Show what you know
Summarize current workspace
Pin this context
Archive this context
```

For your design, I would replace raw memory percentage with something more user-facing:

```text
Context: 3 panels + selected lines
Memory: project rules active
Summary: current run compressed
```

---

# The meta-pattern

The biggest shift is this:

```text
Old UI: user operates software.
Modern AI UI: user supervises software that can operate other software.
```

That changes the role of interaction design. The designer is no longer only designing navigation and controls. They are designing:

```text
agency
oversight
provenance
confidence
context
interruptibility
reversibility
collaboration
```

For your prototype, the highest-value next patterns to borrow would be:

```text
Agent task inbox
Run inspector
Explicit autonomy mode
Panel minimap
Branch alternatives
Review-before-apply lifecycle
Visible context contract
Risk/reversibility labels
Promptable command palette
Connector/tool-call inspector
```

Those would make the design feel not just modern visually, but genuinely modern as an AI-native interaction model.

[1]: https://openai.com/index/introducing-canvas/?utm_source=chatgpt.com "Introducing canvas"
[2]: https://docs.github.com/copilot/concepts/agents/coding-agent/about-coding-agent?utm_source=chatgpt.com "About GitHub Copilot cloud agent"
[3]: https://www.anthropic.com/news/model-context-protocol?utm_source=chatgpt.com "Introducing the Model Context Protocol"
[4]: https://openai.com/index/introducing-deep-research/?utm_source=chatgpt.com "Introducing deep research - OpenAI"
[5]: https://ai-sdk.dev/docs/ai-sdk-ui/generative-user-interfaces?utm_source=chatgpt.com "AI SDK UI: Generative User Interfaces"
[6]: https://chatgpt.com/features/voice-with-video/?utm_source=chatgpt.com "ChatGPT Voice mode with live video"
[7]: https://openai.com/index/introducing-operator/?utm_source=chatgpt.com "Introducing Operator"
[8]: https://github.blog/ai-and-ml/github-copilot/copilot-ask-edit-and-agent-modes-what-they-do-and-when-to-use-them/?utm_source=chatgpt.com "Copilot ask, edit, and agent modes: What they do and ..."
[9]: https://cursor.com/blog/agent-best-practices?utm_source=chatgpt.com "Best practices for coding with agents"
[10]: https://notebooklm.google/?utm_source=chatgpt.com "Google NotebookLM | AI Research Tool & Thinking Partner"
[11]: https://openai.com/index/introducing-apps-in-chatgpt/?utm_source=chatgpt.com "Introducing apps in ChatGPT and the new Apps SDK"
[12]: https://developer.apple.com/design/human-interface-guidelines/designing-for-visionos?utm_source=chatgpt.com "Designing for visionOS | Apple Developer Documentation"
[13]: https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/?utm_source=chatgpt.com "Apple introduces a delightful and elegant new software ..."
[14]: https://code.claude.com/docs/en/vs-code?utm_source=chatgpt.com "Use Claude Code in VS Code - Claude Code Docs"
[15]: https://code.claude.com/docs/en/commands?utm_source=chatgpt.com "Commands - Claude Code Docs"
[16]: https://help.openai.com/en/articles/10500283-deep-research-in-chatgpt?utm_source=chatgpt.com "Deep research in ChatGPT - OpenAI Help Center"
[17]: https://modelcontextprotocol.io/docs/getting-started/intro?utm_source=chatgpt.com "Model Context Protocol"
