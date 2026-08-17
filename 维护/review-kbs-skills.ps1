#Requires -Version 5.1
<#
.SYNOPSIS
  Static review of in-repo KBS Agent Skills (not an attack script).
.DESCRIPTION
  Whitelist dirs, denylist patterns, frontmatter. Exit 0 pass, 1 fail.
#>
$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$marker = Join-Path ".agents\skills\kbs-red-team" "SKILL.md"
while ($Root) {
    if (Test-Path -LiteralPath (Join-Path $Root $marker)) { break }
    $parent = Split-Path -Parent $Root
    if (-not $parent -or $parent -eq $Root) { break }
    $Root = $parent
}
$SkillsRoot = Join-Path $Root ".agents\skills"
$Allowed = @("kbs-red-team", "kbs-weekly-update", "kbs-skill-guard")
$Fail = New-Object System.Collections.Generic.List[string]

function Add-Fail([string]$Msg) { [void]$Fail.Add($Msg) }

Write-Host "Review root: $Root"

if (-not (Test-Path -LiteralPath $SkillsRoot)) {
    Write-Error "Skills dir not found: $SkillsRoot"
    exit 1
}

$dirs = Get-ChildItem -LiteralPath $SkillsRoot -Directory -Force
foreach ($d in $dirs) {
    if ($Allowed -notcontains $d.Name) {
        Add-Fail ("Unlisted skill dir: " + $d.Name)
    }
    $scripts = Join-Path $d.FullName "scripts"
    if (Test-Path $scripts) {
        Add-Fail ($d.Name + " contains scripts/")
    }
    $bins = Get-ChildItem -LiteralPath $d.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -match '\.(exe|dll|bin|so|dylib|ps1|bat|cmd|sh)$' }
    foreach ($b in $bins) {
        Add-Fail ($d.Name + " forbidden file: " + $b.Name)
    }
}

$skillFiles = @(Get-ChildItem -LiteralPath $SkillsRoot -Recurse -Filter SKILL.md -Force -ErrorAction SilentlyContinue)
$n = @($skillFiles).Count
if ($n -eq 0) { Add-Fail ("No SKILL.md under " + $SkillsRoot) }

$deny = @(
    'ignore (all )?previous instructions',
    'do not tell the (user|human)',
    'jailbreak',
    'curl[^\n]{0,80}\|\s*(ba)?sh',
    'invoke-expression|\biex\b',
    'downloadstring',
    'bypass (the )?red.?line'
)

foreach ($f in $skillFiles) {
    $text = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
    $rel = $f.FullName.Substring($Root.Length).TrimStart('\', '/')
    $lines = ($text -split "`n").Count
    if ($lines -gt 500) { Add-Fail ($rel + " exceeds 500 lines") }
    if ($text -notmatch '(?m)^---\s*$') { Add-Fail ($rel + " missing YAML frontmatter") }
    if ($text -notmatch '(?m)^name:\s*\S') { Add-Fail ($rel + " missing name") }
    if ($text -notmatch '(?m)^description:') { Add-Fail ($rel + " missing description") }
    foreach ($p in $deny) {
        if ([regex]::IsMatch($text, $p, 'IgnoreCase')) {
            Add-Fail ($rel + " denylist hit: " + $p)
        }
    }
    $hexHits = ([regex]::Matches($text, '\\x[0-9a-fA-F][0-9a-fA-F]')).Count
    if ($hexHits -ge 24) { Add-Fail ($rel + " possible shellcode hex block") }
}

if ($Fail.Count -gt 0) {
    Write-Host "SKILL REVIEW FAILED" -ForegroundColor Red
    $Fail | ForEach-Object { Write-Host (" - " + $_) }
    exit 1
}

Write-Host ("SKILL REVIEW OK, files=" + $n)
exit 0
