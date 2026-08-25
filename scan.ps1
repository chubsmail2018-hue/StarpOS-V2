# ===========================================================================
#  scan.ps1  -  starpOS advanced system scan   (developer mode)
# ===========================================================================
#  A deep, READ-ONLY look at the whole of starpOS. It changes nothing at all.
#  When it finds something wrong it prints a STARP code, and repair.ps1 is
#  the tool that actually fixes them.
#
#     powershell -NoProfile -ExecutionPolicy Bypass -File "scan.ps1"
#
#  Switches:
#     -Quick     skip the batch label analysis, which is the slow part
#     -Log "..\data\1.log"   write the findings into a log stream
#
#  THE CHECK THAT MATTERS MOST is the batch label one. A "goto" aimed at a
#  label that does not exist kills a batch script on the spot, with the
#  window vanishing and no error left on screen. That is what used to happen
#  to the old startup.bat, and this finds it in every .bat at once.
# ===========================================================================

[CmdletBinding()]
param(
    [string]$Log = "",
    [switch]$Quick,
    [switch]$NoPause
)

$ErrorActionPreference = "Continue"
$here = Split-Path -Parent $MyInvocation.MyCommand.Definition
$root = Split-Path -Parent $here

function Resolve-Local {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path $here $Path)
}
if ($Log -ne "") { $Log = Resolve-Local $Log }

$report   = New-Object System.Collections.Generic.List[string]
$problems = New-Object System.Collections.Generic.List[string]

function Say-Line {
    param([string]$Text = "", [string]$Colour = "Gray")
    $report.Add($Text) | Out-Null
    Write-Host $Text -ForegroundColor $Colour
}
function Say-Head {
    param([string]$Text)
    Say-Line ""
    Say-Line ("--- " + $Text + " " + ("-" * [math]::Max(0, 74 - $Text.Length))) "White"
}
function Say-Ok   { param([string]$T) Say-Line ("   [ OK ]   " + $T) "Green" }
function Say-Info { param([string]$T) Say-Line ("   [ .. ]   " + $T) "Gray" }
function Say-Bad {
    param([string]$Code, [string]$T)
    Say-Line ("   [ " + $Code + " ] " + $T) "Red"
    $problems.Add($Code + "  " + $T) | Out-Null
}
function Say-Warn {
    param([string]$T)
    Say-Line ("   [ WARN ] " + $T) "Yellow"
    $problems.Add("WARN      " + $T) | Out-Null
}

