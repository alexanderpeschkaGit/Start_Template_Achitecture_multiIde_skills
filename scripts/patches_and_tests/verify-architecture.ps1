<#
.SYNOPSIS
    Template Architecture Verification Script
.DESCRIPTION
    Validates rules frontmatter, skills match, workflows registration, dangling references,
    text encodings/BOM/line-endings, contract consistency, PS syntax, and token blocklist.
.PARAMETER Root
    Repository root directory. Defaults to git root or script parent.
.PARAMETER Fix
    Converts line endings to CRLF and removes UTF-8 BOMs for text files in Root.
#>
[CmdletBinding()]
param(
    [string]$Root = "",
    [switch]$Fix
)

# 1. Resolve repository root
if (-not $Root) {
    try { $g = git rev-parse --show-toplevel 2>$null; if ($LASTEXITCODE -eq 0 -and $g) { $Root = $g.Trim() } } catch {}
    if (-not $Root -or -not (Test-Path $Root)) { $Root = (Resolve-Path "$PSScriptRoot\..\..").Path }
}
$Root = (Resolve-Path $Root).Path
Write-Host "Verifying repository at: $Root" -ForegroundColor Cyan

# 2. Helpers
function Get-RepoFiles([string]$dir) {
    Get-ChildItem -Path $dir -Recurse -File | Where-Object {
        $_.FullName.Substring($dir.Length).TrimStart('\', '/') -notmatch '^(\.git|repomix-output|\.tmp|node_modules)[\\/]'
    }
}

function Is-TextFile([System.IO.FileInfo]$f) {
    $bin = @('.png','.jpg','.jpeg','.gif','.ico','.webp','.pdf','.zip','.gz','.woff','.woff2','.ttf','.eot','.exe','.dll','.mp4','.webm')
    if ($bin -contains $f.Extension.ToLowerInvariant()) { return $false }
    if ($f.Length -eq 0) { return $true }
    $len = [Math]::Min([int]$f.Length, 8000); $buf = New-Object byte[] $len
    $s = [System.IO.File]::OpenRead($f.FullName); $r = $s.Read($buf, 0, $len); $s.Close()
    return ([Array]::IndexOf($buf, [byte]0, 0, $r) -eq -1)
}

$allFiles = @(Get-RepoFiles $Root)
$textFiles = @($allFiles | Where-Object { Is-TextFile $_ })

# 3. Optional -Fix switch execution
if ($Fix) {
    Write-Host "Applying -Fix (CRLF line endings & removing UTF-8 BOM)..." -ForegroundColor Yellow
    $u8 = [System.Text.UTF8Encoding]::new($false)
    foreach ($f in $textFiles) {
        $rel = ($f.FullName.Substring($Root.Length).TrimStart('\', '/')) -replace '\\', '/'
        if ($rel -eq '.kilo/.gitignore') { continue }
        $b = [System.IO.File]::ReadAllBytes($f.FullName)
        $hasBom = ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
        $t = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8).TrimStart([char]0xFEFF)
        if ($hasBom -or ($t -match '(?<!\r)\n')) {
            $crlf = $t -replace "\r\n", "`n" -replace "`r", "`n" -replace "`n", "`r`n"
            [System.IO.File]::WriteAllText($f.FullName, $crlf, $u8)
            Write-Host "  Fixed: $rel" -ForegroundColor Gray
        }
    }
}

$results = [System.Collections.Generic.List[PSCustomObject]]::new()
$allFailures = [System.Collections.Generic.List[string]]::new()

function Record-Check([string]$name, [System.Collections.Generic.List[string]]$errs) {
    $results.Add([PSCustomObject]@{ Check = $name; Status = if ($errs.Count -eq 0) { "PASS" } else { "FAIL" }; Errors = $errs.Count })
    foreach ($e in $errs) { $allFailures.Add("[$name] $e") }
}

# Check 1: Rules frontmatter & sections
$err1 = [System.Collections.Generic.List[string]]::new()
$rulesDir = Join-Path $Root ".agents\rules"
if (-not (Test-Path $rulesDir)) { $err1.Add("Missing .agents/rules") } else {
    $rFiles = Get-ChildItem -Path $rulesDir -Filter "*.md" -File
    if ($rFiles.Count -eq 0) { $err1.Add("No rule files found in .agents/rules") }
    foreach ($rf in $rFiles) {
        $c = [System.IO.File]::ReadAllText($rf.FullName, [System.Text.Encoding]::UTF8); $rel = ".agents/rules/$($rf.Name)"
        if ($c -notmatch '(?s)^---\r?\n(.*?)\r?\n---') { $err1.Add("$rel missing YAML frontmatter"); continue }
        $fm = $Matches[1]
        if ($fm -notmatch '(?m)^trigger:\s*model_decision\b') { $err1.Add("$rel missing 'trigger: model_decision'") }
        if ($fm -notmatch '(?m)^globs:\s*.+') { $err1.Add("$rel missing 'globs:'") }
        if ($fm -notmatch '(?m)^description:\s*.+') { $err1.Add("$rel missing 'description:'") }
        if ($c -notmatch '(?m)^## Acceptance & Audit Criteria\b') {
            $err1.Add("$rel missing '## Acceptance & Audit Criteria'")
        } elseif ($c -match '(?s)## Acceptance & Audit Criteria\b.*(?m)^##\s+[^\r\n]+') {
            $err1.Add("$rel has trailing ## section after Acceptance & Audit Criteria")
        }
    }
}
Record-Check "1. Rules frontmatter & sections" $err1

# Check 2: Skills frontmatter & folder match
$err2 = [System.Collections.Generic.List[string]]::new()
$skillsDir = Join-Path $Root ".agents\skills"
if (-not (Test-Path $skillsDir)) { $err2.Add("Missing .agents/skills") } else {
    $sFiles = Get-ChildItem -Path $skillsDir -Filter "SKILL.md" -Recurse -File
    if ($sFiles.Count -eq 0) { $err2.Add("No SKILL.md found in .agents/skills") }
    foreach ($sf in $sFiles) {
        $folder = $sf.Directory.Name; $rel = ".agents/skills/$folder/SKILL.md"
        $c = [System.IO.File]::ReadAllText($sf.FullName, [System.Text.Encoding]::UTF8)
        if ($c -notmatch '(?s)^---\r?\n(.*?)\r?\n---') { $err2.Add("$rel missing frontmatter"); continue }
        $fm = $Matches[1]
        if ($fm -match '(?m)^name:\s*[''"]?([^''"\r\n]+)[''"]?') {
            if ($Matches[1].Trim() -ne $folder) { $err2.Add("$rel name '$($Matches[1].Trim())' != folder '$folder'") }
        } else { $err2.Add("$rel missing 'name:'") }
        if ($fm -notmatch '(?m)^description:\s*.+') { $err2.Add("$rel missing 'description:'") }
    }
}
Record-Check "2. Skills frontmatter & folder match" $err2

# Check 3: Workflows registration
$err3 = [System.Collections.Generic.List[string]]::new()
$wfPath = Join-Path $Root ".agents\WORKFLOWS.md"
if (-not (Test-Path $wfPath)) { $err3.Add("Missing .agents/WORKFLOWS.md") } else {
    $wf = [System.IO.File]::ReadAllText($wfPath, [System.Text.Encoding]::UTF8); $checked = @{}
    foreach ($m in [regex]::Matches($wf, '(?:\.agents|scripts|[A-Za-z0-9_\-]+\.md)[A-Za-z0-9_\-\.\/]*')) {
        $p = $m.Value.TrimEnd('.', ',', ';', ':', '`', '"', "'")
        if ($p -and -not $checked.ContainsKey($p)) {
            $checked[$p] = $true
            if (-not (Test-Path (Join-Path $Root ($p -replace '/', '\')))) { $err3.Add("Path in WORKFLOWS.md missing: $p") }
        }
    }
    if (Test-Path $skillsDir) {
        foreach ($sd in (Get-ChildItem -Path $skillsDir -Directory)) {
            if ($wf -notmatch [regex]::Escape(".agents/skills/$($sd.Name)")) {
                $err3.Add("Skill '$($sd.Name)' not registered in WORKFLOWS.md")
            }
        }
    }
}
Record-Check "3. Workflows registration" $err3

# Check 4: Dangling references
$err4 = [System.Collections.Generic.List[string]]::new()
$chkFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
foreach ($tg in @("AGENTS.md", "CLAUDE.md", "GEMINI.md", "KIMI.md", ".clinerules", ".windsurfrules")) {
    $p = Join-Path $Root $tg; if (Test-Path $p -PathType Leaf) { $chkFiles.Add((Get-Item $p)) }
}
foreach ($sub in @(".agents", ".kilo", ".cursor")) {
    $sd = Join-Path $Root $sub
    if (Test-Path $sd) {
        Get-ChildItem -Path $sd -Recurse -File | Where-Object { if ($sub -eq ".agents") { $_.Extension -eq ".md" } else { $true } } | ForEach-Object { $chkFiles.Add($_) }
    }
}
foreach ($f in $chkFiles) {
    if (-not (Is-TextFile $f)) { continue }
    $relFile = ($f.FullName.Substring($Root.Length).TrimStart('\', '/')) -replace '\\', '/'
    $txt = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    foreach ($m in [regex]::Matches($txt, '`([^`\r\n]+)`')) {
        $v = $m.Groups[1].Value.Trim()
        if ($v -match '^(\.agents|scripts|\.kilo|\.cursor|\.github)[\\/]') {
            if ($v -match '[\*<\{]' -or $v -match '(\.tmp|plans)[\\/]') { continue }
            $norm = ($v -replace '[#:\?].*$', '').TrimEnd('\', '/')
            if (-not (Test-Path (Join-Path $Root ($norm -replace '/', '\')))) {
                $err4.Add("$relFile references missing path: $v")
            }
        }
    }
}
Record-Check "4. Dangling references" $err4

# Check 5: Encoding, BOM & Line Endings
$err5 = [System.Collections.Generic.List[string]]::new()
$gitAttr = Join-Path $Root ".gitattributes"; $lfPats = @()
if (Test-Path $gitAttr) {
    (Get-Content $gitAttr) | ForEach-Object { $l = $_.Trim(); if ($l -and -not $l.StartsWith("#") -and $l -match 'eol=lf') { $lfPats += ($l -split '\s+')[0] } }
}
$garbledPattern = "[\u00E2][\u20AC\u2020]|[\u00C3][\u0080-\u00BF]"
foreach ($tf in $textFiles) {
    $rel = ($tf.FullName.Substring($Root.Length).TrimStart('\', '/')) -replace '\\', '/'
    $b = [System.IO.File]::ReadAllBytes($tf.FullName)
    if ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) { $err5.Add("$rel has UTF-8 BOM") }
    $exempt = ($rel -eq '.kilo/.gitignore')
    if (-not $exempt) { foreach ($pat in $lfPats) { if ($rel -like $pat -or $tf.Name -like $pat) { $exempt = $true; break } } }
    $t = [System.Text.Encoding]::UTF8.GetString($b)
    if (-not $exempt -and ($t -match '(?<!\r)\n')) { $err5.Add("$rel has bare LF (CRLF required)") }
    if ($t -match $garbledPattern) { $err5.Add("$rel contains garbled characters (matched '$($Matches[0])')") }
}
Record-Check "5. Encoding, BOM & Line Endings" $err5

# Check 6: Contract consistency
$err6 = [System.Collections.Generic.List[string]]::new()
foreach ($sk in @("plan", "exec", "exec-wave", "delegate", "solve")) {
    $p = Join-Path $Root ".agents\skills\$sk\SKILL.md"
    if (-not (Test-Path $p)) { $err6.Add("Missing .agents/skills/$sk/SKILL.md") }
    elseif ([System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) -notmatch 'multi-ide-setup\.md') {
        $err6.Add(".agents/skills/$sk/SKILL.md does not contain 'multi-ide-setup.md'")
    }
}
Record-Check "6. Contract consistency" $err6

# Check 7: PowerShell syntax parse
$err7 = [System.Collections.Generic.List[string]]::new()
foreach ($psf in ($allFiles | Where-Object { $_.Extension.ToLowerInvariant() -eq '.ps1' })) {
    $rel = ($psf.FullName.Substring($Root.Length).TrimStart('\', '/')) -replace '\\', '/'
    $tok = $null; $pErr = $null
    try { $null = [System.Management.Automation.Language.Parser]::ParseFile($psf.FullName, [ref]$tok, [ref]$pErr) }
    catch {
        try { $null = [System.Management.Automation.Language.Parser]::ParseFile($psf.FullName, [ref]$null, [ref]$tok, [ref]$pErr) }
        catch { $err7.Add("$rel parse exception: $($_.Exception.Message)"); continue }
    }
    if ($pErr -and $pErr.Count -gt 0) {
        foreach ($pe in $pErr) { $err7.Add("$rel line $($pe.Extent.StartLineNumber): $($pe.Message)") }
    }
}
Record-Check "7. PowerShell syntax parse" $err7

# Check 8: Token blocklist
$err8 = [System.Collections.Generic.List[string]]::new()
$tokRegex = '(?i)\b(Vijay|Sikanda|Portfolio|bunny|server-hono|media-canonicalization|useVideoStore|ios-stable-video|zoom-media)\b'
foreach ($tf in $textFiles) {
    $rel = ($tf.FullName.Substring($Root.Length).TrimStart('\', '/')) -replace '\\', '/'
    if ($rel -eq 'howto.info' -or $rel -eq 'scripts/patches_and_tests/verify-architecture.ps1') { continue }
    if ([System.IO.File]::ReadAllText($tf.FullName, [System.Text.Encoding]::UTF8) -match $tokRegex) {
        $err8.Add("$rel contains blocked token '$($Matches[0])'")
    }
}
Record-Check "8. Token blocklist" $err8

# 4. Summary & Output
Write-Host ""
Write-Host "=== ARCHITECTURE VERIFICATION REPORT ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize | Out-String | Write-Host
if ($allFailures.Count -gt 0) {
    Write-Host "Detailed Failures ($($allFailures.Count)):" -ForegroundColor Red
    foreach ($f in $allFailures) { Write-Host "  $f" -ForegroundColor Red }
    Write-Host "`nVerification FAILED." -ForegroundColor Red
    exit 1
} else {
    Write-Host "All architecture checks PASSED." -ForegroundColor Green
    exit 0
}
