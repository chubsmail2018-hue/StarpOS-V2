# ===========================================================================
#  calc.ps1  -  starpOS calculator
# ===========================================================================
#  Type a sum, get an answer. Keeps a history for the session and remembers
#  the last answer as "ans".
#
#     powershell -NoProfile -ExecutionPolicy Bypass -File "calc.ps1"
#
#  Do one sum and quit (handy from a batch file):
#
#     powershell -NoProfile -ExecutionPolicy Bypass -File "calc.ps1" -Expression "12*(3+4)"
#
#  WHY THE INPUT IS CHECKED FIRST: this evaluates what you type as
#  PowerShell, which would happily run a real command if one were typed in.
#  So anything that is not a number, an operator or a bracket is rejected
#  before it gets near the evaluator. Keep that check if you edit this file.
# ===========================================================================

[CmdletBinding()]
param(
    [string]$Expression = "",
    [switch]$NoPause
)

$ErrorActionPreference = "Continue"

# Only these characters may ever reach the evaluator.
$allowed = '^[0-9\.\+\-\*\/\%\(\)\s]+$'

$history = New-Object System.Collections.Generic.List[string]
$ans     = 0

function Solve {
    param([string]$Text)

    $clean = $Text.Trim()
    if ($clean -eq "") { return $null }

    # "ans" stands in for the previous answer.
    $clean = $clean -replace '(?i)\bans\b', ([string]$script:ans)
    # Let people write 5x3 and 12÷4 the way they would on paper.
    $clean = $clean -replace '(?i)x', '*'
    $clean = $clean -replace [char]0x00F7, '/'

    if ($clean -notmatch $allowed) {
        Write-Host "  [ ERROR ] Numbers and + - * / % ( ) only." -ForegroundColor Red
        return $null
    }
    if ($clean -match '/\s*0(?!\.)') {
        Write-Host "  [ ERROR ] Cannot divide by zero." -ForegroundColor Red
        return $null
    }

    try {
        $result = Invoke-Expression $clean
        return $result
    } catch {
        Write-Host "  [ ERROR ] That sum does not make sense. Check your brackets." -ForegroundColor Red
        return $null
    }
}

# --- One-shot mode ----------------------------------------------------------
if ($Expression -ne "") {
    $r = Solve $Expression
    if ($null -ne $r) { Write-Host $r }
    return
}

# --- Interactive mode -------------------------------------------------------
function Draw {
    try {
        $host.UI.RawUI.WindowTitle = "starpOS Calculator"
        Clear-Host
    } catch { }
    Write-Host "==============================================================================="
    Write-Host "                            starpOS CALCULATOR"
    Write-Host "==============================================================================="
    Write-Host ""
    Write-Host "  Type a sum and press Enter.       7 + 3 * 2        (7 + 3) * 2"
    Write-Host "  'ans' reuses the last answer.     ans / 4"
    Write-Host "  x and % work too.                 6 x 7            17 % 5"
    Write-Host ""
    Write-Host "  Commands:  hist  clears nothing, shows your sums"
    Write-Host "             clear wipes the history"
    Write-Host "             exit  returns to the starpOS desktop"
    Write-Host ""
    Write-Host "==============================================================================="
    Write-Host ""
}

Draw

while ($true) {

    Write-Host -NoNewline "  calc> "
    $entry = ""
    try { $entry = [string](Read-Host) } catch { break }
    $entry = $entry.Trim()

    if ($entry -eq "") { continue }

    if ($entry -match '(?i)^(exit|quit|q)$') { break }

    if ($entry -match '(?i)^(hist|history)$') {
        Write-Host ""
        if ($history.Count -eq 0) {
            Write-Host "  Nothing yet." -ForegroundColor DarkGray
        } else {
            foreach ($h in $history) { Write-Host ("   " + $h) -ForegroundColor Gray }
        }
        Write-Host ""
        continue
    }

    if ($entry -match '(?i)^(clear|cls)$') {
        $history.Clear()
        Draw
        continue
    }

    $result = Solve $entry
    if ($null -eq $result) { continue }

    $ans = $result
    $line = "$entry = $result"
    $history.Add($line) | Out-Null
    Write-Host ("  = " + $result) -ForegroundColor Green
}

Write-Host ""
Write-Host "  Calculator closed."
if (-not $NoPause) {
    Write-Host ""
    Write-Host "Press any key to return to starpOS . . ."
    try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
}
