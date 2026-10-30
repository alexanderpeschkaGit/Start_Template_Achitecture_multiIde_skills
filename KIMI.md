# Kimi Code Instructions

This repository uses `AGENTS.md` in the repository root as the canonical instruction file. Read and follow it before performing any task.
For workflow commands, read `.agents/WORKFLOWS.md` and then the referenced repository-local skill.

## Kimi Capability Translation

### `pro` subagent

When a rule requires a `pro` subagent, use the Kimi Code `Agent` tool with `subagent_type="coder"`. Supply the exact file paths, dependency list, and safeguards so its output meets the global decomposition and completeness standard.

### `flash` mode / `#flash`

When a rule references `flash` or `#flash`, read and apply `.agents/skills/flash/SKILL.md`.

### `#grillme` interview

When a rule requires `#grillme`, read `.agents/skills/grillme/SKILL.md` and resolve the relevant ambiguity before editing.

## Rate Limits & Paced Execution (3 RPM)

Kimi Code operates under a strict limit of **3 Requests Per Minute (RPM)**. All tool calls, model inferences, and subagent spawns count against this quota.

To prevent `429 Too Many Requests`:
1. **Pacing Throttle:** Enforce a minimum pause of **25 seconds** between state-changing steps, subagent invocations, and build/validation commands.
2. **Strict Sequential Execution (Concurrency = 1):** Never spawn subagents in parallel. All tasks, delegations, and subagent runs must execute strictly **one at a time**.
3. **Rate-Limit Backoff:** Upon receiving a `429`, immediately pause execution for **40 seconds** before attempting the next request.

## Workflows: Deep Refactor & Multiagent Translation

When executing `#deep-refactor`, `#refactor`, or any workflow that normally uses a concurrent "Scatter-Gather" pattern:

1. **Disable Scatter-Gather:** Replace parallel subagent calls with a **Sequential Queue**:
   - The Coordinator writes individual step plans as usual.
   - Subagents are invoked **one by one**: invoke Subagent 1 → wait for completion → pause 25s → invoke Subagent 2.
2. **Prefer Single-Agent Execution When Feasible:** If file extractions are small or closely coupled, the Main Agent should perform the sequential refactoring steps directly rather than delegating to multiple subagents, drastically conserving RPM quota.
3. **Mega-File Pipeline:** For large files, follow the sequential pipeline (State → Hooks → UI components → Cutover), completing each phase sequentially and running validation only after each full phase rather than after every file change.
4. **Validation Pacing:** Allow the compiler and file system to settle; pause 25 seconds after the last file edit before running `tsc` or `npm run build`.

## Tooling Notes for This Environment

Kimi Code on this machine runs through Git Bash. The project’s `AGENTS.md` recommends PowerShell-native cmdlets for manual use, but Kimi Code’s file tools (`Read`, `Edit`, `Write`, `Glob`, `Grep`) and Bash tool are the preferred way to interact with the repository from this agent. Prefer the dedicated file tools over raw shell commands for file operations; use Bash only for shell semantics (npm, git, build runners) and observe the single-action protocol.
