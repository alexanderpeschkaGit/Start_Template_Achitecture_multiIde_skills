---
name: delegate
description: Writes a focused execution plan to .tmp/ and spawns an isolated subagent to execute it, preventing Coordinator context bloat. Triggered by #delegate or /delegate.
---

# Context-Saving Subagent Delegation (`#delegate`)

1. **Persist Plan:** Write the scoped batch specification and File Inventory to `.tmp/delegate_plan.md`.
2. **Spawn Subagent:** Delegate implementation according to the host mode and 3-Tier table in `.agents/rules/multi-ide-setup.md`. Forbid the subagent from running `git commit` or bumping `package.json`.
3. **Verify Return:** Run the Combo Anti-Phantom Diff Audit from `.agents/rules/multi-ide-setup.md` and `npm run lint` upon completion.