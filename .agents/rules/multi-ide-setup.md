---
trigger: model_decision
globs: 'AGENTS.md, .agents/**/*.md'
description: 'Apply this when configuring IDE adapters, routing workflow commands, or delegating tiered subagents across multi-IDE environments.'
---

# Shared Instructions & IDE Adapters

This repository supports multiple AI IDEs and autonomous agents. Project policy has one source of truth; IDE files may add only the minimal capability translation required by their host.

## Routing Tree

Adapters must not duplicate project policy or hard-code user-machine paths.

`[IDE Dotfile]` ──points to──> `AGENTS.md` ──delegates to──> `[.agents/rules/*.md & WORKFLOWS.md]`

1. **IDE adapters (e.g., `.clinerules`, `.cursor/rules/agents.mdc`, `KIMI.md`):** Point to the canonical instructions and may translate agent capabilities such as subagents or rate limits. They do not redefine project policy.
2. **`AGENTS.md` (Root):** The canonical entry point. It enforces host constraints (Windows/PowerShell) and handles global code quality limits.
3. **`.agents/rules/*.md`:** Domain-specific rules loaded dynamically via progressive disclosure based on the files the AI is editing.
4. **`.agents/WORKFLOWS.md`:** Global routing for `#tags` and `/commands`.

## Add a New IDE

When integrating a new AI IDE, create its system prompt file and use this template. Add only adapter-specific capability translation below it when needed.

```markdown
This repository uses `AGENTS.md` in the repository root as the canonical instruction file. Read and follow it before performing any task.
For workflow commands, read `.agents/WORKFLOWS.md` and then the referenced repository-local skill.
```

## Unified 3-Tier Model Routing (`#plan`, `#exec`, `#exec-wave`)

All execution workflows follow a **Flash-First, Pro-on-Demand** tiering model based on the 1–10 complexity score assigned per step/batch:

| Tier                      | Complexity Score | Target Scope                                                                       | Subagent Model (`Mode A`)   |
| :------------------------ | :--------------- | :--------------------------------------------------------------------------------- | :-------------------------- |
| **Tier 1 (`FLASH_LITE`)** | `1–3`            | Copy updates, simple type exports, config tweaks, minor CSS/Tailwind (<300 lines)  | `flash_lite`                |
| **Tier 2 (`FLASH`)**      | `4–6`            | Standard component/hook batches (<= 3–4 files, clear interfaces, <500 lines)       | `flash` _(Default)_         |
| **Tier 3 (`PRO`)**        | `7–10`           | Cross-file Zustand state, SSR/Hydration, Audio/Video lifecycles, files >=500 lines | `pro` _(+ Reviewer at >=8)_ |

### 3-Tier Per-Batch Model Selection Rules

- **Tier 1 (`flash_lite` — Score 1–3):** Trivial/mechanical batches. Auto-Upgrade Guard: If a batch tagged `flash_lite` touches 4 or more files, Coordinator MUST automatically escalate its Model to `flash` upon invocation.
- **Tier 2 (`flash` — Score 4–6, Default):** Standard scoped implementation batches.
- **Tier 3 (`pro` — Score 7–10 or Unsliced Files >= 500 Lines): Complex state refactors, unsliced files >= 500 lines. Explicit `#flash` Override: If `#flash` is explicitly specified by user or roadmap, batches touching >= 500 line files route to `flash` instead of `pro`, provided the batch File Inventory <= 3 files and complexity score <= 6.
- **Auto-Escalation Rule:** If a Tier 1 (`flash_lite`) or Tier 2 (`flash`) step fails validation (`npm run lint` / `npm test`) and survives **one** targeted diagnostic repair attempt, escalate that specific step/batch immediately to Tier 3 (`pro`).
  - **Zero-PRO Token Guard (`--no-pro` / `--no-pro-escalation`):** If `--no-pro` is explicitly flagged or budget mode is active, automatic PRO escalation is suppressed. The agent halts in **Graceful Pause (Dirty Inspection)** after the single repair attempt to preserve modified files without spending PRO tokens.

## Multi-IDE Host Capability Matrix

