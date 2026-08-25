# ===========================================================================
#  logedit.ps1  -  starpOS log editor   (developer mode)
# ===========================================================================
#  Read, search, trim, rewrite and wipe the log streams from inside starpOS.
#  logview.ps1 is the read-only viewer on the normal desktop. This one can
#  change what is in them, so it lives behind developer mode.
#
#     powershell -NoProfile -ExecutionPolicy Bypass -File "logedit.ps1"
#
#  Every command that changes a stream copies it into system\backup first.
#  If you delete the wrong thing, the previous version is still there.
# ===========================================================================

[CmdletBinding()]
param(
    [ValidateSet("1", "2", "3")]
    [string]$Stream = "1",
    [switch]$NoPause
)

$ErrorActionPreference = "Continue"
$here   = Split-Path -Parent $MyInvocation.MyCommand.Definition
$root   = Split-Path -Parent $here
$backup = Join-Path $here "backup"

$names = @{ "1" = "KERNEL"; "2" = "SYSTEM"; "3" = "USER" }

function Get-StreamPath {
    param([string]$Key)
    return (Join-Path $root ("data\" + $Key + ".log"))
}

function Backup-Stream {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $true }
    try {
        if (-not (Test-Path -LiteralPath $backup)) {
            New-Item -ItemType Directory -Path $backup -Force -ErrorAction Stop | Out-Null
        }
        $name = [System.IO.Path]::GetFileName($Path) + "." + (Get-Date -Format "yyyyMMdd-HHmmss") + ".bak"
        Copy-Item -LiteralPath $Path -Destination (Join-Path $backup $name) -Force -ErrorAction Stop
        Write-Host ("  [ backup ] backup\" + $name) -ForegroundColor DarkGray
        return $true
    } catch {
        Write-Host "  [ ERROR ] Could not make a backup, so nothing was changed." -ForegroundColor Red
        return $false
    }
}

function Read-Stream {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    try { return @(Get-Content -LiteralPath $Path -ErrorAction Stop) } catch { return @() }
}

function Save-Stream {
    param([string]$Path, $Lines)
    try {
        Set-Content -LiteralPath $Path -Value $Lines -Encoding ASCII -ErrorAction Stop
        return $true
    } catch {
        Write-Host "  [ STARP-0202 ] Could not write the stream. Is it open somewhere else?" -ForegroundColor Red
        return $false
    }
}

function Get-Colour {
    param([string]$Text)
    if ($Text -match "SECURITY|ERROR|FAIL|WARNING|STARP-") { return "Red" }
    if ($Text -match "\[AUTH\]|\[PWR\]|\[DEV") { return "Yellow" }
    if ($Text -match "\[LAUNCH\]|\[ACT\]|\[VOICE_CMD\]") { return "Cyan" }
    if ($Text -match "\[INP\]|\[DATA\]") { return "Green" }
    return "Gray"
}

function Show-Lines {
    param($Lines, [int]$Tail = 25, [string]$Filter = "")
    $shown = $Lines
    $offset = 0
    if ($Filter -ne "") {
        Write-Host ("  Lines containing '" + $Filter + "':") -ForegroundColor White
        Write-Host ""
        $i = 0
        $hits = 0
        foreach ($l in $Lines) {
            $i++
            if ($l -match [regex]::Escape($Filter)) {
                Write-Host ("  " + $i.ToString().PadLeft(5) + " | " + $l) -ForegroundColor (Get-Colour $l)
                $hits++
            }
        }
        if ($hits -eq 0) { Write-Host "  Nothing matched." -ForegroundColor DarkGray }
        Write-Host ""
        Write-Host ("  " + $hits + " matching line(s) out of " + $Lines.Count) -ForegroundColor DarkGray
        return
    }
    if ($Tail -gt 0 -and $Lines.Count -gt $Tail) {
        $offset = $Lines.Count - $Tail
        $shown = $Lines[$offset..($Lines.Count - 1)]
        Write-Host ("  ... " + $offset + " earlier lines hidden ...") -ForegroundColor DarkGray
    }
    $i = $offset
    foreach ($l in $shown) {
        $i++
        Write-Host ("  " + $i.ToString().PadLeft(5) + " | " + $l) -ForegroundColor (Get-Colour $l)
    }
    Write-Host ""
    Write-Host ("  " + $Lines.Count + " lines total") -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
#  Main loop
# ---------------------------------------------------------------------------
$emptyRuns = 0

while ($true) {

    $path  = Get-StreamPath $Stream
    $lines = @(Read-Stream $path)

    try {
        $host.UI.RawUI.WindowTitle = "starpOS Log Editor"
        Clear-Host
    } catch { }

    Write-Host "==============================================================================="
    Write-Host "  starpOS LOG EDITOR                                       DEVELOPER MODE"
    Write-Host "==============================================================================="
    Write-Host ("  Stream " + $Stream + " (" + $names[$Stream] + ")   " + $path)
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host "  [ STARP-0201 ] This stream does not exist yet." -ForegroundColor Red
    } else {
        Write-Host ("  " + $lines.Count + " lines")
    }
    Write-Host "-------------------------------------------------------------------------------"
    Write-Host "   1  Switch stream (1 kernel, 2 system, 3 user)"
    Write-Host "   2  Show the last 25 lines"
    Write-Host "   3  Show everything"
    Write-Host "   4  Search for text"
    Write-Host "   5  Delete one line by number"
    Write-Host "   6  Delete every line containing some text"
    Write-Host "   7  Keep only the last N lines"
    Write-Host "   8  Add a line of your own"
    Write-Host "   9  Wipe this stream completely"
    Write-Host "   0  Back to the developer menu"
    Write-Host "==============================================================================="
    Write-Host ""
    Write-Host -NoNewline "  logedit> "

    $pick = ""
    try { $pick = [string](Read-Host) } catch { break }
    $pick = $pick.Trim()

    if ($pick -eq "") {
        $emptyRuns++
        if ($emptyRuns -ge 30) {
            Write-Host "  [ INFO ] No input. Closing the log editor."
            break
        }
        continue
    }
    $emptyRuns = 0

    switch ($pick) {

        "0" { return }

        "1" {
            Write-Host ""
            Write-Host -NoNewline "  Which stream, 1 2 or 3> "
            $s = ""
            try { $s = [string](Read-Host) } catch { $s = "" }
            $s = $s.Trim()
            if ($names.ContainsKey($s)) {
                $Stream = $s
            } else {
                Write-Host "  That is not a stream number." -ForegroundColor Yellow
                Start-Sleep -Milliseconds 1200
            }
        }

        "2" {
            Write-Host ""
            Show-Lines $lines 25
            Write-Host ""
            Write-Host "  Press any key . . ."
            try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
        }

        "3" {
            Write-Host ""
            Show-Lines $lines 0
            Write-Host ""
            Write-Host "  Press any key . . ."
            try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
        }

        "4" {
            Write-Host ""
            Write-Host -NoNewline "  Search for> "
            $term = ""
            try { $term = [string](Read-Host) } catch { $term = "" }
            $term = $term.Trim()
            if ($term -ne "") {
                Write-Host ""
                Show-Lines $lines 0 $term
                Write-Host ""
                Write-Host "  Press any key . . ."
                try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
            }
        }

        "5" {
            Write-Host ""
            Write-Host -NoNewline "  Delete which line number> "
            $num = ""
            try { $num = [string](Read-Host) } catch { $num = "" }
            if ($num -match '^\d+$') {
                $i = [int]$num
                if ($i -lt 1 -or $i -gt $lines.Count) {
                    Write-Host ("  There is no line " + $i + ". This stream has " + $lines.Count + ".") -ForegroundColor Yellow
                } else {
                    Write-Host ""
                    Write-Host ("  About to delete:  " + $lines[$i - 1]) -ForegroundColor Yellow
                    Write-Host -NoNewline "  Type YES to confirm> "
                    $c = ""
                    try { $c = [string](Read-Host) } catch { $c = "" }
                    if ($c.Trim() -eq "YES") {
                        if (Backup-Stream $path) {
                            $out = @()
                            for ($k = 0; $k -lt $lines.Count; $k++) {
                                if ($k -ne ($i - 1)) { $out += $lines[$k] }
                            }
                            if (Save-Stream $path $out) { Write-Host "  Deleted." -ForegroundColor Green }
                        }
                    } else {
                        Write-Host "  Cancelled." -ForegroundColor Gray
                    }
                }
            } else {
                Write-Host "  That is not a number." -ForegroundColor Yellow
            }
            Start-Sleep -Milliseconds 1500
        }

        "6" {
            Write-Host ""
            Write-Host -NoNewline "  Delete every line containing> "
            $term = ""
            try { $term = [string](Read-Host) } catch { $term = "" }
            $term = $term.Trim()
            if ($term -eq "") {
                Write-Host "  Nothing typed, nothing deleted." -ForegroundColor Gray
            } else {
                $hits = @($lines | Where-Object { $_ -match [regex]::Escape($term) })
                if ($hits.Count -eq 0) {
                    Write-Host "  Nothing matched, nothing deleted." -ForegroundColor Gray
                } else {
                    Write-Host ""
                    Write-Host ("  " + $hits.Count + " line(s) would go, for example:") -ForegroundColor Yellow
                    foreach ($h in ($hits | Select-Object -First 3)) { Write-Host ("    " + $h) -ForegroundColor DarkGray }
                    Write-Host ""
                    Write-Host -NoNewline "  Type YES to confirm> "
                    $c = ""
                    try { $c = [string](Read-Host) } catch { $c = "" }
                    if ($c.Trim() -eq "YES") {
                        if (Backup-Stream $path) {
                            $out = @($lines | Where-Object { $_ -notmatch [regex]::Escape($term) })
                            if (Save-Stream $path $out) {
                                Write-Host ("  Deleted " + $hits.Count + " line(s).") -ForegroundColor Green
                            }
                        }
                    } else {
                        Write-Host "  Cancelled." -ForegroundColor Gray
                    }
                }
            }
            Start-Sleep -Milliseconds 1800
        }

        "7" {
            Write-Host ""
            Write-Host -NoNewline "  Keep the last how many lines> "
            $num = ""
            try { $num = [string](Read-Host) } catch { $num = "" }
            if ($num -match '^\d+$') {
                $keep = [int]$num
                if ($keep -ge $lines.Count) {
                    Write-Host ("  This stream only has " + $lines.Count + " lines, nothing to trim.") -ForegroundColor Gray
                } else {
                    Write-Host ""
                    Write-Host ("  " + ($lines.Count - $keep) + " older line(s) would be removed.") -ForegroundColor Yellow
                    Write-Host -NoNewline "  Type YES to confirm> "
                    $c = ""
                    try { $c = [string](Read-Host) } catch { $c = "" }
                    if ($c.Trim() -eq "YES") {
                        if (Backup-Stream $path) {
                            $out = @()
                            if ($keep -gt 0) { $out = $lines[($lines.Count - $keep)..($lines.Count - 1)] }
                            if (Save-Stream $path $out) { Write-Host "  Trimmed." -ForegroundColor Green }
                        }
                    } else {
                        Write-Host "  Cancelled." -ForegroundColor Gray
                    }
                }
            } else {
                Write-Host "  That is not a number." -ForegroundColor Yellow
            }
            Start-Sleep -Milliseconds 1500
        }

        "8" {
            Write-Host ""
            Write-Host -NoNewline "  Text to add> "
            $text = ""
            try { $text = [string](Read-Host) } catch { $text = "" }
            $text = $text.Trim()
            if ($text -ne "") {
                try {
                    $stamp = "[" + (Get-Date -Format "HH:mm:ss.ff") + "] [DEV_NOTE] "
                    Add-Content -LiteralPath $path -Value ($stamp + $text) -Encoding ASCII -ErrorAction Stop
                    Write-Host "  Added." -ForegroundColor Green
                } catch {
                    Write-Host "  [ STARP-0202 ] Could not write to the stream." -ForegroundColor Red
                }
            }
            Start-Sleep -Milliseconds 1200
        }

        "9" {
            Write-Host ""
            Write-Host ("  This wipes every one of the " + $lines.Count + " lines in stream " + $Stream + ".") -ForegroundColor Red
            Write-Host -NoNewline "  Type WIPE to confirm> "
            $c = ""
            try { $c = [string](Read-Host) } catch { $c = "" }
            if ($c.Trim() -eq "WIPE") {
                if (Backup-Stream $path) {
                    $header = "=== starpOS " + $names[$Stream] + " LOG - wiped " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + " ==="
                    if (Save-Stream $path @($header)) { Write-Host "  Stream wiped." -ForegroundColor Green }
                }
            } else {
                Write-Host "  Cancelled, nothing was wiped." -ForegroundColor Gray
            }
            Start-Sleep -Milliseconds 1800
        }

        default {
            Write-Host "  Not an option." -ForegroundColor Yellow
            Start-Sleep -Milliseconds 900
        }
    }
}

Write-Host ""
Write-Host "  Log editor closed."
if (-not $NoPause) {
    Write-Host ""
    Write-Host "Press any key to return to starpOS . . ."
    try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
}
