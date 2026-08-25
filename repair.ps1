# ===========================================================================
#  repair.ps1  -  starpOS instant error repair   (developer mode)
# ===========================================================================
#  Finds the faults starpOS knows how to fix and fixes them. Nothing is
#  changed until you say so, and anything it edits is copied into
#  system\backup first, so a repair can always be undone by copying the
#  backup back.
#
#     powershell -NoProfile -ExecutionPolicy Bypass -File "repair.ps1"
#
#  Switches:
#     -Auto      apply every safe fix without asking (still makes backups)
#     -Check     only report, never offer to change anything
#
#  scan.ps1 is the tool that finds problems this one cannot fix, such as a
#  goto pointing at a label that does not exist. That needs a person to
#  decide what the jump was meant to say.
# ===========================================================================

[CmdletBinding()]
param(
    [string]$Log = "",
    [switch]$Auto,
    [switch]$Check,
    [switch]$NoPause
)

$ErrorActionPreference = "Continue"
$here   = Split-Path -Parent $MyInvocation.MyCommand.Definition
$root   = Split-Path -Parent $here
$backup = Join-Path $here "backup"

if ($Log -ne "" -and -not [System.IO.Path]::IsPathRooted($Log)) { $Log = Join-Path $here $Log }

function Write-Log {
    param([string]$Message)
    if ($Log -eq "") { return }
    try {
        Add-Content -LiteralPath $Log -Value ("[" + (Get-Date -Format "HH:mm:ss.ff") + "] [DEV_REPAIR] " + $Message) -Encoding ASCII -ErrorAction Stop
    } catch { }
}

# Every fix is one of these: a description, and a script block that does it.
$fixes = New-Object System.Collections.Generic.List[object]
function Add-Fix {
    param([string]$Code, [string]$What, [scriptblock]$Action)
    $o = New-Object PSObject
    $o | Add-Member NoteProperty Code   $Code
    $o | Add-Member NoteProperty What   $What
    $o | Add-Member NoteProperty Action $Action
    $fixes.Add($o) | Out-Null
}

function Backup-File {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $true }
    try {
        if (-not (Test-Path -LiteralPath $backup)) {
            New-Item -ItemType Directory -Path $backup -Force -ErrorAction Stop | Out-Null
        }
        $name = [System.IO.Path]::GetFileName($Path) + "." + (Get-Date -Format "yyyyMMdd-HHmmss") + ".bak"
        Copy-Item -LiteralPath $Path -Destination (Join-Path $backup $name) -Force -ErrorAction Stop
        Write-Host ("        backed up to backup\" + $name) -ForegroundColor DarkGray
        return $true
    } catch {
        Write-Host ("        [ ERROR ] could not back up " + $Path + " - refusing to change it") -ForegroundColor Red
        return $false
    }
}

try { Clear-Host } catch { }
Write-Host "==============================================================================="
Write-Host "                      starpOS INSTANT ERROR REPAIR"
Write-Host "==============================================================================="
Write-Host ""
Write-Host "  Checking..." -ForegroundColor Gray
Write-Host ""

# ---------------------------------------------------------------------------
#  1. Missing folders
# ---------------------------------------------------------------------------
foreach ($name in @("data", "debug", "builds", "resources")) {
    $p = Join-Path $root $name
    if (-not (Test-Path -LiteralPath $p)) {
        Add-Fix "STARP-0201" "the $name folder is missing" ([scriptblock]::Create("New-Item -ItemType Directory -Path '$p' -Force | Out-Null"))
    }
}
$notes = Join-Path $root "data\notes"
if (-not (Test-Path -LiteralPath $notes)) {
    Add-Fix "STARP-0201" "the notes folder is missing, Notepad has nowhere to save" ([scriptblock]::Create("New-Item -ItemType Directory -Path '$notes' -Force | Out-Null"))
}

