---
name: flash
description: Enforce high-stability execution rules optimized for high-speed / Flash models. Triggered when the user uses the #flash or /flash command.
---

# High-Stability Flash Execution Rules (`#flash`)

1. **Micro-Batches:** Touch at most 3 files per step. Never perform whole-file rewrites on files >= 500 lines.
2. **Single-Action Protocol:** Execute shell commands one at a time without chaining `&&` or `;`.
3. **Trace & Verify:** If an edit or lint check fails, inspect the exact lines with `read_file` or `Select-String` before attempting a single targeted fix.