# ===========================================================================
#  install.ps1  -  starpOS app installer   (developer mode)
# ===========================================================================
#  Puts programs onto the starpOS desktop that starpOS could not otherwise
#  run: a script from somewhere else on the disk, a Windows program, a
#  folder, a website. It writes the menu.cfg and apps.reg lines for you and
#  can take an app back off again.
#
#     powershell -NoProfile -ExecutionPolicy Bypass -File "install.ps1"
#
#  It can also hand a package over to winget, which is how Windows software
#  gets installed on this machine. That part never runs on its own: it shows
#  what it is about to do and waits for you to type YES.
# ===========================================================================

[CmdletBinding()]
param([switch]$NoPause)

$ErrorActionPreference = "Continue"
$here     = Split-Path -Parent $MyInvocation.MyCommand.Definition
$root     = Split-Path -Parent $here
$menuPath = Join-Path $here "menu.cfg"
$appsPath = Join-Path $here "apps.reg"
$backup   = Join-Path $here "backup"

function Ask {
    param([string]$Prompt, [string]$Default = "")
    if ($Default -ne "") { Write-Host -NoNewline ("  " + $Prompt + " [" + $Default + "]> ") }
    else { Write-Host -NoNewline ("  " + $Prompt + "> ") }
    $a = ""
    try { $a = [string](Read-Host) } catch { return $null }
    $a = $a.Trim()
    if ($a -eq "") { return $Default }
    return $a
}

function Write-StarpLog {
    param([string]$Message)
    try {
        Add-Content -LiteralPath (Join-Path $root "data\1.log") -Value ("[" + (Get-Date -Format "HH:mm:ss.ff") + "] [DEV_INSTALL] " + $Message) -Encoding ASCII -ErrorAction Stop
    } catch { }
}

function Get-MenuEntries {
    $list = @()
    if (-not (Test-Path -LiteralPath $menuPath)) { return $list }
    foreach ($line in (Get-Content -LiteralPath $menuPath)) {
        $t = $line.Trim()
        if ($t -eq "" -or $t.StartsWith("#")) { continue }
        $p = $t.Split("|")
        if ($p.Count -lt 4) { continue }
        $o = New-Object PSObject
        $o | Add-Member NoteProperty Slot   $p[0].Trim()
        $o | Add-Member NoteProperty Label  $p[1].Trim()
        $o | Add-Member NoteProperty Type   $p[2].Trim()
        $o | Add-Member NoteProperty Target $p[3].Trim()
        $o | Add-Member NoteProperty Raw    $t
        $list += $o
    }
    return $list
}

function Get-FreeSlot {
    $used = @{}
    foreach ($e in @(Get-MenuEntries)) { $used[$e.Slot.ToLower()] = $true }
    for ($i = 1; $i -le 99; $i++) {
        if (-not $used.ContainsKey([string]$i)) { return [string]$i }
    }
    return "99"
}

function Test-SlotFree {
    param([string]$Slot)
    foreach ($e in @(Get-MenuEntries)) {
        if ($e.Slot.ToLower() -eq $Slot.ToLower()) { return $false }
    }
    return $true
}

function Register-App {
    param([string]$Slot, [string]$Label, [string]$Type, [string]$Target, [string]$Desc)
    $Label = $Label -replace '\|', '-'
    $Desc  = $Desc  -replace '\|', '-'
    try {
        Add-Content -LiteralPath $menuPath -Value ($Slot + "|" + $Label + "|" + $Type + "|" + $Target) -Encoding ASCII -ErrorAction Stop
        Write-Host ("  [ OK ] on the desktop as " + $Slot) -ForegroundColor Green
    } catch {
        Write-Host "  [ ERROR ] could not write menu.cfg" -ForegroundColor Red
        return $false
    }
    try {
        Add-Content -LiteralPath $appsPath -Value ($Slot + "|" + $Label + "|" + $Target + "|app|" + $Desc) -Encoding ASCII -ErrorAction Stop
    } catch { }
    Write-StarpLog ("Installed '" + $Label + "' as slot " + $Slot + " -> " + $Target)
    return $true
}

