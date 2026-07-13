<#
.SYNOPSIS
  VoiceBridge smoke test -- build, install, drive the app through Record/Stop/Play/Transcribe/Translate,
  capture a screenshot of each step, and fail loudly on any crash or missing UI element.
  Codifies the manual post-feature verification as a single repeatable command.

.DESCRIPTION
  Steps:
    0. Credential hygiene + verify_structure.py check
    1. (optional) assembleDebug
    2. Ensure emulator is booted
    3. adb install -r; grant RECORD_AUDIO programmatically (avoids dialog blocking tests)
    4. Launch app, screenshot initial state; verify all buttons present
    5. Verify initial enabled/disabled states (Record=on, Stop/Play/Transcribe/Translate=off)
    6. Tap Record -> wait 2s -> screenshot recording state (Stop=on, Record=off)
    7. Tap Stop -> screenshot stopped state (Play=on, Transcribe=on, Translate=off)
    8. Tap Play -> wait 3s -> screenshot playback
    9. Tap Transcribe -> verify error card (missing key) or transcript card (key set)
   10. Translate flow: type test text if no transcript, tap Translate, verify result or error card
   11. Scan logcat for FATAL/AndroidRuntime crashes; confirm app is still foreground

  Screenshots land in android/app/build/smoke-<timestamp>/ (gitignored).
  Element taps are resolved from a live uiautomator dump by @text or content-desc --
  NOT hardcoded pixels -- so the script survives layout changes.

  KEEP IN SYNC with MainActivity.kt whenever buttons are renamed or screens are added.

  ASCII-only: Windows PowerShell 5.1 reads .ps1 as ANSI; non-ASCII breaks parsing.

.PARAMETER Build     Run assembleDebug first. Otherwise uses the most recent APK.
.PARAMETER AutoMerge After a passing run on a vX.Y.Z branch, merge to main and push both.
                     Called automatically by the post-commit hook when CHANGELOG.md is updated.
.PARAMETER AvdName   Android Virtual Device name. Default: voicebridge_avd.
.PARAMETER JavaHome  Path to JDK 17 home. Default: Eclipse Adoptium 17 at the standard path.
.PARAMETER AndroidHome Path to Android SDK. Default: C:\Android.

.EXAMPLE
  # Build and run the full smoke test
  powershell -File android/scripts/smoke-test.ps1 -Build

  # Use an already-built APK (faster on re-runs)
  powershell -File android/scripts/smoke-test.ps1

  # Full release flow: build + smoke test + auto-merge (called by post-commit hook on CHANGELOG update)
  powershell -File android/scripts/smoke-test.ps1 -Build -AutoMerge
#>
param(
    [switch] $Build,
    [switch] $AutoMerge,
    [string] $AvdName     = "voicebridge_avd",
    [string] $JavaHome    = "C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot",
    [string] $AndroidHome = "C:\Android"
)

# Continue (not Stop): adb writes routine progress to stderr, which must not abort the run.
# Real failures are tracked via Fail() and the final crash/foreground checks.
$ErrorActionPreference = "Continue"
$ProgressPreference    = "SilentlyContinue"

$AppId      = "com.mananpatel.voicebridge"
$Root       = Resolve-Path "$PSScriptRoot\..\.."
$AndroidDir = Join-Path $Root "android"
$Adb        = Join-Path $AndroidHome "platform-tools\adb.exe"
$Emulator   = Join-Path $AndroidHome "emulator\emulator.exe"
$Apk        = Join-Path $AndroidDir "app\build\outputs\apk\debug\app-debug.apk"
$Stamp      = Get-Date -Format "yyyyMMdd-HHmmss"
$OutDir     = Join-Path $AndroidDir "app\build\smoke-$Stamp"
$env:JAVA_HOME    = $JavaHome
$env:ANDROID_HOME = $AndroidHome
$script:Failures = @()
$script:Step = 0

function Log  { param([string]$m, [string]$c = "Cyan")  Write-Host "[smoke] $m" -ForegroundColor $c }
function Fail { param([string]$m) $script:Failures += $m; Log "FAIL: $m" "Red" }

# --- adb / ui helpers ---------------------------------------------------------
function Adb { & $Adb @args 2>$null }