When executing `#exec`, `#exec-wave`, `#delegate`, or `#deep-refactor`, translate subagent and tier directives according to the host environment's capabilities:

1. **Mode A — Native Multi-Model Subagents (e.g., Antigravity):**
   - Triggering `#exec` or `#exec-wave` explicitly authorizes tiered `Model` selection (`'flash_lite' | 'flash' | 'pro'`) over the default `'inherit'`.
   - Spawn isolated implementation subagents via `invoke_subagent` with `TypeName: 'self'` and explicit `Model: 'flash_lite' | 'flash' | 'pro'` per step/batch. For `Score >= 8` Red-Team audits, spawn a read-only auditor with `TypeName: 'research'`, `Model: 'pro'`, and `Role: 'Red-Team Auditor'` returning a compact 2-point audit report (`Verdict`, `Findings`).
   - **Kilo Code v7:** Its project `kilo.jsonc` uses an OpenCode-compatible configuration shape. Kilo loads root `AGENTS.md` automatically; list `.agents/WORKFLOWS.md` in the `instructions` array. Map `invoke_subagent` model tiers to Kilo's native `Task` tool and configured agent identifiers: Tier 1 -> `flash_lite`, Tier 2 -> `flash`, Tier 3 -> `pro` (implementer agent), architectural planning -> `pro_planner`, and `research` for read-only audits.
   - In VS Code, set `"files.autoSave": "afterDelay"` so agent edits are written to disk before filesystem and diff audits.
   - Support concurrent Scatter-Gather waves for disjoint file inventories.
   - Emit clickable live stream links immediately upon launching (`[⚡ Watch Stream](conversation://<conversation-id>)` or `[🛡️ Watch Red-Team Audit](conversation://<reviewer-conversation-id>)`).
   - Enforce the standardized 3-point completion feedback contract (`Status`, `Files Modified`, `Summary`) from all implementation subagents to aggregate clean wave summaries without context bloat.
2. **Mode B — Fixed-Model or Rate-Limited Subagents (e.g., Kimi Code, Claude Code CLI):**
   - Spawn subagents using the host's default/inherited model (`inherit` or `subagent_type="coder"`) to keep the Coordinator context clean. (Claude Code: Task subagents can map tiers to `haiku` / `sonnet` / `opus` via `model`; otherwise use `inherit`).
   - Apply `.agents/skills/flash/SKILL.md` stability rules and the 3-point completion feedback contract inside every subagent.
   - If the host UI cannot handle `conversation://` URIs, display the subagent ID and transcript file path as a readable fallback. Respect host concurrency limits (such as the sequential queue in `KIMI.md`).
3. **Mode C — Single-Agent IDEs without Subagents (e.g., Cline, Windsurf):**
   - Translate parallel waves into sequential, low-context batch passes (read only the files listed in the active batch).
   - Apply `.agents/skills/flash/SKILL.md` (Single-Action Protocol) for Tier 1–2 steps.
   - Before executing a Tier 3 (`PRO`, Score >= 7) step, emit a brief model-switch advisory if running on a lightweight/fast model, or perform a dedicated self-review pass before staging if already running on a high-reasoning model.
