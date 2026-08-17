#Requires -Version 5.1
<#
.SYNOPSIS
  Point brand-specific skill dirs at the canonical .agents/skills folder.
.DESCRIPTION
  Cursor / Kimi Code / most Codex-class agents already scan .agents/skills/.
  Claude Code and Reasonix typically scan .claude/skills or .reasonix/skills.
  This script creates local junctions (Windows) so those agents load the same
  reviewed skills without copying files. Brand dirs are gitignored — do not commit them.
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

$Canonical = Join-Path $Root ".agents\skills"
if (-not (Test-Path -LiteralPath $Canonical)) {
    Write-Error "Canonical skills dir not found: $Canonical"
    exit 1
}

$CanonicalFull = (Resolve-Path -LiteralPath $Canonical).Path
$Adapters = @(
    (Join-Path $Root ".claude\skills"),
    (Join-Path $Root ".reasonix\skills")
)

function Test-PointsToCanonical([string]$Path, [string]$Target) {
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        try {
            $dest = (Resolve-Path -LiteralPath $Path).Path
            return ($dest -eq $Target)
        } catch {
            return $false
        }
    }
    return $false
}

Write-Host "Repo root: $Root"
Write-Host "Canonical: $CanonicalFull"

foreach ($link in $Adapters) {
    $parent = Split-Path -Parent $link
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }
    if (Test-PointsToCanonical $link $CanonicalFull) {
        Write-Host ("OK already linked: " + $link)
        continue
    }
    if (Test-Path -LiteralPath $link) {
        Write-Host ("SKIP exists and is not a junction to canonical: " + $link) -ForegroundColor Yellow
        continue
    }
    New-Item -ItemType Junction -Path $link -Target $CanonicalFull | Out-Null
    Write-Host ("Linked: " + $link)
}

Write-Host "Done. Cursor / Kimi Code do not need this script; they scan .agents/skills/ natively."
exit 0
