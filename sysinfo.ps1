# ===========================================================================
#  sysinfo.ps1  -  starpOS real system information reporter
# ===========================================================================
#  The System Info screen in startup.bat prints made-up specs. This one
#  reads the actual machine, and pulls the starpOS identity block out of
#  starpos.cfg so both agree.
#
#  Run it from batch:
#
#     powershell -NoProfile -ExecutionPolicy Bypass -File "sysinfo.ps1"
#
#  And to also append the report to a log stream:
#
#     powershell -NoProfile -ExecutionPolicy Bypass -File "sysinfo.ps1" -Log "..\data\1.log"
#
#  -NoPause keeps it from waiting for a key, for unattended boot logging.
# ===========================================================================

[CmdletBinding()]
param(
    [string]$Config = "starpos.cfg",
    [string]$Log    = "",
    [switch]$NoPause
)

$ErrorActionPreference = "Continue"
$lines = New-Object System.Collections.Generic.List[string]

function Add-Line {
    param([string]$Text = "")
    $lines.Add($Text) | Out-Null
}

function Add-Field {
    param([string]$Label, $Value)
    if ($null -eq $Value -or "$Value".Trim() -eq "") { $Value = "unavailable" }
    Add-Line ("  {0,-18}: {1}" -f $Label, $Value)
}

# --- starpOS identity, straight out of starpos.cfg --------------------------
function Read-Config {
    param([string]$Path)
    $settings = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $settings }
    foreach ($line in (Get-Content -LiteralPath $Path)) {
        $trimmed = $line.Trim()
        if ($trimmed -eq "" -or $trimmed.StartsWith("#")) { continue }
        $split = $trimmed.IndexOf("=")
        if ($split -lt 1) { continue }
        $key = $trimmed.Substring(0, $split).Trim()
        $val = $trimmed.Substring($split + 1).Trim()
        $settings[$key] = $val
    }
    return $settings
}

function Get-Setting {
    param($Settings, [string]$Key, [string]$Fallback)
    if ($Settings.ContainsKey($Key) -and "$($Settings[$Key])".Trim() -ne "") {
        return $Settings[$Key]
    }
    return $Fallback
}

# Resolve the config next to this script, not next to whoever called it.
$here = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not [System.IO.Path]::IsPathRooted($Config)) {
    $Config = Join-Path $here $Config
}
$cfg = Read-Config -Path $Config

# --- Collect the real numbers ----------------------------------------------
# Each probe is wrapped: one missing WMI class must not kill the whole report.
function Get-CimSafe {
    param([string]$Class)
    try { return Get-CimInstance -ClassName $Class -ErrorAction Stop } catch { return $null }
}

$os    = Get-CimSafe "Win32_OperatingSystem"
$cs    = Get-CimSafe "Win32_ComputerSystem"
$cpu   = @(Get-CimSafe "Win32_Processor")
$gpu   = @(Get-CimSafe "Win32_VideoController")
$bios  = Get-CimSafe "Win32_BIOS"
$disks = @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)