4. **Mode D — Cursor (Task Subagents, Limited Model Tiers):**
   - Cursor exposes isolated subagents via the native `Task` tool. Map abstract `invoke_subagent` / `TypeName` directives to `Task` — never call a nonexistent `invoke_subagent` tool.
   - **Implementer mapping:** `TypeName: 'self'` → `Task` with `subagent_type: "generalPurpose"` (or the host's best write-capable equivalent). Pass the full step/batch spec or `.tmp/` plan path in `prompt`; enforce the 3-point return contract and forbid subagent `git commit` / version bumps.
   - **Read-only auditor mapping:** `TypeName: 'research'` → `Task` with `subagent_type: "explore"` (or an explicit read-only prompt). Require the compact 2-point audit report (`Verdict`, `Findings`).
   - **Model tiers:** Do **not** pass `flash_lite` / `flash` / `pro` as Cursor model slugs. Default `model: "inherit"`. Treat Tier 1–2 as a **behavior** contract (apply `.agents/skills/flash/SKILL.md` inside the subagent or inline). Treat Tier 3 as Coordinator high-reasoning + explicit self-review (or spawn `Task` with `inherit` on a strong parent). Only pass a non-`inherit` slug when the user explicitly requested a model listed in the session's available subagent models.
   - **Inline vs. Task:** For a single Tier 1–2 step (`#exec N`) on a matching parent model, execute inline under Flash. For `#exec all`, `#exec-wave`, `#delegate`, `#solve`, or when the parent model differs from the step tier, spawn `Task` for context isolation.
   - **Waves:** Parallel Scatter-Gather is allowed when batch file inventories are disjoint. Overlapping inventories stay serial. Emit Cursor agent links as `[Name](agent-id)` (not `conversation://`). Persist plans/reports in `.tmp/`.
   - **Domain rules:** Before editing, Read every matching `.agents/rules/*.md` from the AGENTS routing table (Cursor does not auto-load those files unless a thin `.cursor/rules/*.mdc` mirror exists).

## Self-Contained Lockstep Dependency Group

Six files form one atomic documentation unit. A change to the tier table, the diff-audit protocol, the handoff link labels, or the subagent prompt contract in any one of them must be verified for parity in all of them within the same batch:

`.agents/rules/multi-ide-setup.md` · `.agents/skills/plan/SKILL.md` · `.agents/skills/exec/SKILL.md` · `.agents/skills/exec-wave/SKILL.md` · `.agents/skills/delegate/SKILL.md` · `.agents/skills/solve/SKILL.md`

- **No partial updates:** Never stage a lockstep change while another group member still documents the previous tier split, audit protocol, or link-label convention.
- **Parity probe:** `Select-String -Path .agents/skills/{plan,exec,exec-wave,delegate,solve}/SKILL.md -Pattern 'multi-ide-setup.md'` must match every workflow skill in the lockstep group.

## Combo Anti-Phantom Diff Audit

Every subagent return — and every lockstep commit — requires both probes, because neither one alone is complete:

```powershell
git --no-pager diff --name-only
git --no-pager status --porcelain
```

`git diff --name-only` omits untracked files; `git status --porcelain` alone blurs the modified/created distinction. Reconcile the **union** of both outputs against the plan's File Inventory.

- **Phantom reporting:** An assigned file absent from the union means the batch did not actually touch it. Reject the subagent's `SUCCESS` as `INCOMPLETE_TASK` / `PHANTOM_REPORTING` and run a targeted completion pass before staging anything.

## Shared Cross-IDE Working State (`.tmp/`)

For workflows that maintain execution context or reports across IDE boundaries (such as `#solve` and `#delegate`), working state and living plans are stored in `.tmp/` (gitignored) to ensure any editor or IDE can open and display files with standard `file:///` markdown links without depending on IDE-internal storage directories:
- `#solve` writes analysis & plan to `.tmp/solve_report.md`.
- Standalone `#delegate` writes to `.tmp/delegate_plan.md`.
- When `#delegate` is invoked as part of `#solve`, it passes `.tmp/solve_report.md` as its context file.

## Acceptance & Audit Criteria

1. **Canonical Root Reference:** All IDE adapter dotfiles (.clinerules, .cursor/rules/agents.mdc, KIMI.md, GEMINI.md) strictly point to `AGENTS.md` as the single canonical source of truth.
2. **3-Tier Model Table Parity:** The tier table reflects `flash_lite` (Score 1–3), `flash` (Score 4–6), and `pro` (Score 7–10) consistently across all workflow definitions.
3. **Subagent Type Identity:** Implementation subagents use abstract `TypeName: 'self'` (Mode A: `invoke_subagent`; Mode D: Cursor `Task` / `generalPurpose`) with host-appropriate model constraints; read-only auditors use abstract `TypeName: 'research'` (Mode A: `research`; Mode D: `explore`).
4. **IDE-Independent Storage:** Living execution plans and cross-IDE handoffs strictly write to `.tmp/` (gitignored), never IDE-internal state storage.
5. **Cursor Adapter Parity:** `.cursor/rules/agents.mdc` documents Mode D (not Mode C) and must not instruct agents to call `invoke_subagent` or pass `flash_lite`/`flash`/`pro` as Cursor model slugs.
