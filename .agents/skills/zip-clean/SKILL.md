---
name: zip-clean
description: >-
  Generate a clean ZIP archive of the repository or project directory, excluding all files and directories matched by .gitignore, .git metadata, and temporary files.
  Triggered by #zip-clean, /zip-clean, #export-zip, /export-zip, #zip, /zip, or when the user asks to zip or package the project without gitignored files.
---

# Clean ZIP Generator Workflow (`#zip-clean`)

**Purpose:** Package the repository or target project into a clean, distributable ZIP archive that strictly respects `.gitignore` rules, strips `.git/` version-control metadata, excludes destination `.zip` files, and prevents inclusion of build artifacts, dependencies (`node_modules`), secrets, or cache files.

---

## Capabilities & Modes

The skill provides three modes of operation via its bundled PowerShell script `.agents/skills/zip-clean/scripts/zip-clean.ps1`:

| Mode | Command Flag | Inclusions | Best For |
| :--- | :--- | :--- | :--- |
| **`WorkingTree`** *(Default)* | `-Mode WorkingTree` | Tracked files + newly added untracked non-ignored files | Sharing current work-in-progress, backups, code handoffs with active uncommitted changes |
| **`Head`** | `-Mode Head` | Strictly committed files at `HEAD` (via `git archive`) | Clean release packaging, tagged version snapshots without dirty working tree state |
| **`TrackedOnly`** | `-Mode TrackedOnly` | Tracked files only (reflecting current file content) | Excluding all untracked files while preserving uncommitted edits to tracked files |

### Unicode & Non-ASCII Path Support

The script natively supports paths with Unicode characters, spaces, and umlauts. It sets console output encoding to UTF-8 (`[System.Text.UTF8Encoding]::new($false)`) within a try/finally block and queries Git using `-c core.quotePath=false` and `-z` (NUL-byte delimiters) to avoid octal character escaping and encoding corruption.

---

## Execution Instructions

### Option 1: Automatic Agent Execution (Recommended)

When the user asks to create a zip or triggers `#zip-clean`:

1. **Resolve Destination Path & Naming:**
   - Default filename: `<RepoName>_<Version>_<Timestamp>.zip` in the repository root or parent directory.
   - If user specified a custom path (e.g., `dist/backup.zip` or desktop), resolve the absolute path.

2. **Execute the Bundled Script via PowerShell:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File .agents/skills/zip-clean/scripts/zip-clean.ps1 -Mode WorkingTree
   ```
   *Custom path example:*
   ```powershell
   powershell -ExecutionPolicy Bypass -File .agents/skills/zip-clean/scripts/zip-clean.ps1 -OutputPath "C:\Backups\Project_Clean.zip" -Force
   ```
   *Dry-run example:*
   ```powershell
   powershell -ExecutionPolicy Bypass -File .agents/skills/zip-clean/scripts/zip-clean.ps1 -DryRun
   ```

3. **Verify Archive Integrity:**
   - Confirm file exists and size is greater than 0 bytes.
   - Verify that excluded paths (`node_modules`, `.git`, `.env*`, `dist`, `.wrangler`, `.tmp`, `repomix*`) and secret artifacts (`*.pem`, `*.key`) are absent from the archive entries.
   - Note file count, uncompressed size, compressed size, and elapsed time.

4. **Deliver Concise Summary:**
   Provide the user with:
   - Full path to the created `.zip` file
   - File size (in MB)
   - Number of files packaged
   - Compression ratio achieved

---

### Option 2: Quick Terminal / npm Script (Optional)

If desired, an optional npm script shortcut can be added to `package.json`:

```json
{
  "scripts": {
    "zip": "powershell -ExecutionPolicy Bypass -File .agents/skills/zip-clean/scripts/zip-clean.ps1"
  }
}
```

When configured, users can directly run from PowerShell:
```powershell
npm run zip
```
Or with custom arguments passed through npm:
```powershell
npm run zip -- -DryRun
npm run zip -- -OutputPath "release.zip" -Mode Head -Force
```

Alternatively, invoke the PowerShell script directly:
```powershell
powershell -ExecutionPolicy Bypass -File .agents/skills/zip-clean/scripts/zip-clean.ps1 -DryRun
powershell -ExecutionPolicy Bypass -File .agents/skills/zip-clean/scripts/zip-clean.ps1 -OutputPath "release.zip" -Mode Head -Force
```

---

### Option 3: Pure Git CLI Alternative (Committed HEAD only)

If running in environments without PowerShell access:
```bash
git archive -o "archive_HEAD.zip" HEAD
```
*Note: `git archive` only bundles committed files at HEAD and will omit uncommitted modifications or new untracked files.*

---

## Parameter Reference (`.agents/skills/zip-clean/scripts/zip-clean.ps1`)

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `-OutputPath` | `string` | `<Repo>_v<Ver>_<Timestamp>.zip` | Target `.zip` path. Relative or absolute. |
| `-Mode` | `string` | `'WorkingTree'` | Selection mode: `'WorkingTree'`, `'Head'`, or `'TrackedOnly'`. |
| `-Prefix` | `string` | `''` | Optional root directory folder name inside the archive. |
| `-AdditionalExcludes` | `string[]` | `@('*.zip', '*.tmp', '.env*', '*.pem', '*.key')` | Extra glob patterns to exclude from packaging. |
| `-DryRun` | `switch` | `false` | Lists files and counts without writing any file to disk. |
| `-Force` | `switch` | `false` | Overwrites destination `.zip` if it already exists. |

> [!NOTE] **Git Repository vs. Directory Fallback:** The script checks `git rev-parse --is-inside-work-tree`. If inside a Git repository but the queried mode returns zero files (e.g. `Head` mode before the initial commit), the script throws an error rather than incorrectly archiving the unignored directory tree. The directory fallback (`Get-ChildItem -Recurse -File`) only activates when the script is executed outside of a Git repository entirely, skipping `.git`, `node_modules`, `dist`, `.wrangler`, `.tmp`, and every `repomix*` directory before applying `-AdditionalExcludes`.

---

## References

- Detailed edge cases and troubleshooting: [troubleshooting.md](./references/troubleshooting.md)
- Bundled automation script: [zip-clean.ps1](./scripts/zip-clean.ps1)