# ---------------------------------------------------------------------------
#  Install a program that is already on the disk
# ---------------------------------------------------------------------------
function Install-LocalFile {
    Write-Host ""
    Write-Host "  Drag the file into this window, or type its full path."
    Write-Host "  Works with .bat .cmd .ps1 .vbs .exe and .lnk"
    Write-Host ""
    $path = Ask "File"
    if ($null -eq $path -or $path -eq "") { return }

    $path = $path.Trim('"').Trim("'")
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host ""
        Write-Host "  [ STARP-0401 ] There is nothing at that path." -ForegroundColor Red
        Start-Sleep -Seconds 2
        return
    }

    $item = Get-Item -LiteralPath $path
    $ext  = $item.Extension.ToLower()
    $known = @(".bat", ".cmd", ".ps1", ".vbs", ".exe", ".lnk")
    if ($known -notcontains $ext) {
        Write-Host ""
        Write-Host ("  " + $ext + " is not something starpOS knows how to launch as an app.") -ForegroundColor Yellow
        Write-Host "  It can still be added as a 'cmd' entry that opens it with Windows."
        $go = Ask "Add it that way? yes or no" "no"
        if ($go -notmatch '(?i)^y') { return }
    }

    Write-Host ""
    $label = Ask "What should it be called on the desktop" $item.BaseName
    if ($null -eq $label -or $label -eq "") { return }

    # Copying keeps starpOS self contained. Referencing leaves the file where
    # it is, which matters if it needs its own folder next to it.
    Write-Host ""
    Write-Host "  1. Copy it into the system folder  (starpOS keeps its own copy)"
    Write-Host "  2. Leave it where it is and point at it"
    $how = Ask "Pick 1 or 2" "1"

    $target = ""
    $type   = "cmd"

    if ($how -eq "1") {
        $dest = Join-Path $here $item.Name
        if (Test-Path -LiteralPath $dest) {
            Write-Host ""
            Write-Host ("  " + $item.Name + " is already in the system folder.") -ForegroundColor Yellow
            $ow = Ask "Overwrite it? yes or no" "no"
            if ($ow -notmatch '(?i)^y') { return }
            try {
                if (-not (Test-Path -LiteralPath $backup)) { New-Item -ItemType Directory -Path $backup -Force | Out-Null }
                Copy-Item -LiteralPath $dest -Destination (Join-Path $backup ($item.Name + "." + (Get-Date -Format "yyyyMMdd-HHmmss") + ".bak")) -Force
            } catch { }
        }
        try {
            Copy-Item -LiteralPath $item.FullName -Destination $dest -Force -ErrorAction Stop
            Write-Host ("  [ OK ] copied in as " + $item.Name) -ForegroundColor Green
        } catch {
            Write-Host ("  [ ERROR ] could not copy it: " + $_.Exception.Message) -ForegroundColor Red
            return
        }
        $target = $item.Name
    } else {
        $target = $item.FullName
    }

    switch ($ext) {
        ".ps1" { $type = "ps1" }
        ".bat" { $type = "bat" }
        ".cmd" { $type = "bat" }
        ".vbs" { $type = "vbs" }
        default { $type = "cmd"; $target = 'start "" "' + $target + '"' }
    }

    if ($ext -eq ".bat" -or $ext -eq ".cmd") {
        Write-Host ""
        Write-Host "  NOTE: bootcore.bat runs every .bat in the system folder at boot, so" -ForegroundColor Yellow
        Write-Host "  this one will also fire during startup unless its first line is:" -ForegroundColor Yellow
        Write-Host '        if not "%STARPOS_LAUNCH%"=="1" goto :eof' -ForegroundColor Yellow
    }

    Write-Host ""
    $slot = Ask "Which key opens it" (Get-FreeSlot)
    if (-not (Test-SlotFree $slot)) {
        $slot = Get-FreeSlot
        Write-Host ("  That key was taken, using " + $slot + " instead.") -ForegroundColor Yellow
    }

    $desc = Ask "One line describing it" ("Installed " + (Get-Date -Format "yyyy-MM-dd"))
    Write-Host ""
    [void](Register-App $slot $label $type $target $desc)
    Write-Host ""
    Write-Host "  Press any key . . ."
    try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
}

