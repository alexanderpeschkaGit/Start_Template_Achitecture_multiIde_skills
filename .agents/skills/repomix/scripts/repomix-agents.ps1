<#
.SYNOPSIS
    Bundles agent instructions, workflows, rules, and skills into a single XML artifact.

.DESCRIPTION
    Runs Repomix with repomix-agents.config.json to generate repomix-output.xml
    at the repository root and performs a character audit (<= 130,000 limit).
#>

[CmdletBinding()]
param()

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

$configPath = Join-Path $PSScriptRoot "repomix-agents.config.json"
$outputFile = Join-Path $repoRoot "repomix-output.xml"

Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host " Repomix Unified Agents & Instructions Bundler" -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "Config: $configPath" -ForegroundColor Gray
Write-Host "Target: $outputFile" -ForegroundColor Gray
Write-Host ""

Push-Location $repoRoot
try {
    $repomixCmd = Get-Command repomix -ErrorAction SilentlyContinue

    if ($repomixCmd) {
        & $repomixCmd.Source --config $configPath
    } else {
        npx --yes repomix --config $configPath
    }

    $repomixExit = $LASTEXITCODE
    if ($repomixExit -ne 0) {
        Write-Host "[ERROR] Repomix failed with exit code $repomixExit" -ForegroundColor Red
        exit $repomixExit
    }

    if (Test-Path $outputFile) {
        $item = Get-Item $outputFile
        $content = Get-Content -Path $outputFile -Raw -Encoding utf8
        $charCount = if ($null -ne $content) { $content.Length } else { 0 }
        $fileMatches = [regex]::Matches($content, '<file path="([^"]+)"')
        $isValid = $charCount -le 130000

        Write-Host ""
        if ($isValid) {
            Write-Host "========================================================================" -ForegroundColor Green
            Write-Host " BUNDLE VERIFICATION: SUCCESS (<= 130,000 characters)" -ForegroundColor Green
            Write-Host "========================================================================" -ForegroundColor Green
        } else {
            Write-Host "========================================================================" -ForegroundColor Red
            Write-Host " BUNDLE VERIFICATION: FAILED (> 130,000 characters)" -ForegroundColor Red
            Write-Host "========================================================================" -ForegroundColor Red
        }

        Write-Host "Output File : $($item.FullName)"
        Write-Host ("File Size   : {0:N0} Bytes" -f $item.Length)
        Write-Host ("Char Count  : {0:N0} Characters" -f $charCount)
        Write-Host "Packed Files: $($fileMatches.Count) files"
        Write-Host ("Audit Status: " + $(if ($isValid) { "[OK] <= 130k" } else { "[FAIL] Exceeds 130k limit" }))
        Write-Host "========================================================================" -ForegroundColor $(if ($isValid) { "Green" } else { "Red" })

        if (-not $isValid) {
            Write-Host "[ERROR] Unified bundle exceeds the 130,000 character limit ($charCount characters)." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "[ERROR] Expected output file not found: $outputFile" -ForegroundColor Red
        exit 1
    }
} finally {
    Pop-Location
}
