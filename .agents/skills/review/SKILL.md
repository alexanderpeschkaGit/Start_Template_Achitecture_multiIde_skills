---
name: review
description: Audit the code in context without modifying it. Triggered when the user uses the #review tag or /review command.
---

# Code Audit & Review Skill (`#review`)

1. **Read-Only Contract:** Do NOT modify files during `#review`.
2. **Rule Compliance Check:** Verify the target files against `AGENTS.md` and every matching `.agents/rules/*.md` rule.
3. **Prioritized Findings:** Report concrete bugs, regressions, unhandled edge cases, and rule violations ordered by severity (High / Medium / Low) with exact file/line links.