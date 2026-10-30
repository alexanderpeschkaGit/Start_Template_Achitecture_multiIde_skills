<#
.SYNOPSIS
    Generates a clean ZIP archive of the repository excluding all .gitignore files.

.DESCRIPTION
    Uses Git and .NET ZipArchive to build a clean ZIP distribution.
    By default, it respects .gitignore rules completely and excludes:
    - Anything ignored by .gitignore (e.g., node_modules, dist, .cache, .env, build artifacts)
    - The internal .git/ directory itself
    - Any destination *.zip files (preventing recursive inclusion)
    - Additional artifacts matched by -AdditionalExcludes (default: *.zip, *.tmp, .env*, *.pem, *.key)

.PARAMETER OutputPath
    The target ZIP file path. Defaults to <RepoRoot>/<RepoName>_v<Version>_<Timestamp>.zip.

.PARAMETER Mode
    Selection mode:
    - 'WorkingTree' (Default): Includes tracked files + untracked non-ignored files.
    - 'Head': Fast export of committed files at Git HEAD (via git archive or ls-tree).
    - 'TrackedOnly': Includes git-tracked files only, using current working-tree content.

.PARAMETER Prefix
    Optional root directory name inside the ZIP archive.

.PARAMETER AdditionalExcludes
    Additional glob patterns or filenames to exclude (e.g., @('*.zip', '*.tmp', '.env*')).

.PARAMETER DryRun
    If set, lists files that would be included and outputs file counts without creating the ZIP.

.PARAMETER Force
    Overwrite output ZIP if it already exists.

.EXAMPLE
    .\zip-clean.ps1
    Creates a timestamped zip in the repository root.

.EXAMPLE
    .\zip-clean.ps1 -OutputPath "C:\Backups\Project_Backup.zip" -Force

.EXAMPLE
    .\zip-clean.ps1 -DryRun
#>

[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [string]$OutputPath,

    [Parameter()]
    [ValidateSet('WorkingTree', 'Head', 'TrackedOnly')]
    [string]$Mode = 'WorkingTree',

    [Parameter()]
    [string]$Prefix = '',

    [Parameter()]
    [string[]]$AdditionalExcludes = @('*.zip', '*.tmp', '.env*', '*.pem', '*.key'),

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [switch]$Force
)

Set-StrictMode -Off
$ErrorActionPreference = 'Stop'

