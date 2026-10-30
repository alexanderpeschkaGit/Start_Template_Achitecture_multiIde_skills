<#
.SYNOPSIS
    Bootstraps the Progressive-Disclosure AI Agent Architecture into a target project.
.PARAMETER TargetDir
    Destination project root directory.
.PARAMETER ProjectName
    Project name for AGENTS.md header (defaults to TargetDir folder name).
.PARAMETER Force
    Overwrite existing files in TargetDir if present.
.PARAMETER DryRun
    Preview actions without writing any changes.
.EXAMPLE
    scripts\init-agent-architecture.ps1 -TargetDir "C:\MyProject"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$TargetDir,
    [string]$ProjectName = "",
    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$TemplateRoot = (Resolve-Path "$PSScriptRoot\..").Path

if (-not (Test-Path -LiteralPath $TargetDir) -and -not $DryRun) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}
$ResolvedTarget = if (Test-Path -LiteralPath $TargetDir) { (Resolve-Path -LiteralPath $TargetDir).Path } else { [System.IO.Path]::GetFullPath($TargetDir) }
if ([string]::IsNullOrWhiteSpace($ProjectName)) { $ProjectName = Split-Path -Path $ResolvedTarget -Leaf }

Write-Host "=== Initializing Agent Architecture: '$ProjectName' ===" -ForegroundColor Magenta
Write-Host "Source: $TemplateRoot"
Write-Host "Target: $ResolvedTarget"
if ($DryRun) { Write-Host "[DRY-RUN MODE ACTIVE]" -ForegroundColor Cyan }

$Manifest = @(
    "AGENTS.md", "GEMINI.md", "CLAUDE.md", "KIMI.md", ".clinerules", ".windsurfrules",
    "kilo.jsonc", ".agents", ".cursor\rules", ".trae\rules", ".kilo\agent",
    ".github\copilot-instructions.md", ".github\workflows\ci.yml", ".gitattributes"
)

$FilesToCopy = [System.Collections.Generic.List[string]]::new()
foreach ($item in $Manifest) {
    $srcPath = Join-Path $TemplateRoot $item
    if (-not (Test-Path -LiteralPath $srcPath)) { continue }
    $items = if ((Get-Item -LiteralPath $srcPath) -is [System.IO.DirectoryInfo]) {
        Get-ChildItem -LiteralPath $srcPath -Recurse -File
    } else { Get-Item -LiteralPath $srcPath }
    foreach ($f in $items) {
        $rel = $f.FullName.Substring($TemplateRoot.Length).TrimStart('\', '/')
        if ($rel -notmatch '^(howto\.info|scripts[\\/]|(?:\.git[\\/]|\.git$)|(?:\.tmp[\\/]|\.tmp$)|repomix)') {
            $FilesToCopy.Add($rel)
        }
    }
}

foreach ($relPath in $FilesToCopy) {
    $srcFile = Join-Path $TemplateRoot $relPath
    $dstFile = Join-Path $ResolvedTarget $relPath
    $action = if (-not (Test-Path -LiteralPath $dstFile)) { "CREATE" } elseif ($Force) { "OVERWRITE" } else { "SKIP" }

    if ($DryRun) {
        Write-Host "[$action] $relPath" -ForegroundColor $(if ($action -eq 'SKIP') { 'Yellow' } else { 'Cyan' })
        continue
    }
    if ($action -eq "SKIP") {
        Write-Host "[SKIP] $relPath (exists, use -Force to overwrite)" -ForegroundColor Yellow
        continue
    }

    $parentDir = Split-Path -Path $dstFile -Parent
    if (-not (Test-Path -LiteralPath $parentDir)) { New-Item -ItemType Directory -Path $parentDir -Force | Out-Null }

    if ((Split-Path -Path $relPath -Leaf) -ieq "AGENTS.md") {
        $content = [System.IO.File]::ReadAllText($srcFile, [System.Text.Encoding]::UTF8).Replace("(NewProject)", "($ProjectName)") -replace "`r?`n", "`r`n"
        [System.IO.File]::WriteAllText($dstFile, $content, (New-Object System.Text.UTF8Encoding($false)))
    } else {
        [System.IO.File]::Copy($srcFile, $dstFile, $true)
    }
    Write-Host "[$action] $relPath" -ForegroundColor Green
}

# .gitignore handling
$srcGitIgnore = Join-Path $TemplateRoot ".gitignore"
$dstGitIgnore = Join-Path $ResolvedTarget ".gitignore"
if (Test-Path -LiteralPath $srcGitIgnore) {
    if (-not (Test-Path -LiteralPath $dstGitIgnore)) {
        if ($DryRun) {
            Write-Host "[CREATE] .gitignore" -ForegroundColor Cyan
        } else {
            [System.IO.File]::Copy($srcGitIgnore, $dstGitIgnore, $true)
            Write-Host "[CREATE] .gitignore" -ForegroundColor Green
        }
    } else {
        $inBlock = $false
        $block = [System.Collections.Generic.List[string]]::new()
        foreach ($line in [System.IO.File]::ReadAllLines($srcGitIgnore)) {
            if ($line -match '^\s*#\s*---\s*agent-architecture\s*---') { $inBlock = $true }
            if ($inBlock) {
                $block.Add($line)
                if ($line -match '^\s*#\s*---\s*end agent-architecture\s*---') { break }
            }
        }
        $dstSet = [System.Collections.Generic.HashSet[string]]::new([string[]][System.IO.File]::ReadAllLines($dstGitIgnore), [System.StringComparer]::Ordinal)
        $toMerge = @($block | Where-Object { -not $dstSet.Contains($_) })

        if ($toMerge.Count -eq 0) {
            Write-Host "[SKIP] .gitignore (all rules present)" -ForegroundColor Yellow
        } elseif ($DryRun) {
            Write-Host "[MERGE] .gitignore ($($toMerge.Count) lines to merge)" -ForegroundColor Cyan
        } else {
            $dstText = [System.IO.File]::ReadAllText($dstGitIgnore, [System.Text.Encoding]::UTF8)
            $prefix = if ($dstText.Length -gt 0 -and -not $dstText.EndsWith("`n")) { "`r`n" } else { "" }
            [System.IO.File]::AppendAllText($dstGitIgnore, $prefix + ($toMerge -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "[MERGE] .gitignore ($($toMerge.Count) lines merged)" -ForegroundColor Green
        }
    }
}

Write-Host "=== Initialization Complete ===" -ForegroundColor Magenta
