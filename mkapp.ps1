# ===========================================================================
#  mkapp.ps1  -  starpOS app builder   (developer mode)
# ===========================================================================
#  Writes a new, working starpOS app from a template and puts it on the
#  desktop for you. The app it makes is not a stub: it runs, it has a menu,
#  it logs, and it returns to the desktop properly. Open it afterwards and
#  change the bits between the markers.
#
#     powershell -NoProfile -ExecutionPolicy Bypass -File "mkapp.ps1"
#
#  ABOUT .bat APPS: bootcore.bat runs every .bat in the system folder at
#  boot. A new app would therefore also fire during startup, before the
#  desktop even appears. Every .bat this tool writes starts with a guard
#  that returns immediately unless the desktop launched it on purpose.
#  PowerShell apps are not scanned at boot, so they need no guard.
# ===========================================================================

[CmdletBinding()]
param([switch]$NoPause)

$ErrorActionPreference = "Continue"
$here = Split-Path -Parent $MyInvocation.MyCommand.Definition
$menuPath = Join-Path $here "menu.cfg"
$appsPath = Join-Path $here "apps.reg"

function Ask {
    param([string]$Prompt, [string]$Default = "")
    if ($Default -ne "") {
        Write-Host -NoNewline ("  " + $Prompt + " [" + $Default + "]> ")
    } else {
        Write-Host -NoNewline ("  " + $Prompt + "> ")
    }
    $a = ""
    try { $a = [string](Read-Host) } catch { return $null }
    $a = $a.Trim()
    if ($a -eq "") { return $Default }
    return $a
}

function Get-FreeSlot {
    $used = @{}
    if (Test-Path -LiteralPath $menuPath) {
        foreach ($line in (Get-Content -LiteralPath $menuPath)) {
            $t = $line.Trim()
            if ($t -eq "" -or $t.StartsWith("#")) { continue }
            $p = $t.Split("|")
            if ($p.Count -ge 1) { $used[$p[0].Trim().ToLower()] = $true }
        }
    }
    for ($i = 1; $i -le 99; $i++) {
        if (-not $used.ContainsKey([string]$i)) { return [string]$i }
    }
    return $null
}

try { Clear-Host } catch { }
Write-Host "==============================================================================="
Write-Host "                        starpOS APP BUILDER"
Write-Host "==============================================================================="
Write-Host ""
Write-Host "  Builds a new app, writes it into the system folder, and adds it to the"
Write-Host "  desktop menu. Press Enter on its own at the name to cancel."
Write-Host ""

# --- Name -------------------------------------------------------------------
$label = Ask "What is the app called"
if ($null -eq $label -or $label -eq "") {
    Write-Host ""
    Write-Host "  Cancelled, nothing was made." -ForegroundColor Gray
    if (-not $NoPause) { Write-Host ""; Write-Host "Press any key . . ."; try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { } }
    return
}

# A file name has to survive being typed into a batch redirect later on.
$fileBase = ($label -replace '[^A-Za-z0-9_\-]', '')
if ($fileBase -eq "") {
    Write-Host ""
    Write-Host "  That name has no letters or numbers in it, so it cannot become a file name." -ForegroundColor Red
    if (-not $NoPause) { Write-Host ""; Write-Host "Press any key . . ."; try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { } }
    return
}
$fileBase = $fileBase.ToLower()

# --- Kind -------------------------------------------------------------------
Write-Host ""
Write-Host "  What kind of app?"
Write-Host "    1. PowerShell  (.ps1)  - recommended, more it can do, not run at boot"
Write-Host "    2. Batch       (.bat)  - matches the older starpOS apps"
Write-Host ""
$kind = Ask "Pick 1 or 2" "1"
if ($null -eq $kind) { return }

$ext = ".ps1"
$type = "ps1"
if ($kind -eq "2") { $ext = ".bat"; $type = "bat" }

$fileName = $fileBase + $ext
$filePath = Join-Path $here $fileName

if (Test-Path -LiteralPath $filePath) {
    Write-Host ""
    Write-Host ("  " + $fileName + " already exists. Pick a different name, or delete that file first.") -ForegroundColor Red
    if (-not $NoPause) { Write-Host ""; Write-Host "Press any key . . ."; try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { } }
    return
}

# --- Slot -------------------------------------------------------------------
$suggested = Get-FreeSlot
Write-Host ""
$slot = Ask "Which key should open it on the desktop" $suggested
if ($null -eq $slot -or $slot -eq "") { $slot = $suggested }

