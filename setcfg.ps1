# ===========================================================================
#  setcfg.ps1  -  write a setting back into starpos.cfg
# ===========================================================================
#  This is what makes starpOS settings STICK. Until now a theme change in
#  the Settings screen lasted until the window closed, because it only ran
#  the colour command. This edits the config file itself, so the choice is
#  still there after a reboot.
#
#     powershell -NoProfile -ExecutionPolicy Bypass -File "setcfg.ps1" -Key THEME_DESKTOP -Value 0A
#
#  Comments, blank lines and the order of the file are all preserved. If the
#  key is not in the file yet it gets added at the bottom.
#
#  Read a value back out instead of writing one:
#
#     powershell -NoProfile -ExecutionPolicy Bypass -File "setcfg.ps1" -Key OS_VERSION -Get
# ===========================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Key,
    [string]$Value = "",
    [string]$File  = "starpos.cfg",
    [switch]$Get,
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Definition

if (-not [System.IO.Path]::IsPathRooted($File)) { $File = Join-Path $here $File }

if (-not (Test-Path -LiteralPath $File)) {
    Write-Host "  [ STARP-0202 ] Config file not found: $File"
    exit 1
}

# A key is letters, digits and underscores. Anything else would produce a
# line the batch loader could not parse back in.
if ($Key -notmatch '^[A-Za-z0-9_]+$') {
    Write-Host "  [ ERROR ] '$Key' is not a valid setting name. Letters, digits and _ only."
    exit 1
}

try {
    $lines = @(Get-Content -LiteralPath $File -ErrorAction Stop)
} catch {
    Write-Host "  [ STARP-0202 ] Could not read $File"
    exit 1
}

# --- Read mode --------------------------------------------------------------
if ($Get) {
    foreach ($line in $lines) {
        $t = $line.Trim()
        if ($t -eq "" -or $t.StartsWith("#")) { continue }
        $i = $t.IndexOf("=")
        if ($i -lt 1) { continue }
        if ($t.Substring(0, $i).Trim() -eq $Key) {
            Write-Output $t.Substring($i + 1).Trim()
            exit 0
        }
    }
    exit 1
}

# --- Write mode -------------------------------------------------------------
# A value must survive the round trip through the batch loader, which splits
# on the first = and would choke on a newline.
if ($Value -match "[\r\n]") {
    Write-Host "  [ ERROR ] A setting cannot contain a line break."
    exit 1
}

$output  = New-Object System.Collections.Generic.List[string]
$replaced = $false

foreach ($line in $lines) {
    $t = $line.Trim()
    if ($t -ne "" -and -not $t.StartsWith("#")) {
        $i = $t.IndexOf("=")
        if ($i -ge 1 -and $t.Substring(0, $i).Trim() -eq $Key) {
            if (-not $replaced) {
                $output.Add("$Key=$Value") | Out-Null
                $replaced = $true
            }
            # A duplicate of the same key later in the file is dropped, so the
            # loader cannot end up with two different answers for one setting.
            continue
        }
    }
    $output.Add($line) | Out-Null
}

if (-not $replaced) {
    $output.Add("") | Out-Null
    $output.Add("# added by setcfg.ps1 on $(Get-Date -Format 'yyyy-MM-dd')") | Out-Null
    $output.Add("$Key=$Value") | Out-Null
}

# Write to a temp file first, then swap it in. If the machine dies halfway
# through, the original config is still intact.
$temp = $File + ".tmp"
try {
    Set-Content -LiteralPath $temp -Value $output -Encoding ASCII -ErrorAction Stop
    Move-Item -LiteralPath $temp -Destination $File -Force -ErrorAction Stop
} catch {
    Write-Host "  [ STARP-0202 ] Could not save $File - is it open in Notepad?"
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
    exit 1
}

if (-not $Quiet) {
    Write-Host "  [ OK ] $Key is now $Value  (saved, it will still be set next boot)"
}
exit 0
