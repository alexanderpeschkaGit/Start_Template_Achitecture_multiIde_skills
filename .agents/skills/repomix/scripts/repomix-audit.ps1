<#
.SYNOPSIS
    Strict character count audit for Repomix output chunks.

.DESCRIPTION
    Audits character counts of Repomix chunk output files against the strict
    130,000 character limit. Exits with code 1 if any chunk exceeds the limit.

.PARAMETER OutputDir
    Destination folder containing chunk files (defaults to 'repomix-output').
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$OutputDir = "repomix-output"
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

# 2. Resolve target output directory
$targetDir = if ([System.IO.Path]::IsPathRooted($OutputDir)) {
    $OutputDir
} else {
    Join-Path $repoRoot $OutputDir
}

if (-not (Test-Path $targetDir)) {
    Write-Host "[ERROR] Directory '$targetDir' does not exist." -ForegroundColor Yellow
    exit 1
}

$files = Get-ChildItem -Path $targetDir -File | Sort-Object Name

if (-not $files) {
    Write-Host "[WARN] No files found in '$targetDir'." -ForegroundColor Yellow
    exit 0
}

# 3. Print audit banner and evaluate character limits
Write-Host ""
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host " REPOMIX CHUNK AUDIT (Maximum Limit: 130,000 characters)" -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Cyan

$allValid = $true
$summary = foreach ($file in $files) {
    $content = Get-Content -Path $file.FullName -Raw -Encoding utf8
    $charCount = if ($null -ne $content) { $content.Length } else { 0 }
    $isValid = $charCount -le 130000
    if (-not $isValid) {
        $allValid = $false
    }

    [PSCustomObject]@{
        File       = $file.Name
        Characters = "{0,8:N0}" -f $charCount
        Bytes      = "{0,8:N0}" -f $file.Length
        Status     = if ($isValid) { "[OK] <= 130k" } else { "[FAIL] > 130k" }
    }
}

$summary | Format-Table -AutoSize

Write-Host "------------------------------------------------------------------------" -ForegroundColor Cyan
if ($allValid) {
    Write-Host "Result: All $($files.Count) chunk(s) are strictly within the 130,000 character limit." -ForegroundColor Green
    Write-Host "Location: $targetDir" -ForegroundColor Gray
    Write-Host "========================================================================" -ForegroundColor Cyan
    Write-Host ""
    exit 0
} else {
    Write-Host "Warning: At least one chunk exceeds the 130,000 character limit!" -ForegroundColor Red
    Write-Host "Location: $targetDir" -ForegroundColor Gray
    Write-Host "========================================================================" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}
