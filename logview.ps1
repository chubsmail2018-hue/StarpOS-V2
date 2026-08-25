# ===========================================================================
#  logview.ps1  -  starpOS log viewer
# ===========================================================================
#  starpOS writes three log streams and until now the only way to read them
#  was to open Notepad outside the OS. This reads them from inside, colours
#  each line by its tag, and can filter.
#
#     powershell -NoProfile -ExecutionPolicy Bypass -File "logview.ps1"
#
#  Switches:
#     -Stream 1|2|3|all   which stream to read (default all)
#     -Tail 40            how many recent lines to show (default 40, 0 = all)
#     -Filter "AUTH"      only lines containing this text
#     -Clear              wipe the streams and start fresh (asks first)
#
#  Stream 1 is the kernel, 2 is the system, 3 is user activity.
# ===========================================================================

[CmdletBinding()]
param(
    [string]$Config = "starpos.cfg",
    [string]$Stream = "all",
    [int]$Tail      = 40,
    [string]$Filter = "",
    [switch]$Clear,
    [switch]$NoPause
)

$ErrorActionPreference = "Continue"
$here = Split-Path -Parent $MyInvocation.MyCommand.Definition

function Resolve-Local {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path $here $Path)
}

# --- Find the streams via starpos.cfg, with the usual defaults as backup ----
$paths = @{
    "1" = "..\data\1.log"
    "2" = "..\data\2.log"
    "3" = "..\data\3.log"
}
$cfgPath = Resolve-Local $Config
if (Test-Path -LiteralPath $cfgPath) {
    foreach ($line in (Get-Content -LiteralPath $cfgPath)) {
        $t = $line.Trim()
        if ($t -eq "" -or $t.StartsWith("#")) { continue }
        $i = $t.IndexOf("=")
        if ($i -lt 1) { continue }
        $k = $t.Substring(0, $i).Trim()
        $v = $t.Substring($i + 1).Trim()
        if ($k -eq "LOG_KERNEL") { $paths["1"] = $v }
        if ($k -eq "LOG_SYSTEM") { $paths["2"] = $v }
        if ($k -eq "LOG_USER")   { $paths["3"] = $v }
    }
}

$names = @{ "1" = "KERNEL"; "2" = "SYSTEM"; "3" = "USER" }

$wanted = @()
if ($Stream -eq "all") { $wanted = @("1", "2", "3") }
elseif ($paths.ContainsKey($Stream)) { $wanted = @($Stream) }
else {
    Write-Host "  [ STARP-0202 ] Unknown stream '$Stream'. Use 1, 2, 3 or all."
    return
}

# --- Clear mode -------------------------------------------------------------
if ($Clear) {
    Write-Host ""
    Write-Host "  This wipes the log streams. Everything recorded so far is gone."
    $answer = Read-Host "  Type YES to confirm"
    if ($answer -ne "YES") {
        Write-Host "  Cancelled. Nothing was changed."
        return
    }
    foreach ($key in $wanted) {
        $p = Resolve-Local $paths[$key]
        try {
            Set-Content -LiteralPath $p -Value ("=== starpOS " + $names[$key] + " LOG - cleared " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + " ===") -Encoding ASCII -ErrorAction Stop
            Write-Host ("  Stream " + $key + " (" + $names[$key] + ") cleared.")
        } catch {
            Write-Host ("  [ STARP-0202 ] Could not clear stream " + $key + ": " + $p)
        }
    }
    Write-Host ""
    return
}

# --- Colour a line by the tag inside it -------------------------------------
function Get-LineColour {
    param([string]$Text)
    if ($Text -match "SECURITY|ERROR|FAIL|WARNING|STARP-") { return "Red" }
    if ($Text -match "\[AUTH\]|\[PWR\]|\[USER_MGMT\]")     { return "Yellow" }
    if ($Text -match "\[LAUNCH\]|\[ACT\]|\[VOICE_CMD\]")   { return "Cyan" }
    if ($Text -match "\[INP\]|\[DATA\]")                   { return "Green" }
    if ($Text -match "^===|^---")                          { return "DarkGray" }
    return "Gray"
}

# --- Read and print ---------------------------------------------------------
try { Clear-Host } catch { }
Write-Host "==============================================================================="
Write-Host "                          starpOS LOG VIEWER"
Write-Host "==============================================================================="

foreach ($key in $wanted) {

    $path = Resolve-Local $paths[$key]
    Write-Host ""
    Write-Host ("--- STREAM " + $key + "  (" + $names[$key] + ")  " + $paths[$key] + " ---") -ForegroundColor White

    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host "  [ STARP-0201 ] This stream does not exist yet. Boot starpOS once to create it." -ForegroundColor Red
        continue
    }

    $lines = @()
    try {
        $lines = @(Get-Content -LiteralPath $path -ErrorAction Stop)
    } catch {
        Write-Host "  [ STARP-0202 ] Stream unreadable. Another program may have it open." -ForegroundColor Red
        continue
    }

    if ($Filter -ne "") {
        $lines = @($lines | Where-Object { $_ -match [regex]::Escape($Filter) })
    }

    if ($lines.Count -eq 0) {
        if ($Filter -ne "") {
            Write-Host ("  Nothing in this stream matches '" + $Filter + "'.") -ForegroundColor DarkGray
        } else {
            Write-Host "  This stream is empty." -ForegroundColor DarkGray
        }
        continue
    }

    $shown = $lines
    if ($Tail -gt 0 -and $lines.Count -gt $Tail) {
        $shown = $lines[($lines.Count - $Tail)..($lines.Count - 1)]
        Write-Host ("  ... " + ($lines.Count - $Tail) + " earlier lines hidden, showing the last " + $Tail + " ...") -ForegroundColor DarkGray
    }

    foreach ($line in $shown) {
        Write-Host ("  " + $line) -ForegroundColor (Get-LineColour $line)
    }

    Write-Host ("  [ " + $lines.Count + " lines total ]") -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "==============================================================================="

if (-not $NoPause) {
    Write-Host ""
    Write-Host "Press any key to return to starpOS . . ."
    try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
}
