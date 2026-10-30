# Troubleshooting & Edge Cases (`zip-clean`)

## 1. Locked Files
If an editor or background server has locked a file, PowerShell's `.NET ZipArchive` might raise an `IOException` (`The process cannot access the file because it is being used by another process`).
- **Fix:** Stop active dev servers (`npm run dev`) or test runners before running `.agents/skills/zip-clean/scripts/zip-clean.ps1`.

## 2. Long Path Names on Windows
Windows path limits (MAX_PATH = 260 characters) can sometimes affect deep folder structures.
- `.agents/skills/zip-clean/scripts/zip-clean.ps1` uses .NET `[System.IO.Compression.ZipFile]` which supports long paths natively when paths are normalized.
- If you encounter a MAX_PATH issue, specify an `-OutputPath` near the drive root (e.g., `C:\temp\archive.zip`).

## 3. Accidental Inclusion of the ZIP Itself
When creating an archive inside the repository folder (e.g., `Y:\repo\archive.zip`), a naive file search might attempt to zip `archive.zip` while it is being written, causing recursion or corruption.
- `zip-clean.ps1` automatically excludes `$resolvedOutput` by comparing absolute paths before archiving, preventing this issue.

## 4. Cross-Platform ZIP Separators
Windows standard paths use backslashes (`\`), but ZIP file specifications require entry keys to use forward slashes (`/`).
- `zip-clean.ps1` explicitly converts relative paths to `/` when creating archive entries:
  ```powershell
  $entryName = $rel.Replace('\', '/')
  ```
  This ensures compatibility when opening the resulting archive on Linux, macOS, Android, or cloud servers.

## 5. Secret Protection
`git ls-files --exclude-standard` strictly obeys `.gitignore`, and `-AdditionalExcludes` defaults to `@('*.zip', '*.tmp', '.env*', '*.pem', '*.key')`, so stray secrets are filtered even when a rule is missing from `.gitignore`.
- For other secret naming schemes (e.g. `*.p12`, `*.pfx`, `id_rsa*`), append patterns: `-AdditionalExcludes @('*.zip','*.tmp','.env*','*.pem','*.key','*.p12','id_rsa*')`.
- The exclude list is a safety net, not a replacement for ignore rules — always add sensitive files to `.gitignore` as well.

## 6. Unicode and Non-ASCII Path Handling
PowerShell console host configurations may default to OEM codepages (e.g., CP437 or CP1252), and Git quotes non-ASCII paths using octal escape sequences by default (`core.quotePath=true`).
- `zip-clean.ps1` sets `[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)` inside a `try ... finally` block, restoring the previous encoding upon completion.
- File enumeration executes with `git -c core.quotePath=false ls-files -z ...` (or `ls-tree -z` for Head mode) and splits strings on the NUL character (`` `0 ``), ensuring filenames containing spaces, umlauts, accents, and international characters are parsed without corruption.

## 7. Head Mode Committed Content Integrity
In `Head` mode, the script executes `git archive --format=zip -o <out> [--prefix=<Prefix>/] HEAD -- . ':(exclude,glob)**/<pattern>'...` directly against the Git object database rather than reading from disk.
- This guarantees that uncommitted changes, staged but uncommitted edits, or deleted tracked files in the local working directory do not contaminate release snapshot archives.
- In `-DryRun` mode, `git -c core.quotePath=false ls-tree -r -z --name-only HEAD` filtered against pathspecs is used to preview committed archive contents.

## 8. Missing Files in WorkingTree Mode
If a tracked file has been deleted from disk without staging or committing the deletion, `git ls-files` may still list it.
- `zip-clean.ps1` verifies `Test-Path` on disk for each candidate in `WorkingTree` mode, collects all missing paths, and emits a structured `Write-Warning` detailing the skipped count and file list.

## 9. Non-Git Fallback vs. Empty Repository Safeguard
The script tests whether it is operating within a valid Git work tree using `git rev-parse --is-inside-work-tree`.
- **Inside Git Repository:** If the queried mode yields zero files (for example, running in `Head` mode on a newly initialized repository before the first commit), the script throws a descriptive error and halts. It will **not** silently dump the unignored filesystem tree.
- **Outside Git Repository:** The fallback file scan (`Get-ChildItem -Recurse -File`) only activates when the repository check fails completely. The fallback explicitly ignores `.git`, `node_modules`, `dist`, `.wrangler`, `.tmp`, and `repomix*` directories before applying `-AdditionalExcludes`.