$prevEncoding = [Console]::OutputEncoding
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

    # 1. Locate repository root and verify Git work tree
    $insideWorkTree = (git rev-parse --is-inside-work-tree 2>$null)
    $isGitRepo = ($LASTEXITCODE -eq 0 -and $insideWorkTree -eq 'true')

    if ($isGitRepo) {
        $repoRootRaw = (git rev-parse --show-toplevel 2>$null)
        if ($repoRootRaw -and (Test-Path $repoRootRaw)) {
            $repoRoot = (Get-Item $repoRootRaw).FullName
        } else {
            $repoRoot = (Get-Item (Get-Location).Path).FullName
        }
    } else {
        $repoRoot = (Get-Item (Get-Location).Path).FullName
        Write-Warning "Not inside a detected git repository. Working in: $repoRoot"
    }

    # 2. Extract repository name & optional version from package.json
    $repoName = Split-Path $repoRoot -Leaf
    $version = ""
    $pkgJsonPath = Join-Path $repoRoot "package.json"
    if (Test-Path $pkgJsonPath) {
        try {
            $pkg = Get-Content -Raw -Path $pkgJsonPath | ConvertFrom-Json
            if ($pkg.version) {
                $version = "v$($pkg.version)_"
            }
        } catch {
            # ignore parse errors
        }
    }

    # 3. Determine default OutputPath
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    if (-not $OutputPath) {
        $zipFileName = "${repoName}_${version}${timestamp}.zip"
        $OutputPath = Join-Path $repoRoot $zipFileName
    }

    $resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
    $outputFileName = [System.IO.Path]::GetFileName($resolvedOutput)

    # 4. Handle existing output file
    if ((Test-Path $resolvedOutput) -and -not $Force -and -not $DryRun) {
        throw "Target archive already exists: $resolvedOutput. Use -Force to overwrite."
    }

    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host " Clean ZIP Generator (Excluding .gitignore)" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Repository Root : $repoRoot"
    Write-Host "Archive Mode    : $Mode"
    Write-Host "Target Archive  : $resolvedOutput"
    if ($Prefix) { Write-Host "Archive Prefix  : $Prefix" }

    # 5. Gather file list respecting .gitignore
    Push-Location $repoRoot
    try {
        $files = @()
        if ($isGitRepo) {
            $gitRaw = $null
            if ($Mode -eq 'Head') {
                # Committed files at HEAD
                $gitRaw = git -c core.quotePath=false ls-tree -r -z --name-only HEAD 2>$null
            } elseif ($Mode -eq 'TrackedOnly') {
                # Tracked files (working tree state)
                $gitRaw = git -c core.quotePath=false ls-files -z --cached 2>$null
            } else {
                # WorkingTree mode: tracked + untracked non-ignored files
                $gitRaw = git -c core.quotePath=false ls-files -z --cached --others --exclude-standard 2>$null
            }

            if ($gitRaw) {
                $files = ($gitRaw -join "`n") -split "`0" | Where-Object { -not [string]::IsNullOrEmpty($_) }
            }

            if (-not $files -or $files.Count -eq 0) {
                throw "No files found for mode '$Mode' in git repository at '$repoRoot' (e.g. no commits at HEAD or index is empty)."
            }
        } else {
            # Fallback for non-git directories
            Write-Warning "No git repository detected. Checking directory fallback..."
            $excludedDirs = @('.git', 'node_modules', 'dist', '.wrangler', '.tmp')
            $files = Get-ChildItem -Recurse -File | Where-Object {
                $relative = $_.FullName.Substring($repoRoot.Length).TrimStart('\')
                $segments = $relative -split '[\\/]'
                $inExcludedDir = $false
                for ($i = 0; $i -lt ($segments.Count - 1); $i++) {
                    if ($excludedDirs -contains $segments[$i] -or $segments[$i] -like 'repomix*') { $inExcludedDir = $true; break }
                }
                (-not $inExcludedDir)
            } | ForEach-Object {
                $_.FullName.Substring($repoRoot.Length).TrimStart('\')
            }
        }
    } finally {
        Pop-Location
    }

    # 6. Filter file list
    $filteredFiles = [System.Collections.Generic.List[string]]::new()
    $skippedMissingFiles = [System.Collections.Generic.List[string]]::new()
    $totalRawBytes = 0

    foreach ($rel in $files) {
        if (-not $rel) { continue }

        # Normalize slashes for comparison
        $normalizedRel = $rel.Replace('/', '\')
        $fullPath = Join-Path $repoRoot $normalizedRel

        # Check existence on disk for working tree modes
        if ($Mode -ne 'Head') {
            if (-not (Test-Path $fullPath -PathType Leaf)) {
                if ($Mode -eq 'WorkingTree') {
                    $skippedMissingFiles.Add($rel)
                }
                continue
            }
        }

        # Exclude target output file if within repository tree
        if ([string]::Equals($fullPath, $resolvedOutput, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        # Exclude additional patterns
        $fileName = [System.IO.Path]::GetFileName($fullPath)
        $skip = $false
        foreach ($pattern in $AdditionalExcludes) {
            if ($fileName -like $pattern -or $normalizedRel -like $pattern -or $rel -like $pattern) {
                $skip = $true
                break
            }
        }
        if ($skip) { continue }

        $filteredFiles.Add($rel)
        if ($Mode -ne 'Head' -and (Test-Path $fullPath -PathType Leaf)) {
            $item = Get-Item $fullPath
            $totalRawBytes += $item.Length
        }
    }

    if ($skippedMissingFiles.Count -gt 0) {
        $missingList = ($skippedMissingFiles | ForEach-Object { "  - $_" }) -join "`n"
        Write-Warning "Skipped $($skippedMissingFiles.Count) file(s) reported by git but not found on disk:`n$missingList"
    }

    $rawSizeMB = [math]::Round($totalRawBytes / 1MB, 2)
    if ($Mode -eq 'Head') {
        Write-Host "Matched Files   : $($filteredFiles.Count) files (HEAD commit)" -ForegroundColor Green
    } else {
        Write-Host "Matched Files   : $($filteredFiles.Count) files ($rawSizeMB MB uncompressed)" -ForegroundColor Green
    }

    # 7. Dry run check
    if ($DryRun) {
        Write-Host "`n[DRY RUN] The following files would be packaged:" -ForegroundColor Yellow
        $displayLimit = [math]::Min($filteredFiles.Count, 25)
        for ($i = 0; $i -lt $displayLimit; $i++) {
            Write-Host "  + $($filteredFiles[$i])"
        }
        if ($filteredFiles.Count -gt 25) {
            Write-Host "  ... and $($filteredFiles.Count - 25) more files." -ForegroundColor DarkGray
        }
        Write-Host "`nDry run complete. No ZIP file was created." -ForegroundColor Yellow
        return
    }

    # 8. Create ZIP archive
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $parentDir = Split-Path $resolvedOutput -Parent
    if ($parentDir -and -not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    if (Test-Path $resolvedOutput) {
        Remove-Item $resolvedOutput -Force
    }

    if ($Mode -eq 'Head') {
        # Head mode: Use git archive to export strictly committed HEAD content
        $gitArchiveArgs = [System.Collections.Generic.List[string]]::new()
        $gitArchiveArgs.Add('archive')
        $gitArchiveArgs.Add('--format=zip')
        $gitArchiveArgs.Add('-o')
        $gitArchiveArgs.Add($resolvedOutput)

        if ($Prefix) {
            $trimmedPrefix = $Prefix.TrimEnd('/')
            $gitArchiveArgs.Add("--prefix=$trimmedPrefix/")
        }

        $gitArchiveArgs.Add('HEAD')
        $gitArchiveArgs.Add('--')
        $gitArchiveArgs.Add('.')

        foreach ($pat in $AdditionalExcludes) {
            if (-not [string]::IsNullOrWhiteSpace($pat)) {
                $globPat = if ($pat.StartsWith('**/') -or $pat.StartsWith('/')) { $pat } else { "**/$pat" }
                $gitArchiveArgs.Add(":(exclude,glob)$globPat")
            }
        }

        Push-Location $repoRoot
        try {
            & git @gitArchiveArgs
            if ($LASTEXITCODE -ne 0) {
                throw "git archive failed with exit code $LASTEXITCODE."
            }
        } finally {
            Pop-Location
        }
    } else {
        # WorkingTree and TrackedOnly modes: use .NET ZipArchive to capture working tree files
        Add-Type -AssemblyName System.IO.Compression
        Add-Type -AssemblyName System.IO.Compression.FileSystem

        $zip = [System.IO.Compression.ZipFile]::Open($resolvedOutput, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            $count = 0
            foreach ($rel in $filteredFiles) {
                $fullPath = Join-Path $repoRoot $rel.Replace('/', '\')

                # Zip entry paths MUST use forward slashes for universal compatibility
                $entryName = $rel.Replace('\', '/')
                if ($Prefix) {
                    $trimmedPrefix = $Prefix.TrimEnd('/')
                    $entryName = "$trimmedPrefix/$entryName"
                }

                # Write to archive with optimal compression
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                    $zip,
                    $fullPath,
                    $entryName,
                    [System.IO.Compression.CompressionLevel]::Optimal
                ) | Out-Null

                $count++
                if ($count % 50 -eq 0 -or $count -eq $filteredFiles.Count) {
                    Write-Progress -Activity "Compressing clean archive" -Status "$count / $($filteredFiles.Count) files" -PercentComplete (($count / $filteredFiles.Count) * 100)
                }
            }
        } finally {
            $zip.Dispose()
            Write-Progress -Activity "Compressing clean archive" -Completed
        }
    }

    $sw.Stop()

    # 9. Verify and output results
    if (Test-Path $resolvedOutput) {
        $zipItem = Get-Item $resolvedOutput
        $zipSizeMB = [math]::Round($zipItem.Length / 1MB, 2)
        $elapsedSec = [math]::Round($sw.Elapsed.TotalSeconds, 2)
        $packagedCount = $filteredFiles.Count

        Write-Host "`n==========================================" -ForegroundColor Green
        Write-Host " ARCHIVE SUCCESSFULLY CREATED" -ForegroundColor Green
        Write-Host "==========================================" -ForegroundColor Green
        Write-Host "File:       $($zipItem.FullName)"
        if ($totalRawBytes -gt 0) {
            $ratio = [math]::Round((1 - ($zipItem.Length / $totalRawBytes)) * 100, 1)
            Write-Host "Size:       $zipSizeMB MB (Saved $ratio% vs $rawSizeMB MB raw)"
        } else {
            Write-Host "Size:       $zipSizeMB MB"
        }
        Write-Host "Files:      $packagedCount files packaged"
        Write-Host "Duration:   $elapsedSec seconds"
        Write-Host "==========================================" -ForegroundColor Green
    } else {
        throw "Failed to create archive at $resolvedOutput."
    }
} finally {
    [Console]::OutputEncoding = $prevEncoding
}
