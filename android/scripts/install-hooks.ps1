<#
.SYNOPSIS
  Copies VoiceBridge git hook templates from android/scripts/hooks/ to .git/hooks/.

.DESCRIPTION
  The .git/ directory is not tracked by git, so hooks must be re-installed on every
  fresh clone. Run this script once after cloning, and again whenever hook templates change.

.EXAMPLE
  powershell -File android/scripts/install-hooks.ps1
#>

$RepoRoot = Resolve-Path "$PSScriptRoot\..\.."
$HookSrc  = Join-Path $PSScriptRoot "hooks"
$HookDst  = Join-Path $RepoRoot ".git\hooks"

if (-not (Test-Path $HookSrc)) {
    Write-Host "ERROR: Hook source not found at $HookSrc" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $HookDst)) {
    New-Item -ItemType Directory -Force $HookDst | Out-Null
}

$count = 0
Get-ChildItem $HookSrc | ForEach-Object {
    $dest = Join-Path $HookDst $_.Name
    Copy-Item $_.FullName $dest -Force
    Write-Host "  Installed: .git/hooks/$($_.Name)" -ForegroundColor Green
    $count++
}

Write-Host ""
Write-Host "Installed $count hook(s)." -ForegroundColor Green
Write-Host ""
Write-Host "Git workflow:" -ForegroundColor Cyan
Write-Host "  git checkout -b v0.0.3            # start a new version branch"
Write-Host "  ... make changes ..."
Write-Host "  git commit -m 'feat: description' # smoke test runs; no merge (CHANGELOG not updated)"
Write-Host "  ... update CHANGELOG.md ..."
Write-Host "  git commit -m 'chore: v0.0.3'     # smoke test + auto-merge + push to origin"
Write-Host ""
Write-Host "To run the smoke test manually (without merging):"
Write-Host "  powershell -File android/scripts/smoke-test.ps1 -Build"
