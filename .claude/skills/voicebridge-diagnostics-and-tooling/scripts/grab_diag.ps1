<#
.SYNOPSIS
  grab_diag.ps1 -- one-shot ADB evidence collector for VoiceBridge.
  Captures everything you need to reason about "what is the app doing right now"
  into a single timestamped folder, so debugging starts from evidence, not memory.

.DESCRIPTION
  Collects, in order:
    1. Connected device/emulator list (adb devices -l)
    2. Installed app version (dumpsys package com.mananpatel.voicebridge -> versionName/versionCode)
    3. Current foreground activity (dumpsys activity activities -> topResumedActivity)
    4. Recent logcat: full dump tail, app-pid-filtered dump, and crash-pattern scan
       (FATAL EXCEPTION / E AndroidRuntime -- the same gate smoke-test.ps1 uses)
    5. Screenshot (screencap -p, pulled to the output folder)
    6. UI hierarchy dump (uiautomator dump ui.xml) for selector debugging

  Output folder default: android/app/build/diag-<timestamp>/ (gitignored via
  android/.gitignore build/ rule), mirroring the smoke test's screenshot convention.

  ASCII-only: Windows PowerShell 5.1 reads .ps1 as ANSI; non-ASCII breaks parsing
  (same rule smoke-test.ps1 documents in its header).

  Read-only: this script never installs, taps, or mutates device or repo state.

.PARAMETER AppId       Application id. Default: com.mananpatel.voicebridge.
.PARAMETER AndroidHome Path to Android SDK. Default: C:\Android.
.PARAMETER OutDir      Output folder. Default: <repo>\android\app\build\diag-<timestamp>.
.PARAMETER LogLines    How many recent logcat lines to keep in the full dump. Default: 1500.

.EXAMPLE
  powershell -File .claude/skills/voicebridge-diagnostics-and-tooling/scripts/grab_diag.ps1
#>
param(
    [string] $AppId       = "com.mananpatel.voicebridge",
    [string] $AndroidHome = "C:\Android",
    [string] $OutDir      = "",
    [int]    $LogLines    = 1500
)

$ErrorActionPreference = "Continue"   # adb writes progress to stderr; do not abort on it
$Adb = Join-Path $AndroidHome "platform-tools\adb.exe"

if (-not (Test-Path $Adb)) {
    Write-Host "[diag] FATAL: adb not found at $Adb (pass -AndroidHome)" -ForegroundColor Red
    exit 2
}

if ($OutDir -eq "") {
    # Script lives at .claude/skills/voicebridge-diagnostics-and-tooling/scripts/
    $Root   = Resolve-Path "$PSScriptRoot\..\..\..\.."
    $Stamp  = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutDir = Join-Path $Root "android\app\build\diag-$Stamp"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Log { param([string]$m) Write-Host "[diag] $m" -ForegroundColor Cyan }
function Adb { & $Adb @args 2>$null }

Log "output folder: $OutDir"

# --- 1. devices ----------------------------------------------------------------
$devices = Adb devices -l
$devices | Out-File -FilePath (Join-Path $OutDir "devices.txt") -Encoding ascii
Log "devices:"
$devices | ForEach-Object { Write-Host "       $_" }
$online = $devices | Select-String "device product:|device usb:|device transport_id:"
if (-not $online) {
    $online = $devices | Select-String "\sdevice$"
}
if (-not $online) {
    Log "FATAL: no device/emulator online. Boot one first, e.g.:"
    Log "  & `"$AndroidHome\emulator\emulator.exe`" -avd voicebridge_avd"
    exit 2
}

# --- 2. app version --------------------------------------------------------------
$pkgDump = Adb shell dumpsys package $AppId
$pkgDump | Out-File -FilePath (Join-Path $OutDir "dumpsys-package.txt") -Encoding ascii
$verLines = $pkgDump | Select-String "versionName|versionCode|lastUpdateTime"
if ($verLines) {
    Log "app version:"
    $verLines | ForEach-Object { Write-Host "       $($_.Line.Trim())" }
} else {
    Log "WARNING: $AppId not installed on this device (no versionName in dumpsys)"
}

# --- 3. foreground activity ------------------------------------------------------
$top = Adb shell dumpsys activity activities | Select-String "topResumedActivity"
$topText = ""
if ($top) { $topText = ($top | ForEach-Object { $_.Line.Trim() }) -join "`r`n" }
$topText | Out-File -FilePath (Join-Path $OutDir "foreground-activity.txt") -Encoding ascii
if ($topText -match [regex]::Escape($AppId)) {
    Log "foreground: $AppId is the top resumed activity"
} else {
    Log "foreground: app is NOT foreground. Top activity:"
    Write-Host "       $topText"
}

# --- 4. logcat -------------------------------------------------------------------
Log "capturing logcat (last $LogLines lines + app-filtered + crash scan)..."
$fullLog = Adb logcat -d -t $LogLines -v time
$fullLog | Out-File -FilePath (Join-Path $OutDir "logcat-full.txt") -Encoding ascii

# App-pid-filtered view (pidof works on API 24+; empty if app not running)
$appPid = (Adb shell pidof $AppId | Out-String).Trim()
if ($appPid -ne "") {
    Log "app pid: $appPid"
    Adb logcat -d -v time --pid $appPid |
        Out-File -FilePath (Join-Path $OutDir "logcat-app.txt") -Encoding ascii
} else {
    Log "app process not running -- skipping pid-filtered logcat"
    "app process not running at capture time" |
        Out-File -FilePath (Join-Path $OutDir "logcat-app.txt") -Encoding ascii
}

# Crash scan: same patterns as the smoke test's crash gate (smoke-test.ps1 step 10)
$crashes = $fullLog | Select-String -Pattern "FATAL EXCEPTION|E AndroidRuntime"
if ($crashes) {
    $crashes | Out-File -FilePath (Join-Path $OutDir "logcat-crashes.txt") -Encoding ascii
    Log "CRASHES FOUND ($(@($crashes).Count) matching lines) -- see logcat-crashes.txt"
} else {
    "no FATAL EXCEPTION / E AndroidRuntime lines in captured window" |
        Out-File -FilePath (Join-Path $OutDir "logcat-crashes.txt") -Encoding ascii
    Log "no crash signatures in captured logcat window"
}

# --- 5. screenshot ---------------------------------------------------------------
Adb shell screencap -p /sdcard/diag.png | Out-Null
Adb pull /sdcard/diag.png (Join-Path $OutDir "screenshot.png") | Out-Null
Adb shell rm /sdcard/diag.png | Out-Null
if (Test-Path (Join-Path $OutDir "screenshot.png")) {
    Log "screenshot: screenshot.png"
} else {
    Log "WARNING: screenshot pull failed"
}

# --- 6. UI hierarchy (selector debugging) ----------------------------------------
Adb shell uiautomator dump /sdcard/diag-ui.xml | Out-Null
Adb pull /sdcard/diag-ui.xml (Join-Path $OutDir "ui.xml") | Out-Null
Adb shell rm /sdcard/diag-ui.xml | Out-Null
if (Test-Path (Join-Path $OutDir "ui.xml")) {
    Log "ui hierarchy: ui.xml (match nodes by @text / @content-desc, as smoke-test.ps1 does)"
} else {
    Log "WARNING: uiautomator dump failed (screen locked, or system UI busy)"
}

Log "DONE. Evidence folder: $OutDir"
exit 0
