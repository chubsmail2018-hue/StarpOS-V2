# ===========================================================================
#  appopener.ps1  -  app opener
#  18
#
#  Built by mkapp.ps1. Launched from the starpOS desktop as slot 18.
#  Everything you want to change is between the CHANGE ME markers.
# ===========================================================================

[CmdletBinding()]
param([switch]$NoPause)

$ErrorActionPreference = "Continue"
$here = Split-Path -Parent $MyInvocation.MyCommand.Definition
$root = Split-Path -Parent $here

# Write a line into the starpOS kernel log, same as the other apps do.
function Write-StarpLog {
    param([string]$Message)
    $log = Join-Path $root "data\1.log"
    try {
        Add-Content -LiteralPath $log -Value ("[" + (Get-Date -Format "HH:mm:ss.ff") + "] [APPOPENER] " + $Message) -Encoding ASCII -ErrorAction Stop
    } catch { }
}

function Draw {
    try {
        $host.UI.RawUI.WindowTitle = "starpOS - app opener"
        Clear-Host
    } catch { }
    Write-Host "==============================================================================="
    Write-Host "  app opener"
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

Write-StarpLog "app opener started"
Draw

# An empty answer counter, so the app cannot spin if input is ever closed.
$emptyRuns = 0

while ($true) {

    Write-Host -NoNewline "  appopener> "
    $pick = ""
    try { $pick = [string](Read-Host) } catch { break }
    $pick = $pick.Trim()

    if ($pick -eq "") {
        $emptyRuns++
        if ($emptyRuns -ge 30) { break }
        continue
    }
    $emptyRuns = 0

    # ----------------------------- CHANGE ME -------------------------------
    if ($pick -eq "0") { break }

    if ($pick -eq "1") {
        Write-Host ""
        Write-Host "  Hello from app opener." -ForegroundColor Green
        Write-StarpLog "said hello"
        Write-Host ""
        continue
    }

    if ($pick -eq "2") {
        Write-Host ""
        Write-Host ("  It is " + (Get-Date -Format "HH:mm:ss") + " on " + (Get-Date -Format "dddd d MMMM yyyy")) -ForegroundColor Cyan
        Write-Host ""
        continue
    }
    # --------------------------- END CHANGE ME -----------------------------

    Write-Host "  Not an option." -ForegroundColor Yellow
    Write-Host ""
}

Write-StarpLog "app opener closed"
Write-Host ""
Write-Host "  Closing app opener."
if (-not $NoPause) {
    Write-Host ""
    Write-Host "Press any key to return to starpOS . . ."
    try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
}