# ---------------------------------------------------------------------------
#  Install a website or a folder as an app
# ---------------------------------------------------------------------------
function Install-Shortcut {
    Write-Host ""
    Write-Host "  1. A website"
    Write-Host "  2. A folder on this computer"
    $k = Ask "Pick 1 or 2" "1"
    if ($null -eq $k) { return }

    if ($k -eq "1") {
        $url = Ask "Web address"
        if ($null -eq $url -or $url -eq "") { return }
        if ($url -notmatch '^(?i)https?://') { $url = "https://" + $url }
        $label = Ask "What should it be called" "Website"
        $slot  = Ask "Which key opens it" (Get-FreeSlot)
        if (-not (Test-SlotFree $slot)) { $slot = Get-FreeSlot }
        Write-Host ""
        [void](Register-App $slot $label "cmd" ('start "" "' + $url + '"') ("Opens " + $url))
    } else {
        $dir = Ask "Folder path"
        if ($null -eq $dir -or $dir -eq "") { return }
        $dir = $dir.Trim('"')
        if (-not (Test-Path -LiteralPath $dir)) {
            Write-Host "  [ STARP-0201 ] That folder is not there." -ForegroundColor Red
            Start-Sleep -Seconds 2
            return
        }
        $label = Ask "What should it be called" (Split-Path -Leaf $dir)
        $slot  = Ask "Which key opens it" (Get-FreeSlot)
        if (-not (Test-SlotFree $slot)) { $slot = Get-FreeSlot }
        Write-Host ""
        [void](Register-App $slot $label "cmd" ('explorer "' + $dir + '"') ("Opens " + $dir))
    }
    Write-Host ""
    Write-Host "  Press any key . . ."
    try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
}