try { Clear-Host } catch { }
Say-Line "==============================================================================="
Say-Line "                     starpOS ADVANCED SYSTEM SCAN"
Say-Line "==============================================================================="
Say-Line ("  Started " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
Say-Line ("  System folder: " + $here)

# ---------------------------------------------------------------------------
#  1. Folder layout
# ---------------------------------------------------------------------------
Say-Head "FOLDERS"
$expected = @("data", "debug", "builds", "resources")
foreach ($name in $expected) {
    $p = Join-Path $root $name
    if (Test-Path -LiteralPath $p) {
        $n = @(Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue).Count
        Say-Ok ("$name  ($n items)")
    } else {
        Say-Bad "STARP-0201" "$name folder is missing"
    }
}

# A folder whose name has stray characters on the end will never be found by
# the ..\name paths in the batch files, which then quietly make a second one.
foreach ($d in (Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue)) {
    if ($d.Name -match '[^\x20-\x7E]' -or $d.Name -ne $d.Name.Trim()) {
        $codes = (([int[]][char[]]$d.Name) -join ",")
        Say-Bad "STARP-0206" ("folder name has stray characters: '" + $d.Name + "'  char codes " + $codes)
    }
}

# ---------------------------------------------------------------------------
#  2. Core system files
# ---------------------------------------------------------------------------
Say-Head "CORE FILES"
$core = @("boot.bat", "bootcore.bat", "startup.bat", "starpos.cfg", "menu.cfg",
          "logo.txt", "help.txt", "errors.txt", "version.txt", "users.db",
          "apps.reg", "voicebank.txt", "voice.cmds", "speak.vbs")
$missingCore = 0
foreach ($f in $core) {
    if (-not (Test-Path -LiteralPath (Join-Path $here $f))) {
        Say-Bad "STARP-0402" "$f is missing from the system folder"
        $missingCore++
    }
}
if ($missingCore -eq 0) { Say-Ok "all $($core.Count) core files present" }

# ---------------------------------------------------------------------------
#  3. Batch health: line endings and label integrity
# ---------------------------------------------------------------------------
Say-Head "BATCH FILES"
$bats = @(Get-ChildItem -LiteralPath $here -Filter "*.bat" -File -ErrorAction SilentlyContinue)
Say-Info ("$($bats.Count) batch files in the system folder")

foreach ($bat in $bats) {

    $raw = ""
    try { $raw = [System.IO.File]::ReadAllText($bat.FullName) } catch { continue }

    # A .bat saved with Unix line endings breaks goto and call label lookup.
    $crlf = ([regex]::Matches($raw, "`r`n")).Count
    $lf   = ([regex]::Matches($raw, "`n")).Count
    if ($lf -gt 0 -and $crlf -lt $lf) {
        Say-Bad "STARP-0106" ($bat.Name + " has Unix line endings. goto and call will misbehave.")
    }

    if ($Quick) { continue }

    $lines = $raw -split "`r?`n"

    # Collect the labels this file defines.
    $labels = @{}
    foreach ($line in $lines) {
        if ($line -match '^\s*:([A-Za-z0-9_\-\.]+)') {
            $labels[$matches[1].ToLower()] = $true
        }
    }

    # Every goto / call :label target must be one of them.
    $dynamic = 0
    $lineNo  = 0
    foreach ($line in $lines) {
        $lineNo++
        $stripped = $line
        # ":: comment" lines are labels themselves and never execute.
        if ($stripped -match '^\s*::') { continue }

        foreach ($m in [regex]::Matches($stripped, '(?i)\bgoto\s+:?([^\s&|>()]+)')) {
            $t = $m.Groups[1].Value
            if ($t -match '[%!]') { $dynamic++; continue }
            if ($t.ToLower() -eq "eof") { continue }
            if (-not $labels.ContainsKey($t.ToLower())) {
                Say-Bad "STARP-0104" ($bat.Name + " line " + $lineNo + ": goto " + $t + " but there is no :" + $t + " label. This kills the script.")
            }
        }
        foreach ($m in [regex]::Matches($stripped, '(?i)\bcall\s+:([^\s&|>()]+)')) {
            $t = $m.Groups[1].Value
            if ($t -match '[%!]') { $dynamic++; continue }
            if ($t.ToLower() -eq "eof") { continue }
            if (-not $labels.ContainsKey($t.ToLower())) {
                Say-Bad "STARP-0104" ($bat.Name + " line " + $lineNo + ": call :" + $t + " but there is no :" + $t + " routine.")
            }
        }
    }
    if ($dynamic -gt 0) {
        Say-Info ($bat.Name + ": " + $dynamic + " jumps built from a variable, cannot be checked here")
    }

    # A set /p loop with no escape spins forever if input is ever unreadable.
    if ($raw -match '(?i)set\s*/p' -and $raw -notmatch '(?i)BLANKS') {
        Say-Warn ($bat.Name + " prompts with set /p but has no empty-answer guard. If input is ever redirected it will loop forever.")
    }
}

# ---------------------------------------------------------------------------
#  4. menu.cfg integrity
# ---------------------------------------------------------------------------
Say-Head "DESKTOP MENU"
$menuPath = Join-Path $here "menu.cfg"
if (-not (Test-Path -LiteralPath $menuPath)) {
    Say-Bad "STARP-0402" "menu.cfg is missing, the desktop will fall back to its emergency menu"
} else {
    $startupText = ""
    $sp = Join-Path $here "startup.bat"
    if (Test-Path -LiteralPath $sp) { $startupText = [System.IO.File]::ReadAllText($sp) }

    $slots = @{}
    $count = 0
    foreach ($line in (Get-Content -LiteralPath $menuPath)) {
        $t = $line.Trim()
        if ($t -eq "" -or $t.StartsWith("#")) { continue }
        $p = $t.Split("|")
        if ($p.Count -lt 4) {
            Say-Bad "STARP-0402" ("menu.cfg line needs at least 4 columns: " + $t)
            continue
        }
        $count++
        $slot = $p[0].Trim()
        $label = $p[1].Trim()
        $type = $p[2].Trim().ToLower()
        $target = $p[3].Trim()

        if ($slots.ContainsKey($slot.ToLower())) {
            Say-Bad "STARP-0405" ("slot '" + $slot + "' is used twice. The later one wins and the first is unreachable.")
        }
        $slots[$slot.ToLower()] = $true

        switch ($type) {
            "builtin" {
                if ($startupText -notmatch ("(?im)^\s*:" + [regex]::Escape($target) + "\s*$")) {
                    Say-Bad "STARP-0402" ($label + " points at builtin '" + $target + "' but startup.bat has no :" + $target + " routine")
                }
            }
            "cmd" { }
            default {
                if (-not (Test-Path -LiteralPath (Join-Path $here $target))) {
                    Say-Bad "STARP-0401" ($label + " points at '" + $target + "' which is not there")
                }
            }
        }
    }
    Say-Ok ("$count menu entries checked")
}

# ---------------------------------------------------------------------------
#  5. starpos.cfg sanity
# ---------------------------------------------------------------------------
Say-Head "CONFIGURATION"
$cfgPath = Join-Path $here "starpos.cfg"
if (Test-Path -LiteralPath $cfgPath) {
    $seen = @{}
    $n = 0
    foreach ($line in (Get-Content -LiteralPath $cfgPath)) {
        $t = $line.Trim()
        if ($t -eq "" -or $t.StartsWith("#")) { continue }
        if ($t -notmatch "=") {
            Say-Bad "STARP-0202" ("config line has no = in it: " + $t)
            continue
        }
        $n++
        $k = $t.Substring(0, $t.IndexOf("="))
        $v = $t.Substring($t.IndexOf("=") + 1)
        if ($k -ne $k.Trim()) {
            Say-Bad "STARP-0207" ("'" + $k + "' has a space before the =, so the variable name will have a space in it")
        }
        if ($v.StartsWith('"') -or $v.EndsWith('"')) {
            Say-Warn ("$($k.Trim()) has quotes around its value. The batch loader adds its own.")
        }
        if ($seen.ContainsKey($k.Trim())) {
            Say-Bad "STARP-0208" ($k.Trim() + " appears more than once. The last one silently wins.")
        }
        $seen[$k.Trim()] = $true
    }
    Say-Ok "$n settings checked"
} else {
    Say-Bad "STARP-0202" "starpos.cfg is missing, everything falls back to built-in defaults"
}

# ---------------------------------------------------------------------------
#  6. Resources folder rule
# ---------------------------------------------------------------------------
Say-Head "RESOURCES RULE"
$res = Join-Path $root "resources"
if (Test-Path -LiteralPath $res) {
    $bad = @(Get-ChildItem -LiteralPath $res -Include "*.bat", "*.cmd", "*.exe" -Recurse -File -ErrorAction SilentlyContinue)
    if ($bad.Count -gt 0) {
        foreach ($b in $bad) { Say-Bad "STARP-0205" ("executable in resources: " + $b.Name) }
    } else {
        Say-Ok "no executables in the resources folder"
    }
}

# ---------------------------------------------------------------------------
#  7. Logs
# ---------------------------------------------------------------------------
Say-Head "LOG STREAMS"
foreach ($pair in @(@("1", "KERNEL"), @("2", "SYSTEM"), @("3", "USER"))) {
    $p = Join-Path $root ("data\" + $pair[0] + ".log")
    if (Test-Path -LiteralPath $p) {
        $item = Get-Item -LiteralPath $p
        $lc = @(Get-Content -LiteralPath $p -ErrorAction SilentlyContinue).Count
        Say-Ok ("stream " + $pair[0] + " (" + $pair[1] + ")  " + $lc + " lines, " + [math]::Round($item.Length / 1KB, 1) + " KB")
        if ($item.Length -gt 1MB) {
            Say-Warn ("stream " + $pair[0] + " is over a megabyte. The log editor can trim it.")
        }
    } else {
        Say-Info ("stream " + $pair[0] + " (" + $pair[1] + ") does not exist yet")
    }
}

# ---------------------------------------------------------------------------
#  8. Files nothing points at
# ---------------------------------------------------------------------------
Say-Head "UNREFERENCED PROGRAMS"
$refText = ""
foreach ($f in @("menu.cfg", "apps.reg", "voice.cmds", "startup.bat")) {
    $p = Join-Path $here $f
    if (Test-Path -LiteralPath $p) { $refText += [System.IO.File]::ReadAllText($p) }
}
$orphans = 0
foreach ($f in (Get-ChildItem -LiteralPath $here -Include "*.bat", "*.ps1", "*.vbs" -File -ErrorAction SilentlyContinue)) {
    if ($refText -notmatch [regex]::Escape($f.Name)) {
        Say-Info ($f.Name + " is not launched from anywhere")
        $orphans++
    }
}
if ($orphans -eq 0) { Say-Ok "every program is registered somewhere" }

# ---------------------------------------------------------------------------
#  Summary
# ---------------------------------------------------------------------------
Say-Line ""
Say-Line "==============================================================================="
if ($problems.Count -eq 0) {
    Say-Line "  SCAN COMPLETE - nothing wrong found." "Green"
} else {
    Say-Line ("  SCAN COMPLETE - " + $problems.Count + " thing(s) to look at:") "Yellow"
    Say-Line ""
    foreach ($p in $problems) { Say-Line ("   " + $p) "Yellow" }
    Say-Line ""
    Say-Line "  Run Instant Error Repair from the developer menu to fix what can be" "Yellow"
    Say-Line "  fixed automatically. Look any STARP code up in errors.txt." "Yellow"
}
Say-Line "==============================================================================="

if ($Log -ne "") {
    try {
        $stamp = "[" + (Get-Date -Format "HH:mm:ss.ff") + "] [DEV_SCAN] "
        Add-Content -LiteralPath $Log -Value ($stamp + "Scan finished with " + $problems.Count + " findings") -Encoding ASCII -ErrorAction Stop
        foreach ($p in $problems) {
            Add-Content -LiteralPath $Log -Value ($stamp + $p) -Encoding ASCII -ErrorAction Stop
        }
    } catch { }
}

if (-not $NoPause) {
    Write-Host ""
    Write-Host "Press any key to return to starpOS . . ."
    try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
}