# ---------------------------------------------------------------------------
#  2. Missing log streams
# ---------------------------------------------------------------------------
foreach ($pair in @(@("1", "KERNEL"), @("2", "SYSTEM"), @("3", "USER"))) {
    $p = Join-Path $root ("data\" + $pair[0] + ".log")
    if (-not (Test-Path -LiteralPath $p)) {
        $header = "=== starpOS " + $pair[1] + " LOG - created by repair.ps1 ==="
        Add-Fix "STARP-0202" ("log stream " + $pair[0] + " (" + $pair[1] + ") does not exist") ([scriptblock]::Create("
            `$d = Split-Path -Parent '$p'
            if (-not (Test-Path -LiteralPath `$d)) { New-Item -ItemType Directory -Path `$d -Force | Out-Null }
            Set-Content -LiteralPath '$p' -Value '$header' -Encoding ASCII"))
    }
}

# ---------------------------------------------------------------------------
#  3. Batch files saved with Unix line endings
# ---------------------------------------------------------------------------
foreach ($bat in (Get-ChildItem -LiteralPath $here -Filter "*.bat" -File -ErrorAction SilentlyContinue)) {
    $raw = ""
    try { $raw = [System.IO.File]::ReadAllText($bat.FullName) } catch { continue }
    $crlf = ([regex]::Matches($raw, "`r`n")).Count
    $lf   = ([regex]::Matches($raw, "`n")).Count
    if ($lf -gt 0 -and $crlf -lt $lf) {
        $fp = $bat.FullName
        Add-Fix "STARP-0106" ($bat.Name + " has Unix line endings, which breaks goto and call") ([scriptblock]::Create("
            `$t = [System.IO.File]::ReadAllText('$fp')
            `$t = `$t -replace ""``r``n"", ""``n""
            `$t = `$t -replace ""``n"", ""``r``n""
            [System.IO.File]::WriteAllText('$fp', `$t)"))
    }
}

# ---------------------------------------------------------------------------
#  4. menu.cfg entries pointing at things that are not there
# ---------------------------------------------------------------------------
$menuPath = Join-Path $here "menu.cfg"
if (Test-Path -LiteralPath $menuPath) {

    $startupText = ""
    $sp = Join-Path $here "startup.bat"
    if (Test-Path -LiteralPath $sp) { $startupText = [System.IO.File]::ReadAllText($sp) }

    $dead = New-Object System.Collections.Generic.List[string]
    foreach ($line in (Get-Content -LiteralPath $menuPath)) {
        $t = $line.Trim()
        if ($t -eq "" -or $t.StartsWith("#")) { continue }
        $p = $t.Split("|")
        if ($p.Count -lt 4) { continue }
        $type = $p[2].Trim().ToLower()
        $target = $p[3].Trim()
        $ok = $true
        if ($type -eq "builtin") {
            if ($startupText -notmatch ("(?im)^\s*:" + [regex]::Escape($target) + "\s*$")) { $ok = $false }
        } elseif ($type -ne "cmd") {
            if (-not (Test-Path -LiteralPath (Join-Path $here $target))) { $ok = $false }
        }
        if (-not $ok) { $dead.Add($t) | Out-Null }
    }

    foreach ($d in $dead) {
        $esc = $d.Replace("'", "''")
        Add-Fix "STARP-0401" ("menu entry goes nowhere and will error when picked: " + $d) ([scriptblock]::Create("
            `$lines = Get-Content -LiteralPath '$menuPath'
            `$out = @()
            foreach (`$l in `$lines) {
                if (`$l.Trim() -eq '$esc') {
                    `$out += '# disabled by repair.ps1, target was missing:'
                    `$out += ('# ' + `$l)
                } else { `$out += `$l }
            }
            Set-Content -LiteralPath '$menuPath' -Value `$out -Encoding ASCII"))
    }
}

# ---------------------------------------------------------------------------
#  5. starpos.cfg problems
# ---------------------------------------------------------------------------
$cfgPath = Join-Path $here "starpos.cfg"
if (Test-Path -LiteralPath $cfgPath) {
    $cfgLines = @(Get-Content -LiteralPath $cfgPath)
    $keys = @{}
    $dupes = @()
    $spaced = @()
    foreach ($line in $cfgLines) {
        $t = $line.Trim()
        if ($t -eq "" -or $t.StartsWith("#") -or $t -notmatch "=") { continue }
        $k = $t.Substring(0, $t.IndexOf("="))
        if ($k -ne $k.Trim()) { $spaced += $k.Trim() }
        if ($keys.ContainsKey($k.Trim())) { $dupes += $k.Trim() }
        $keys[$k.Trim()] = $true
    }

    if ($spaced.Count -gt 0) {
        Add-Fix "STARP-0207" ("config keys have spaces around the = : " + ($spaced -join ", ")) ([scriptblock]::Create("
            `$lines = Get-Content -LiteralPath '$cfgPath'
            `$out = @()
            foreach (`$l in `$lines) {
                `$t = `$l.Trim()
                if (`$t -ne '' -and -not `$t.StartsWith('#') -and `$t -match '=') {
                    `$i = `$t.IndexOf('=')
                    `$out += (`$t.Substring(0, `$i).Trim() + '=' + `$t.Substring(`$i + 1).Trim())
                } else { `$out += `$l }
            }
            Set-Content -LiteralPath '$cfgPath' -Value `$out -Encoding ASCII"))
    }

    if ($dupes.Count -gt 0) {
        $uniq = ($dupes | Select-Object -Unique) -join ", "
        Add-Fix "STARP-0208" ("these settings appear twice, only the last one counts: " + $uniq) ([scriptblock]::Create("
            `$lines = Get-Content -LiteralPath '$cfgPath'
            `$last = @{}
            `$idx = 0
            foreach (`$l in `$lines) {
                `$t = `$l.Trim()
                if (`$t -ne '' -and -not `$t.StartsWith('#') -and `$t -match '=') {
                    `$last[`$t.Substring(0, `$t.IndexOf('=')).Trim()] = `$idx
                }
                `$idx++
            }
            `$out = @()
            `$idx = 0
            foreach (`$l in `$lines) {
                `$t = `$l.Trim()
                `$keep = `$true
                if (`$t -ne '' -and -not `$t.StartsWith('#') -and `$t -match '=') {
                    `$k = `$t.Substring(0, `$t.IndexOf('=')).Trim()
                    if (`$last[`$k] -ne `$idx) { `$keep = `$false }
                }
                if (`$keep) { `$out += `$l }
                `$idx++
            }
            Set-Content -LiteralPath '$cfgPath' -Value `$out -Encoding ASCII"))
    }
}

# ---------------------------------------------------------------------------
#  6. Executables sitting in the resources folder
# ---------------------------------------------------------------------------
$res = Join-Path $root "resources"
if (Test-Path -LiteralPath $res) {
    foreach ($b in (Get-ChildItem -LiteralPath $res -Include "*.bat", "*.cmd" -Recurse -File -ErrorAction SilentlyContinue)) {
        $src = $b.FullName
        $dst = Join-Path $here $b.Name
        Add-Fix "STARP-0205" ($b.Name + " is a script sitting in the resources folder") ([scriptblock]::Create("
            if (Test-Path -LiteralPath '$dst') {
                Write-Host '        a file of that name is already in system, leaving it alone' -ForegroundColor Yellow
            } else {
                Move-Item -LiteralPath '$src' -Destination '$dst' -ErrorAction Stop
            }"))
    }
}

# ---------------------------------------------------------------------------
#  Report
# ---------------------------------------------------------------------------
if ($fixes.Count -eq 0) {
    Write-Host "  Nothing to repair. starpOS looks healthy." -ForegroundColor Green
    Write-Host ""
    Write-Host "  For the deeper checks this tool cannot fix on its own, such as a goto"
    Write-Host "  aimed at a label that does not exist, run the Advanced System Scan."
    Write-Host ""
    Write-Log "Repair found nothing to fix"
    if (-not $NoPause) {
        Write-Host "Press any key to return to starpOS . . ."
        try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
    }
    return
}

Write-Host ("  Found " + $fixes.Count + " thing(s) that can be repaired automatically:") -ForegroundColor Yellow
Write-Host ""
$n = 0
foreach ($f in $fixes) {
    $n++
    Write-Host ("   " + $n.ToString().PadLeft(2) + ". [" + $f.Code + "]  " + $f.What)
}
Write-Host ""

if ($Check) {
    Write-Host "  Running in check-only mode, nothing was changed." -ForegroundColor Gray
    Write-Host ""
    if (-not $NoPause) {
        Write-Host "Press any key to return to starpOS . . ."
        try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
    }
    return
}

# ---------------------------------------------------------------------------
#  Apply
# ---------------------------------------------------------------------------
$chosen = @()
if ($Auto) {
    $chosen = 1..$fixes.Count
} else {
    Write-Host "==============================================================================="
    Write-Host "  Type ALL to fix everything, or numbers separated by spaces (e.g. 1 3 4)."
    Write-Host "  Press Enter on its own to change nothing and go back."
    Write-Host "==============================================================================="
    Write-Host ""
    Write-Host -NoNewline "  repair> "
    $answer = ""
    try { $answer = [string](Read-Host) } catch { $answer = "" }
    $answer = $answer.Trim()

    if ($answer -eq "") {
        Write-Host ""
        Write-Host "  Nothing was changed." -ForegroundColor Gray
        Write-Log "Repair cancelled by user"
        if (-not $NoPause) {
            Write-Host ""
            Write-Host "Press any key to return to starpOS . . ."
            try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
        }
        return
    }

    if ($answer -match '(?i)^all$') {
        $chosen = 1..$fixes.Count
    } else {
        foreach ($part in ($answer -split '[\s,]+')) {
            if ($part -match '^\d+$') {
                $i = [int]$part
                if ($i -ge 1 -and $i -le $fixes.Count) { $chosen += $i }
                else { Write-Host ("  There is no fix number " + $i) -ForegroundColor Yellow }
            }
        }
    }
}

if ($chosen.Count -eq 0) {
    Write-Host "  Nothing selected, nothing changed." -ForegroundColor Gray
} else {
    Write-Host ""
    $done = 0
    $failed = 0
    foreach ($i in ($chosen | Select-Object -Unique | Sort-Object)) {
        $f = $fixes[$i - 1]
        Write-Host ("   fixing " + $i + ". " + $f.What) -ForegroundColor Cyan

        # Anything that rewrites an existing file gets copied first.
        $touch = @()
        if ($f.Code -eq "STARP-0401") { $touch += $menuPath }
        if ($f.Code -eq "STARP-0207" -or $f.Code -eq "STARP-0208") { $touch += $cfgPath }
        if ($f.Code -eq "STARP-0106") {
            foreach ($b in (Get-ChildItem -LiteralPath $here -Filter "*.bat" -File)) {
                if ($f.What.StartsWith($b.Name)) { $touch += $b.FullName }
            }
        }
        $safe = $true
        foreach ($t in $touch) { if (-not (Backup-File $t)) { $safe = $false } }
        if (-not $safe) {
            Write-Host "        skipped, could not make a backup first" -ForegroundColor Red
            $failed++
            continue
        }

        try {
            & $f.Action
            Write-Host "        done" -ForegroundColor Green
            Write-Log ("Fixed " + $f.Code + ": " + $f.What)
            $done++
        } catch {
            Write-Host ("        [ ERROR ] " + $_.Exception.Message) -ForegroundColor Red
            Write-Log ("FAILED " + $f.Code + ": " + $_.Exception.Message)
            $failed++
        }
    }
    Write-Host ""
    Write-Host ("  " + $done + " repaired, " + $failed + " failed.") -ForegroundColor White
    if ($done -gt 0) {
        Write-Host "  Originals of anything edited are in system\backup." -ForegroundColor DarkGray
    }
}

Write-Host ""
if (-not $NoPause) {
    Write-Host "Press any key to return to starpOS . . ."
    try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
}