function Get-Ui {
    Adb shell uiautomator dump /sdcard/ui.xml | Out-Null
    $local = Join-Path $OutDir "ui.xml"
    Adb pull /sdcard/ui.xml $local | Out-Null
    $ui = [xml](Get-Content $local -ErrorAction SilentlyContinue)
    # Dismiss transient "app isn't responding" / "keeps stopping" dialog (cold-boot jank).
    if ($ui.SelectSingleNode("//node[contains(@text,'responding') or contains(@text,'keeps stopping')]")) {
        Log "dismissing transient system ANR dialog (cold-boot jank)" "Yellow"
        $wait = $ui.SelectSingleNode("//node[@text='Wait']")
        if ($wait -and $wait.bounds -match '\[(\d+),(\d+)\]\[(\d+),(\d+)\]') {
            Tap-Xy ([int](([int]$Matches[1]+[int]$Matches[3])/2)) ([int](([int]$Matches[2]+[int]$Matches[4])/2))
        } else {
            Adb shell input keyevent 4 | Out-Null
        }
        Start-Sleep -Milliseconds 800
        Adb shell uiautomator dump /sdcard/ui.xml | Out-Null
        Adb pull /sdcard/ui.xml $local | Out-Null
        $ui = [xml](Get-Content $local)
    }
    return $ui
}

function Get-Center([xml]$ui, [string]$predicate) {
    $node = $ui.SelectSingleNode("//node[$predicate]")
    if (-not $node) { return $null }
    if ($node.bounds -notmatch '\[(\d+),(\d+)\]\[(\d+),(\d+)\]') { return $null }
    return @{ x = [int](([int]$Matches[1]+[int]$Matches[3])/2)
              y = [int](([int]$Matches[2]+[int]$Matches[4])/2) }
}

function Tap-Xy([int]$x, [int]$y) { Adb shell input tap $x $y | Out-Null; Start-Sleep -Milliseconds 600 }

function Tap-Element([string]$predicate, [string]$label) {
    $ui = Get-Ui
    $c  = Get-Center $ui $predicate
    if (-not $c) { Fail "could not find UI element: $label ($predicate)"; return $false }
    Tap-Xy $c.x $c.y
    return $true
}

# Assert a node matching $predicate is present in the dump.
function Assert-Node([xml]$ui, [string]$predicate, [string]$label) {
    if (-not ($ui.SelectSingleNode("//node[$predicate]"))) {
        Fail "not found: $label"
    } else {
        Log "found: $label" "Green"
    }
}

# Compose buttons may dump as a clickable parent android.view.View (which carries the REAL
# enabled state) wrapping a non-clickable TextView child that carries the text and always
# reports enabled=true. Resolve the effective button node: self if clickable, else the
# nearest clickable ancestor. (Observed 2026-07-13: text-node enabled was true for visually
# disabled buttons; the clickable parent held the correct state.)
function Get-EffectiveButtonNode([System.Xml.XmlNode]$node) {
    $n = $node
    while ($null -ne $n -and $n.NodeType -eq [System.Xml.XmlNodeType]::Element) {
        if ($n.clickable -eq 'true') { return $n }
        $n = $n.ParentNode
    }
    return $node
}

# Assert that a button with @text=$text has the expected Compose semantics enabled state.
# The state is read from the effective (clickable) node, not the text node — see
# Get-EffectiveButtonNode. KEEP IN SYNC with button labels in MainActivity.kt.
function Assert-Enabled([xml]$ui, [string]$text, [bool]$expected) {
    $node = $ui.SelectSingleNode("//node[@text='$text']")
    if (-not $node) { Fail "button not found: '$text'"; return }
    $actual = [bool]::Parse((Get-EffectiveButtonNode $node).enabled)
    if ($actual -ne $expected) {
        Fail "button '$text': expected enabled=$expected, got enabled=$actual"
    } else {
        Log "button '$text' enabled=$expected (correct)" "Green"
    }
}

function Save-Shot([string]$name) {
    $script:Step++
    $n = "{0:D2}_{1}" -f $script:Step, $name
    Adb shell screencap -p "/sdcard/$n.png" | Out-Null
    Adb pull "/sdcard/$n.png" (Join-Path $OutDir "$n.png") | Out-Null
    Log "screenshot: $n.png"
}

