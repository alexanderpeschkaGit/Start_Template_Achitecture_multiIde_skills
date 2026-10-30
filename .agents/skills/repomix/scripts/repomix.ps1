<#
.SYNOPSIS
    PowerShell-native runner for Repomix Codebase Bundler.

.DESCRIPTION
    Packs the repository into semantically partitioned chunks with a strict maximum
    limit of 130,000 characters per chunk, followed by an automated character audit.

.PARAMETER TargetFolder
    Target export directory name or version tag (e.g. 'v2', 'repomix_v2', or CLI flags).
    Normalized to 'repomix_<name>' unless it starts with 'repomix_', 'repomix-', or '-'.
    Default folder is 'repomix-output'.

.PARAMETER RemainingArgs
    Additional arguments and flags forwarded to repomix.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $false, HelpMessage = "Target export directory or version tag")]
    [string]$TargetFolder,

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

# 1. Resolve repository root via git or fallback to 4 levels above $PSScriptRoot
$repoRoot = $null
try {
    $gitOutput = git -C $PSScriptRoot rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and [string]::IsNullOrWhiteSpace($gitOutput) -eq $false -and (Test-Path $gitOutput)) {
        $repoRoot = (Resolve-Path $gitOutput).Path
    }
} catch {
    $repoRoot = $null
}

if (-not $repoRoot) {
    try {
        $repoRoot = (Resolve-Path "$PSScriptRoot\..\..\..\..").Path
    } catch {
        $repoRoot = (Get-Location).Path
    }
}

# 2. Normalize target folder name and extract CLI flags
$targetDirName = "repomix-output"
$forwardArgs = @()

if ($TargetFolder) {
    if ($TargetFolder.StartsWith("-")) {
        $targetDirName = "repomix-output"
        $forwardArgs += $TargetFolder
    } elseif ($TargetFolder -like "repomix_*" -or $TargetFolder -like "repomix-*") {
        $targetDirName = $TargetFolder
    } else {
        $targetDirName = "repomix_$TargetFolder"
    }
}

if ($RemainingArgs) {
    $forwardArgs += $RemainingArgs
}

$targetFullPath = if ([System.IO.Path]::IsPathRooted($targetDirName)) {
    $targetDirName
} else {
    Join-Path $repoRoot $targetDirName
}

# 3. Print generic banner
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host " Repomix Codebase Bundler" -ForegroundColor Cyan
Write-Host " Splitting into chunks with maximum 130,000 characters" -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "Repo Root    : $repoRoot" -ForegroundColor Gray
Write-Host "Target Folder: $targetDirName" -ForegroundColor Gray
Write-Host ""

# 4. Push-Location to repo root and execute Repomix safely
Push-Location $repoRoot
try {
    # Ensure target directory exists and clean old chunks only
    if (-not (Test-Path $targetFullPath)) {
        New-Item -ItemType Directory -Path $targetFullPath -Force | Out-Null
    } else {
        Write-Host "Cleaning previous chunks in '$targetDirName'..." -ForegroundColor Gray
        Get-ChildItem -Path $targetFullPath -File | Where-Object {
            $_.Name -like "bundle*.txt" -or $_.Name -like "bundle*.xml" -or $_.Name -eq "repomix-output.xml"
        } | Remove-Item -Force -ErrorAction SilentlyContinue
    }

    Write-Host "Starting Repomix..." -ForegroundColor Cyan
    $configPath = Join-Path $PSScriptRoot "repomix.config.json"
    $outputPath = Join-Path $targetDirName "bundle.txt"

    $repomixArgs = @("--config", $configPath, "--output", $outputPath)
    if ($forwardArgs -and $forwardArgs.Count -gt 0) {
        $repomixArgs += $forwardArgs
    }

    $repomixCmd = Get-Command repomix -ErrorAction SilentlyContinue
    if ($repomixCmd) {
        & $repomixCmd.Source @repomixArgs
    } else {
        npx --yes repomix @repomixArgs
    }

    $repomixExit = $LASTEXITCODE
    if ($repomixExit -ne 0) {
        Write-Host ""
        Write-Host "[ERROR] Repomix failed with exit code $repomixExit" -ForegroundColor Red
        exit $repomixExit
    }

    # Non-interactive execution: call repomix-audit.ps1
    $auditScript = Join-Path $PSScriptRoot "repomix-audit.ps1"
    if (Test-Path $auditScript) {
        & $auditScript -OutputDir $targetDirName
        $auditExit = $LASTEXITCODE
        if ($auditExit -ne 0) {
            exit $auditExit
        }
    } else {
        Write-Host "[WARN] Audit script not found at '$auditScript'." -ForegroundColor Yellow
    }
} finally {
    Pop-Location
}
