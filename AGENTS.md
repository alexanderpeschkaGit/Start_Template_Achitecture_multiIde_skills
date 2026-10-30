# Engineering and Assistant Instructions (NewProject)

These repository instructions are the authoritative project contract. Project-specific behavior and architecture rules take precedence over general coding preferences. When two rules appear to conflict, preserve the established application behavior and apply the more narrowly scoped rule.

> [!IMPORTANT] IDE / COPILOT ROUTING INSTRUCTIONS (PROGRESSIVE DISCLOSURE)
> To keep the context window lean, domain rules and workflow instructions are NOT preloaded into every turn.
> 1. **Before writing or modifying code**, match the files you will touch against the routing table below and read every matching `.agents/rules/*.md` file.
> 2. **When a user prompt contains a workflow tag** (e.g. `#ask`, `#grillme`, `#plan`, `#exec`, `#review`, `#refactor`, `#solve`), read `.agents/WORKFLOWS.md` and only the corresponding skill file.

## Deterministic File-to-Rule Routing

Deep-dive rules live in `.agents/rules/`. Before editing, match the files you will touch and read every rule that applies:

| Files / Directories | Rule |
| --- | --- |
| `src/**/*.{tsx,css}` | `.agents/rules/styling-ui.md` |
| `src/store/**`, `src/hooks/**`, `src/services/**` | `.agents/rules/core-react-state.md` |
| `src/utils/**`, `src/**/*.ts` | `.agents/rules/core-react-state.md` |
| `server/**`, `functions/**`, `wrangler.toml` | `.agents/rules/backend-edge.md` |
| `src/components/**`, `src/hooks/**`, `src/config/siteConfig.ts`, `.agents/rules/*.md` | `.agents/rules/boilerplate-standards.md` |
| `AGENTS.md`, `.agents/**/*.md` | `.agents/rules/multi-ide-setup.md` |
| `CLAUDE.md`, `GEMINI.md`, `KIMI.md`, `.clinerules`, `.windsurfrules`, `.cursor/rules/**`, `.trae/rules/**`, `.github/copilot-instructions.md`, `kilo.jsonc`, `.kilo/agent/**` | `.agents/rules/multi-ide-setup.md` |

## Host Environment

- **OS/Shell:** Windows 11 (x64) with PowerShell 5.1+; backslash path separator; never assume POSIX paths.
- **Forbidden Unix-only tools:** `sed`, `awk`, `grep` (use `Select-String`), `chmod`, `touch`, `cat` (`Get-Content`), `rm` (`Remove-Item`), `cp` (`Copy-Item`), `mv` (`Move-Item`). Prefer PowerShell cmdlets or built-in agent file tools.
- **Line endings:** CRLF is the default; do not force LF-only endings unless `.gitattributes` requires it.

## Code Quality & Modularity Limits

- Apply KISS, practical DRY, and SRP. Use descriptive English identifiers; comments explain *why*, not *what*.
- **File Size & Refactoring Limits:**
  - **300–499 lines (Warning):** Warn the user and propose a decomposition (candidate subcomponents, custom hooks, or utility extractions).
  - **500+ lines (Mandatory Decomposition):** Refactor into modular subcomponents (`src/components/`), custom hooks (`src/hooks/`), Zustand stores (`src/store/`), and pure utilities (`src/utils/`), delegating complex decompositions to a `pro` subagent where supported.
- Produce complete, production-ready implementations. Never replace required logic with placeholders such as `// ...`.
- **Version Bumping:** Bump the patch version once per completed plan, in the final checkpoint commit. (Coordinator only; skipped when no package.json exists).
- **Script Organization:** Place one-off utility scripts, automated patches, and test scripts in `scripts/patches_and_tests/`. Keep the root repository clean.

## Decision Gate & Interaction Contract

- **Default is action, not a question:** Report progress and pending state as factual statements rather than asking routine confirmation questions.
- **Single-Question Rule:** Ask at most ONE open question per turn. If multiple decisions are pending, bundle them into a single structured query, or run `#grillme` before editing.
- **Branch & Git Policy:** Checkpoint commits go to the active development branch (default `preview` or `feature/*` / `task/*`; never `main` / `master`).
- **Hard Stops — Always ask:**
  - Actions that leave the local working tree or are irreversible without user prompting: AI-initiated `git push`, pushing to `main`/`production`, deploying to production, git history rewrites, starting persistent background daemons, or deleting user data.
  - Genuine validation failures that survive agreed repair attempts.

## Brand & Configuration SSOT

- **Zero-Hardcoding Contract:** Hardcoded brand names, email addresses, social links, or CDN URLs are forbidden in UI components or server routes. Consume all brand and environment metadata dynamically from `src/config/siteConfig.ts` (`SITE_CONFIG`).

## Canonical Verification Command Matrix

Run the smallest command that covers the change; escalate to the full suite only when targeted checks fail.

| Scope | Command | Gate |
| --- | --- | --- |
| Types + ESLint (always) | `npm run lint` | exit `0` |
| Formatting | `npm run format` | clean diff |
| Unit tests | `npm test` | exit `0` |