# --- 0. pre-flight checks -----------------------------------------------------
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Log "output dir: $OutDir"
Log ""

# Credential hygiene: local.properties must not be committed
$tracked = git -C $Root ls-files android/local.properties 2>$null
if ($tracked) {
    Fail "android/local.properties is tracked by git -- remove it: git rm --cached android/local.properties"
} else {
    Log "credential hygiene: local.properties is gitignored" "Green"
}

# Structure integrity
$py = Get-Command python  -ErrorAction SilentlyContinue
if ($null -eq $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
if ($null -ne $py) {
    & $py.Source (Join-Path $Root "scripts\verify_structure.py")
    if ($LASTEXITCODE -eq 0) { Log "verify_structure.py passed" "Green" }
    else                     { Fail "verify_structure.py failed (changelog mismatch)" }
} else {
    Log "SKIP verify_structure.py (Python not on PATH)" "Yellow"
}
Log ""

# --- 1. build -----------------------------------------------------------------
if ($Build) {
    Log "Running assembleDebug..."
    & (Join-Path $AndroidDir "gradlew.bat") -p $AndroidDir assembleDebug --console=plain
    if ($LASTEXITCODE -ne 0) { Fail "assembleDebug failed"; exit 1 }
    Log "Build succeeded" "Green"
    Log ""
}
if (-not (Test-Path $Apk)) {
    Write-Host "[smoke] APK not found at $Apk -- run with -Build first." -ForegroundColor Red
    exit 1
}

# --- 2. emulator --------------------------------------------------------------
$booted = (Adb devices | Select-String "emulator-\d+\s+device")
if (-not $booted) {
    Log "Booting AVD $AvdName ..."
    Start-Process -FilePath $Emulator -ArgumentList "-avd",$AvdName,"-no-snapshot-load","-no-boot-anim" -WindowStyle Minimized
}
Adb wait-for-device | Out-Null
$tries = 0
while ((Adb shell getprop sys.boot_completed).Trim() -ne "1" -and $tries -lt 60) {
    Start-Sleep 3
    $tries++
}
Log "Emulator ready" "Green"
Log ""

# --- 3. install + grant permissions + launch ----------------------------------
Log "Installing APK..."
Adb install -r $Apk | Out-Null
# Grant mic permission programmatically so the runtime dialog does not block UI automation.
# This works on debug builds (debuggable=true) on API 23+.
Adb shell pm grant $AppId android.permission.RECORD_AUDIO | Out-Null
Adb logcat -c | Out-Null
Adb shell monkey -p $AppId -c android.intent.category.LAUNCHER 1 | Out-Null
Start-Sleep -Seconds 5
Save-Shot "launch"
Log ""

# --- 4. verify initial screen state -------------------------------------------
Log "Verifying initial screen state..."
$ui = Get-Ui
Assert-Node    $ui "contains(@text,'VoiceBridge')"  "app title"
Assert-Node    $ui "@text='Record'"                  "Record button"
Assert-Node    $ui "@text='Stop'"                    "Stop button"
Assert-Node    $ui "@text='Play'"                    "Play button"
Assert-Node    $ui "contains(@text,'Transcribe')"    "Transcribe (Gujarati) button"
Assert-Node    $ui "contains(@text,'(English)')"     "Translate (English) button"
# Initial state: Record enabled (permission granted), rest disabled (no recording yet).
# KEEP IN SYNC with UiState defaults in MainViewModel.kt.
Assert-Enabled $ui "Record"  $true
Assert-Enabled $ui "Stop"    $false
Assert-Enabled $ui "Play"    $false
# Translate starts disabled (transcript field empty)
$translateNode = $ui.SelectSingleNode("//node[contains(@text,'(English)')]")
if ($null -ne $translateNode) { $translateNode = Get-EffectiveButtonNode $translateNode }
if ($null -eq $translateNode) {
    Fail "Translate (English) button not found in initial state"
} elseif ($translateNode.enabled -eq "true") {
    Fail "Translate (English) should be disabled initially (no transcript); got enabled=true"
} else {
    Log "Translate (English) disabled initially (correct)" "Green"
}
Save-Shot "initial-state"
Log ""

# --- 5. record ----------------------------------------------------------------
Log "Tapping Record (2s recording)..."
[void](Tap-Element "@text='Record'" "Record button")
Start-Sleep -Seconds 1
$ui = Get-Ui
# While recording: Stop=enabled, Record=disabled (per MainViewModel RecordingState.RECORDING).
Assert-Enabled $ui "Stop"   $true
Assert-Enabled $ui "Record" $false
Save-Shot "recording"
Start-Sleep -Seconds 2

# --- 6. stop ------------------------------------------------------------------
Log "Tapping Stop..."
[void](Tap-Element "@text='Stop'" "Stop button")
Start-Sleep -Seconds 1
$ui = Get-Ui
# After stop: Play and Transcribe enabled (hasRecording=true).
Assert-Enabled $ui "Play" $true
# Transcribe button text contains "Gujarati", so match with contains()
$transcribeNode = $ui.SelectSingleNode("//node[contains(@text,'Transcribe')]")
if ($null -ne $transcribeNode) { $transcribeNode = Get-EffectiveButtonNode $transcribeNode }
if ($null -eq $transcribeNode) {
    Fail "Transcribe button not found after stop"
} elseif ($transcribeNode.enabled -ne "true") {
    Fail "Transcribe button should be enabled after recording; got enabled=$($transcribeNode.enabled)"
} else {
    Log "Transcribe button enabled after recording (correct)" "Green"
}
Save-Shot "stopped"
Log ""

# --- 7. playback --------------------------------------------------------------
Log "Tapping Play..."
[void](Tap-Element "@text='Play'" "Play button")
Start-Sleep -Seconds 3
Save-Shot "playback"
Log ""

# --- 8. transcribe: verify error-surfacing without a real API key ------------
# This tests Chunk 1 error handling. If GCP_STT_API_KEY is blank (default in CI),
# the app shows an error card with "GCP_STT_API_KEY" in the text.
# If a real key is configured, a transcript card appears instead.
# EITHER outcome proves the Transcribe flow fires and does not crash.
# KEEP IN SYNC with the error message in MainViewModel.transcribe().
Log "Tapping Transcribe (verifying error card or transcript card)..."
$transcribeBtn = "contains(@text,'Transcribe')"
$tapped = Tap-Element $transcribeBtn "Transcribe button"
if ($tapped) {
    Start-Sleep -Seconds 3
    $ui = Get-Ui
    $errorCard      = $ui.SelectSingleNode("//node[contains(@text,'GCP_STT_API_KEY')]")
    $networkError   = $ui.SelectSingleNode("//node[contains(@text,'Error:') or contains(@text,'error')]")
    $transcriptCard = $ui.SelectSingleNode("//node[contains(@text,'Transcript')]")
    if ($transcriptCard) {
        Log "Transcribe: transcript card returned (API key is set and service responded)" "Green"
    } elseif ($errorCard) {
        Log "Transcribe: error card shown for missing GCP_STT_API_KEY (expected in CI)" "Green"
    } elseif ($networkError) {
        Log "Transcribe: network/auth error surfaced (API key invalid or no network)" "Green"
    } else {
        Fail "Transcribe: neither transcript card nor error card appeared after tapping Transcribe"
    }
    Save-Shot "transcribe-result"
}
Log ""

# --- 9. translate flow --------------------------------------------------------
# Chunk 2: test the Translate (English) button.
# If STT produced a transcript, use it. Otherwise type ASCII test text into the editable
# transcript field so we can drive the button without a real GCP key.
# Either a translation card or an error card proves the flow fires and does not crash.
# KEEP IN SYNC with button label and contentDescription in MainActivity.kt.
Log "Testing Translate flow..."
$ui = Get-Ui
$transcriptField = $ui.SelectSingleNode("//node[@content-desc='transcript-field']")
$hasTranscriptText = ($transcriptField -and $transcriptField.text -and $transcriptField.text.Length -gt 0 -and $transcriptField.text -ne "Transcription appears here, or type directly to test translation")
if (-not $hasTranscriptText) {
    Log "No transcript text from STT -- typing test input into transcript field" "Yellow"
    if ($null -ne $transcriptField -and $transcriptField.bounds -match '\[(\d+),(\d+)\]\[(\d+),(\d+)\]') {
        Tap-Xy ([int](([int]$Matches[1]+[int]$Matches[3])/2)) ([int](([int]$Matches[2]+[int]$Matches[4])/2))
        Start-Sleep -Milliseconds 500
        Adb shell input text "hello" | Out-Null
        Start-Sleep -Milliseconds 500
        Log "Typed 'hello' into transcript field" "Yellow"
    } else {
        Log "SKIP translate step: transcript field not found (contentDescription mismatch?)" "Yellow"
    }
}
$transBtn = Tap-Element "contains(@text,'(English)')" "Translate (English) button"
if ($transBtn) {
    Start-Sleep -Seconds 3
    $ui = Get-Ui
    $translationCard  = $ui.SelectSingleNode("//node[contains(@text,'Translation (English)')]")
    $translationError = $ui.SelectSingleNode("//node[contains(@text,'GCP_STT_API_KEY') or contains(@text,'Translation API error') or contains(@text,'Translation failed')]")
    $genericError     = $ui.SelectSingleNode("//node[contains(@text,'Error:')]")
    if ($translationCard) {
        Log "Translate: translation card returned (API key is set and service responded)" "Green"
    } elseif ($translationError -or $genericError) {
        Log "Translate: error card shown (missing/invalid key in CI -- expected)" "Green"
    } else {
        Fail "Translate: neither translation card nor error card appeared after tapping Translate (English)"
    }
    Save-Shot "translate-result"
}
Log ""

# --- 10. crash check ----------------------------------------------------------
Log "Scanning logcat for crashes..."
$crashes = Adb logcat -d | Select-String -Pattern "FATAL EXCEPTION|E AndroidRuntime"
if ($crashes) {
    Fail ("logcat shows crash(es):`n" + ($crashes -join "`n"))
} else {
    Log "No crashes in logcat" "Green"
}
$top = Adb shell dumpsys activity activities | Select-String "topResumedActivity"
if ($top -notmatch [regex]::Escape($AppId)) {
    Fail "app is not the foreground activity after the test run"
} else {
    Log "App is still foreground" "Green"
}

# --- summary ------------------------------------------------------------------
Write-Host ""
if ($script:Failures.Count -eq 0) {
    Log "==========================================" "Green"
    Log "  SMOKE TEST PASSED" "Green"
    Log "  Screenshots: $OutDir" "Green"
    Log "==========================================" "Green"
} else {
    Log "==========================================" "Red"
    Log "  SMOKE TEST FAILED ($($script:Failures.Count) issue(s)):" "Red"
    $script:Failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Log "  Screenshots (for diagnosis): $OutDir" "Yellow"
    Log "==========================================" "Red"
    exit 1
}

# --- auto-merge ---------------------------------------------------------------
if (-not $AutoMerge) { exit 0 }

$branch = git -C $Root rev-parse --abbrev-ref HEAD 2>$null
if ($branch -notmatch '^v\d+\.\d+\.\d+$') {
    Log "SKIP auto-merge: -AutoMerge only fires on version branches (v*.*.*). Current branch: $branch" "Yellow"
    exit 0
}

Write-Host ""
Log "Auto-merging $branch -> main ..." "Cyan"

git -C $Root checkout main
if ($LASTEXITCODE -ne 0) { Log "FAIL: git checkout main" "Red"; exit 1 }

git -C $Root merge --no-ff $branch -m "Merge $branch into main"
if ($LASTEXITCODE -ne 0) {
    Log "FAIL: git merge (conflict?)" "Red"
    git -C $Root checkout $branch   # return to feature branch so user can fix
    exit 1
}

git -C $Root push origin main
if ($LASTEXITCODE -ne 0) { Log "FAIL: git push main" "Red"; exit 1 }

git -C $Root push origin $branch
if ($LASTEXITCODE -ne 0) { Log "FAIL: git push $branch" "Red"; exit 1 }

Log "Merged and pushed: $branch -> main. Both branches on origin." "Green"
Log "Next: git checkout -b v<next-version>" "Cyan"
exit 0
