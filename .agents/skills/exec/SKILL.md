---
name: exec
description: Implement steps from the most recent plan. Triggered when the user uses the #exec tag or /exec command.
---

# Plan Execution Skill (`#exec`)

1. **Tiered Execution:** Follow the 3-Tier Model Routing and Multi-IDE rules in `.agents/rules/multi-ide-setup.md`.
2. **Domain Rule Check:** Before editing any file in a batch, ensure its matching `.agents/rules/*.md` files from `AGENTS.md` have been read.
3. **Verification & Anti-Phantom Audit:** Run the Combo Anti-Phantom Diff Audit (`git --no-pager diff --name-only` and `git --no-pager status --porcelain`) and `npm run lint` before marking a batch complete.
4. **Commit & Ownership:** Only the Coordinator creates git commits; checkpoint commit per completed batch on the active development branch; run `npm test` when present; bump patch version only at the final checkpoint of the completed plan (skipped if no package.json).