# ---------------------------------------------------------------------------
#  Windows software through winget
# ---------------------------------------------------------------------------
function Install-Winget {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    Write-Host ""
    if ($null -eq $winget) {
        Write-Host "  winget is not on this machine, so Windows software cannot be" -ForegroundColor Yellow
        Write-Host "  installed from here. It comes with App Installer from the Microsoft" -ForegroundColor Yellow
        Write-Host "  Store on Windows 10 and 11." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Press any key . . ."
        try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
        return
    }

    Write-Host "  This installs real Windows software onto this computer. It is the one"
    Write-Host "  thing in starpOS that changes the machine outside its own folder."
    Write-Host ""
    Write-Host "  1. Search for something"
    Write-Host "  2. Install by package id"
    Write-Host "  0. Back"
    $k = Ask "Pick" "1"
    if ($null -eq $k -or $k -eq "0") { return }

    if ($k -eq "1") {
        $term = Ask "Search for"
        if ($null -eq $term -or $term -eq "") { return }
        Write-Host ""
        Write-Host "  Searching..." -ForegroundColor Gray
        Write-Host ""
        try { & winget search --query $term | Select-Object -First 25 } catch {
            Write-Host "  winget search failed." -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "  Note the Id column, then come back and pick option 2."
        Write-Host ""
        Write-Host "  Press any key . . ."
        try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
        return
    }

    $id = Ask "Package id"
    if ($null -eq $id -or $id -eq "") { return }

    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Yellow
    Write-Host "  About to run:  winget install --id $id" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  This downloads and installs software onto this computer. It is not" -ForegroundColor Yellow
    Write-Host "  undone by anything in starpOS - you would uninstall it through Windows." -ForegroundColor Yellow
    Write-Host "===============================================================================" -ForegroundColor Yellow
    Write-Host ""
    $c = Ask "Type YES to go ahead"
    if ($c -ne "YES") {
        Write-Host "  Cancelled, nothing was installed." -ForegroundColor Gray
        Start-Sleep -Seconds 2
        return
    }

    Write-StarpLog ("winget install requested: " + $id)
    Write-Host ""
    try {
        & winget install --id $id --accept-package-agreements --accept-source-agreements
        Write-Host ""
        Write-Host "  winget has finished. Check above for whether it worked." -ForegroundColor Green
        Write-StarpLog ("winget install finished: " + $id)
    } catch {
        Write-Host ("  [ ERROR ] " + $_.Exception.Message) -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "  Press any key . . ."
    try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
}

# ---------------------------------------------------------------------------
#  Take an app back off the desktop
# ---------------------------------------------------------------------------
function Uninstall-App {
    $entries = @(Get-MenuEntries)
    Write-Host ""
    if ($entries.Count -eq 0) {
        Write-Host "  Nothing is on the menu." -ForegroundColor Gray
        Start-Sleep -Seconds 2
        return
    }
    foreach ($e in $entries) {
        Write-Host ("   " + $e.Slot.PadRight(4) + $e.Label.PadRight(26) + $e.Type.PadRight(9) + $e.Target)
    }
    Write-Host ""
    $slot = Ask "Remove which key from the desktop (Enter to cancel)"
    if ($null -eq $slot -or $slot -eq "") { return }

    $hit = $null
    foreach ($e in $entries) { if ($e.Slot.ToLower() -eq $slot.ToLower()) { $hit = $e } }
    if ($null -eq $hit) {
        Write-Host "  No menu entry uses that key." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return
    }

    Write-Host ""
    Write-Host ("  This only takes '" + $hit.Label + "' off the desktop.") -ForegroundColor Yellow
    Write-Host "  The file itself is left exactly where it is." -ForegroundColor Yellow
    $c = Ask "Type YES to confirm"
    if ($c -ne "YES") {
        Write-Host "  Cancelled." -ForegroundColor Gray
        Start-Sleep -Seconds 2
        return
    }

    try {
        if (-not (Test-Path -LiteralPath $backup)) { New-Item -ItemType Directory -Path $backup -Force | Out-Null }
        Copy-Item -LiteralPath $menuPath -Destination (Join-Path $backup ("menu.cfg." + (Get-Date -Format "yyyyMMdd-HHmmss") + ".bak")) -Force
    } catch { }

    try {
        $out = @()
        foreach ($line in (Get-Content -LiteralPath $menuPath)) {
            if ($line.Trim() -eq $hit.Raw) {
                $out += ("# removed by install.ps1 on " + (Get-Date -Format "yyyy-MM-dd") + ":")
                $out += ("# " + $line)
            } else { $out += $line }
        }
        Set-Content -LiteralPath $menuPath -Value $out -Encoding ASCII -ErrorAction Stop
        Write-Host ""
        Write-Host ("  [ OK ] '" + $hit.Label + "' taken off the desktop. Its line is commented out in") -ForegroundColor Green
        Write-Host "         menu.cfg, so you can put it back by deleting the #." -ForegroundColor Green
        Write-StarpLog ("Removed '" + $hit.Label + "' from the desktop")
    } catch {
        Write-Host "  [ ERROR ] could not update menu.cfg" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "  Press any key . . ."
    try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
}

# ---------------------------------------------------------------------------
#  Menu
# ---------------------------------------------------------------------------
$emptyRuns = 0
while ($true) {

    try {
        $host.UI.RawUI.WindowTitle = "starpOS Installer"
        Clear-Host
    } catch { }

    Write-Host "==============================================================================="
    Write-Host "  starpOS APP INSTALLER                                    DEVELOPER MODE"
    Write-Host "==============================================================================="
    Write-Host ""
    Write-Host "   1  Install a program from this computer   (.bat .ps1 .vbs .exe .lnk)"
    Write-Host "   2  Install a website or folder as an app"
    Write-Host "   3  Install Windows software with winget"
    Write-Host "   4  List what is on the desktop"
    Write-Host "   5  Take an app off the desktop"
    Write-Host "   0  Back to the developer menu"
    Write-Host ""
    Write-Host "==============================================================================="
    Write-Host ""
    Write-Host -NoNewline "  install> "

    $pick = ""
    try { $pick = [string](Read-Host) } catch { break }
    $pick = $pick.Trim()

    if ($pick -eq "") {
        $emptyRuns++
        if ($emptyRuns -ge 30) { break }
        continue
    }
    $emptyRuns = 0

    switch ($pick) {
        "0" { return }
        "1" { Install-LocalFile }
        "2" { Install-Shortcut }
        "3" { Install-Winget }
        "4" {
            Write-Host ""
            foreach ($e in @(Get-MenuEntries)) {
                Write-Host ("   " + $e.Slot.PadRight(4) + $e.Label.PadRight(26) + $e.Type.PadRight(9) + $e.Target)
            }
            Write-Host ""
            Write-Host "  Press any key . . ."
            try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
        }
        "5" { Uninstall-App }
        default {
            Write-Host "  Not an option." -ForegroundColor Yellow
            Start-Sleep -Milliseconds 900
        }
    }
}

Write-Host ""
Write-Host "  Installer closed."
if (-not $NoPause) {
    Write-Host ""
    Write-Host "Press any key to return to starpOS . . ."
    try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
}