Add-Line "==============================================================================="
Add-Line "                        starpOS SYSTEM INFORMATION"
Add-Line "==============================================================================="
Add-Line ("  Report generated : " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
Add-Line ""

Add-Line "--- starpOS -------------------------------------------------------------------"
Add-Field "OS Name"      (Get-Setting $cfg "OS_NAME"      "starpOS")
Add-Field "Version"      (Get-Setting $cfg "OS_VERSION"   "unknown")
Add-Field "Codename"     (Get-Setting $cfg "OS_CODENAME"  "unknown")
Add-Field "Build"        (Get-Setting $cfg "OS_BUILD"     "unknown")
Add-Field "Architecture" (Get-Setting $cfg "OS_ARCH"      "Batch 64-bit Emulation")
Add-Field "Developer"    (Get-Setting $cfg "OS_DEVELOPER" "ScottSoft Team")
if (Test-Path -LiteralPath $Config) {
    Add-Field "Config file" $Config
} else {
    Add-Field "Config file" "not found (STARP-0202)"
}
Add-Line ""

Add-Line "--- Host operating system -----------------------------------------------------"
if ($os) {
    Add-Field "Windows"   $os.Caption
    Add-Field "Version"   ("{0} (build {1})" -f $os.Version, $os.BuildNumber)
    Add-Field "Installed" $os.InstallDate
    if ($os.LastBootUpTime) {
        $up = (Get-Date) - $os.LastBootUpTime
        Add-Field "Booted" $os.LastBootUpTime
        Add-Field "Uptime" ("{0}d {1}h {2}m" -f $up.Days, $up.Hours, $up.Minutes)
    }
} else {
    Add-Field "Windows" "unavailable"
}
Add-Field "Machine name" $env:COMPUTERNAME
Add-Field "Signed in as" ("{0}\{1}" -f $env:USERDOMAIN, $env:USERNAME)
Add-Field "PowerShell"   $PSVersionTable.PSVersion.ToString()
Add-Line ""

Add-Line "--- Hardware ------------------------------------------------------------------"
if ($cs) {
    Add-Field "Manufacturer" $cs.Manufacturer
    Add-Field "Model"        $cs.Model
}
if ($cpu.Count -gt 0 -and $cpu[0]) {
    Add-Field "Processor" $cpu[0].Name
    Add-Field "Cores"     ("{0} physical / {1} logical @ {2} MHz" -f $cpu[0].NumberOfCores, $cpu[0].NumberOfLogicalProcessors, $cpu[0].MaxClockSpeed)
}
if ($os -and $os.TotalVisibleMemorySize) {
    $totalMb = [math]::Round($os.TotalVisibleMemorySize / 1024)
    $freeMb  = [math]::Round($os.FreePhysicalMemory / 1024)
    $usedMb  = $totalMb - $freeMb
    $pct     = 0
    if ($totalMb -gt 0) { $pct = [math]::Round(($usedMb / $totalMb) * 100) }
    Add-Field "Memory" ("{0} MB total / {1} MB free ({2}% in use)" -f $totalMb, $freeMb, $pct)
}
foreach ($card in $gpu) {
    if ($card -and $card.Name) { Add-Field "Graphics" $card.Name }
}
if ($bios) {
    Add-Field "BIOS" ("{0} {1}" -f $bios.Manufacturer, $bios.SMBIOSBIOSVersion)
}
Add-Line ""

Add-Line "--- Storage -------------------------------------------------------------------"
$shown = 0
foreach ($d in $disks) {
    if ($null -eq $d.Used -and $null -eq $d.Free) { continue }
    $used = 0
    $free = 0
    if ($d.Used) { $used = [math]::Round($d.Used / 1GB, 1) }
    if ($d.Free) { $free = [math]::Round($d.Free / 1GB, 1) }
    Add-Line ("  {0,-18}: {1} GB used / {2} GB free" -f ($d.Name + ":"), $used, $free)
    $shown = $shown + 1
}
if ($shown -eq 0) { Add-Field "Drives" "unavailable" }
Add-Line ""

Add-Line "--- starpOS folders -----------------------------------------------------------"
$folders = @(
    @("System",    (Get-Setting $cfg "DIR_SYSTEM"    ".")),
    @("Data",      (Get-Setting $cfg "DIR_DATA"      "..\data")),
    @("Debug",     (Get-Setting $cfg "DIR_DEBUG"     "..\debug")),
    @("Builds",    (Get-Setting $cfg "DIR_BUILDS"    "..\builds")),
    @("Resources", (Get-Setting $cfg "DIR_RESOURCES" "..\resources"))
)
foreach ($pair in $folders) {
    $label = $pair[0]
    $path  = Join-Path $here $pair[1]
    if (Test-Path -LiteralPath $path) {
        $count = @(Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue).Count
        Add-Line ("  {0,-18}: present ({1} items)" -f $label, $count)
    } else {
        Add-Line ("  {0,-18}: MISSING  (STARP-0201)" -f $label)
    }
}
Add-Line ""
Add-Line "==============================================================================="

# --- Output -----------------------------------------------------------------
$report = $lines -join [Environment]::NewLine
Write-Host $report

if ($Log -ne "") {
    if (-not [System.IO.Path]::IsPathRooted($Log)) { $Log = Join-Path $here $Log }
    try {
        $stamp = "[" + (Get-Date -Format "HH:mm:ss.ff") + "] [SYSINFO] "
        Add-Content -LiteralPath $Log -Value ($stamp + "System information report:") -Encoding ASCII -ErrorAction Stop
        Add-Content -LiteralPath $Log -Value $report -Encoding ASCII -ErrorAction Stop
    } catch {
        Write-Host "[ STARP-0202 ] Could not write to the log stream: $Log"
    }
}

if (-not $NoPause) {
    Write-Host ""
    Write-Host "Press any key to return to starpOS . . ."
    try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
}
