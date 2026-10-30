---
name: solve
description: Investigates an issue, drafts an execution plan in .tmp/solve_report.md, and delegates execution while keeping Coordinator context lean. Triggered by #solve or /solve.
---

# End-to-End Investigation & Delegated Fix (`#solve`)

1. **Diagnose & Plan:** Inspect the root cause, match `.agents/rules/*.md`, and write the diagnosis and execution plan to `.tmp/solve_report.md`.
2. **Delegate Execution:** Execute via `#delegate` using the 3-Tier table in `.agents/rules/multi-ide-setup.md`, passing `.tmp/solve_report.md` as the context file for subagent delegation.
3. **Audit & Report:** Verify via the Combo Anti-Phantom Diff Audit from `.agents/rules/multi-ide-setup.md` and `npm run lint`, then append the final verification summary to `.tmp/solve_report.md`.