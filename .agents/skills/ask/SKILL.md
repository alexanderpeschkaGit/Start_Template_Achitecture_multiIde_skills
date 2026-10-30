---
name: ask
description: Explain or investigate without modifying files. Triggered when the user uses the #ask tag or /ask command.
---

# Ask / Read-Only Investigation Skill (`#ask`)

1. **Read-Only Contract:** Do NOT create, edit, stage, or delete any repository files.
2. **Targeted Inspection:** Read only the files and `.agents/rules/*.md` domain rules relevant to the user's question.
3. **Traceable Answers:** Reference exact file paths and line ranges using clickable markdown links.