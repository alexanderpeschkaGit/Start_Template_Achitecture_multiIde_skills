---
name: plan
description: Inspect the relevant repository context and create a detailed plan before proposing changes. Triggered when the user uses the #plan tag or /plan command.
---

# Implementation Planning Skill (`#plan`)

1. **Read-Only Phase:** Inspect affected files and matching `.agents/rules/*.md` rules without modifying source files.
2. **Structured Steps & Complexity Scoring:** Break the implementation into numbered steps/batches. Assign each step a Complexity Score (`1–10`) and Tier (`FLASH_LITE`, `FLASH`, or `PRO`) per `.agents/rules/multi-ide-setup.md`.
3. **Explicit File Inventory:** List the exact files to create or modify in each step and specify the verification commands from `AGENTS.md`.