$clash = $false
if (Test-Path -LiteralPath $menuPath) {
    foreach ($line in (Get-Content -LiteralPath $menuPath)) {
        $t = $line.Trim()
        if ($t -eq "" -or $t.StartsWith("#")) { continue }
        $p = $t.Split("|")
        if ($p.Count -ge 1 -and $p[0].Trim().ToLower() -eq $slot.ToLower()) { $clash = $true }
    }
}
if ($clash) {
    Write-Host ""
    Write-Host ("  Slot '" + $slot + "' is already taken. Using " + $suggested + " instead.") -ForegroundColor Yellow
    $slot = $suggested
}

$desc = Ask "One line describing it" ("Built by the app builder on " + (Get-Date -Format "yyyy-MM-dd"))
if ($null -eq $desc) { $desc = "" }
$desc = $desc -replace '\|', '-'
$labelSafe = $label -replace '\|', '-'

# ---------------------------------------------------------------------------
#  Templates
# ---------------------------------------------------------------------------
$nl = "`r`n"

if ($type -eq "ps1") {

$body = @"
# ===========================================================================
#  $fileName  -  $labelSafe
#  $desc
#
#  Built by mkapp.ps1. Launched from the starpOS desktop as slot $slot.
#  Everything you want to change is between the CHANGE ME markers.
# ===========================================================================

[CmdletBinding()]
param([switch]`$NoPause)

`$ErrorActionPreference = "Continue"
`$here = Split-Path -Parent `$MyInvocation.MyCommand.Definition
`$root = Split-Path -Parent `$here

# Write a line into the starpOS kernel log, same as the other apps do.
function Write-StarpLog {
    param([string]`$Message)
    `$log = Join-Path `$root "data\1.log"
    try {
        Add-Content -LiteralPath `$log -Value ("[" + (Get-Date -Format "HH:mm:ss.ff") + "] [$($fileBase.ToUpper())] " + `$Message) -Encoding ASCII -ErrorAction Stop
    } catch { }
}

function Draw {
    try {
        `$host.UI.RawUI.WindowTitle = "starpOS - $labelSafe"
        Clear-Host
    } catch { }
    Write-Host "==============================================================================="
    Write-Host "  $labelSafe"
    Write-Host "==============================================================================="
    Write-Host ""

    # ----------------------------- CHANGE ME -------------------------------
    Write-Host "  1. Say hello"
    Write-Host "  2. Show the time"
    Write-Host "  0. Back to the starpOS desktop"
    # --------------------------- END CHANGE ME -----------------------------

    Write-Host ""
    Write-Host "==============================================================================="
    Write-Host ""
}

Write-StarpLog "$labelSafe started"
Draw

# An empty answer counter, so the app cannot spin if input is ever closed.
`$emptyRuns = 0

while (`$true) {

    Write-Host -NoNewline "  $fileBase> "
    `$pick = ""
    try { `$pick = [string](Read-Host) } catch { break }
    `$pick = `$pick.Trim()

    if (`$pick -eq "") {
        `$emptyRuns++
        if (`$emptyRuns -ge 30) { break }
        continue
    }
    `$emptyRuns = 0

    # ----------------------------- CHANGE ME -------------------------------
    if (`$pick -eq "0") { break }

    if (`$pick -eq "1") {
        Write-Host ""
        Write-Host "  Hello from $labelSafe." -ForegroundColor Green
        Write-StarpLog "said hello"
        Write-Host ""
        continue
    }

    if (`$pick -eq "2") {
        Write-Host ""
        Write-Host ("  It is " + (Get-Date -Format "HH:mm:ss") + " on " + (Get-Date -Format "dddd d MMMM yyyy")) -ForegroundColor Cyan
        Write-Host ""
        continue
    }
    # --------------------------- END CHANGE ME -----------------------------

    Write-Host "  Not an option." -ForegroundColor Yellow
    Write-Host ""
}

Write-StarpLog "$labelSafe closed"
Write-Host ""
Write-Host "  Closing $labelSafe."
if (-not `$NoPause) {
    Write-Host ""
    Write-Host "Press any key to return to starpOS . . ."
    try { `$null = `$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
}
"@

} else {

$body = @"
@echo off
setlocal enabledelayedexpansion

:: ===========================================================================
::  $fileName  -  $labelSafe
::  $desc
::
::  Built by mkapp.ps1. Launched from the starpOS desktop as slot $slot.
::  Everything you want to change is between the CHANGE ME markers.
:: ===========================================================================

:: bootcore.bat runs every .bat in this folder when starpOS boots. Without
:: this line, this app would also open during startup. The desktop sets
:: STARPOS_LAUNCH before it calls an app, so this only runs on purpose.
if not "%STARPOS_LAUNCH%"=="1" goto :eof

:: Log targets handed over by the desktop.
set "_s1=%~1"
set "_s3=%~3"
if not defined _s1 set "_s1=..\data\1.log"

set "BLANKS=0"

:app_menu
cls
title starpOS - $labelSafe
echo ===============================================================================
echo  $labelSafe
echo ===============================================================================
echo.

:: ------------------------------- CHANGE ME ---------------------------------
echo    1. Say hello
echo    2. Show the time
echo    0. Back to the starpOS desktop
:: ----------------------------- END CHANGE ME -------------------------------

echo.
echo ===============================================================================
echo.
set "pick="
set /p pick="$fileBase> "
if not defined pick goto app_blank
set "BLANKS=0"

call :log "[APP] $labelSafe selection: !pick!"

:: ------------------------------- CHANGE ME ---------------------------------
if "!pick!"=="0" goto app_done
if "!pick!"=="1" goto say_hello
if "!pick!"=="2" goto show_time
:: ----------------------------- END CHANGE ME -------------------------------

echo.
echo  Not an option.
timeout /t 2 >nul
goto app_menu

:: ------------------------------- CHANGE ME ---------------------------------
:say_hello
echo.
echo  Hello from $labelSafe.
echo.
pause
goto app_menu

:show_time
echo.
echo  It is %TIME:~0,8% on %DATE%
echo.
pause
goto app_menu
:: ----------------------------- END CHANGE ME -------------------------------

:app_blank
set /a BLANKS+=1
if !BLANKS! LSS 30 goto app_menu

:app_done
call :log "[APP] $labelSafe closed"
:: exit /b hands control back to the desktop. A bare "exit" would close the
:: whole starpOS window instead, which is a very easy mistake to make.
endlocal
exit /b

:log
if defined _s1 >>"%_s1%" echo [%TIME%] %~1
if defined _s3 >>"%_s3%" echo [%TIME%] %~1
goto :eof
"@

}

# ---------------------------------------------------------------------------
#  Write it out
# ---------------------------------------------------------------------------
Write-Host ""
try {
    # Batch in particular must be CRLF or goto and call stop finding labels.
    $text = $body -replace "`r`n", "`n"
    $text = $text -replace "`n", $nl
    [System.IO.File]::WriteAllText($filePath, $text, [System.Text.Encoding]::ASCII)
    Write-Host ("  [ OK ] wrote " + $fileName) -ForegroundColor Green
} catch {
    Write-Host ("  [ ERROR ] could not write " + $fileName + ": " + $_.Exception.Message) -ForegroundColor Red
    if (-not $NoPause) { Write-Host ""; Write-Host "Press any key . . ."; try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { } }
    return
}

# --- Put it on the desktop --------------------------------------------------
try {
    Add-Content -LiteralPath $menuPath -Value ($slot + "|" + $labelSafe + "|" + $type + "|" + $fileName) -Encoding ASCII -ErrorAction Stop
    Write-Host ("  [ OK ] added to menu.cfg as slot " + $slot) -ForegroundColor Green
} catch {
    Write-Host "  [ WARN ] could not add it to menu.cfg, add the line yourself:" -ForegroundColor Yellow
    Write-Host ("         " + $slot + "|" + $labelSafe + "|" + $type + "|" + $fileName)
}

try {
    Add-Content -LiteralPath $appsPath -Value ($slot + "|" + $labelSafe + "|" + $fileName + "|app|" + $desc) -Encoding ASCII -ErrorAction Stop
    Write-Host "  [ OK ] listed in apps.reg" -ForegroundColor Green
} catch {
    Write-Host "  [ WARN ] could not update apps.reg" -ForegroundColor Yellow
}

try {
    $log = Join-Path (Split-Path -Parent $here) "data\1.log"
    Add-Content -LiteralPath $log -Value ("[" + (Get-Date -Format "HH:mm:ss.ff") + "] [DEV_MKAPP] Created " + $fileName + " on slot " + $slot) -Encoding ASCII -ErrorAction Stop
} catch { }

Write-Host ""
Write-Host "==============================================================================="
Write-Host ("  " + $labelSafe + " is ready.") -ForegroundColor Green
Write-Host ""
Write-Host ("  File     : system\" + $fileName)
Write-Host ("  Desktop  : press " + $slot + " on the starpOS desktop")
Write-Host ""
Write-Host "  The desktop re-reads menu.cfg every time it draws, so it is there now."
Write-Host "  Open the file and edit between the CHANGE ME markers to make it yours."
Write-Host "==============================================================================="

if (-not $NoPause) {
    Write-Host ""
    Write-Host "Press any key to return to starpOS . . ."
    try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
}
