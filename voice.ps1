# ===========================================================================
#  voice.ps1  -  starpOS voice control engine
# ===========================================================================
#  A real speech engine for starpOS. It reads voice.cmds, builds a speech
#  recognition grammar out of the phrases in it, listens on the microphone,
#  and runs whatever the matching line says to run. Adding a spoken command
#  means adding a line to voice.cmds. There is nothing to change in here.
#
#  If there is no microphone, no recogniser for your language, or no sound
#  card at all, it drops to a typed command panel instead of falling over.
#
#  Run it:
#     powershell -NoProfile -ExecutionPolicy Bypass -File "voice.ps1"
#
#  Useful switches:
#     -Typed        skip the microphone, go straight to typed commands
#     -ListVoices   show every speech voice installed on this machine
#     -Log "..\data\1.log"   append every recognised command to a log stream
# ===========================================================================

[CmdletBinding()]
param(
    [string]$Commands = "voice.cmds",
    [string]$Config   = "starpos.cfg",
    [string]$Log      = "",
    [switch]$Typed,
    [switch]$ListVoices
)

$ErrorActionPreference = "Continue"
$here = Split-Path -Parent $MyInvocation.MyCommand.Definition

function Resolve-Local {
    param([string]$Path)
    if ($Path -eq "") { return $Path }
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path $here $Path)
}

$Commands = Resolve-Local $Commands
$Config   = Resolve-Local $Config
if ($Log -ne "") { $Log = Resolve-Local $Log }

# --- Logging ----------------------------------------------------------------
function Write-Log {
    param([string]$Message)
    if ($Log -eq "") { return }
    try {
        $stamp = "[" + (Get-Date -Format "HH:mm:ss.ff") + "] [VOICE_CMD] "
        Add-Content -LiteralPath $Log -Value ($stamp + $Message) -Encoding ASCII -ErrorAction Stop
    } catch { }
}

# --- Settings ---------------------------------------------------------------
$osName = "starpOS"
$rate   = 0
$volume = 100
if (Test-Path -LiteralPath $Config) {
    foreach ($line in (Get-Content -LiteralPath $Config)) {
        $t = $line.Trim()
        if ($t -eq "" -or $t.StartsWith("#")) { continue }
        $i = $t.IndexOf("=")
        if ($i -lt 1) { continue }
        $k = $t.Substring(0, $i).Trim()
        $v = $t.Substring($i + 1).Trim()
        if ($k -eq "OS_NAME")      { $osName = $v }
        if ($k -eq "VOICE_RATE")   { if ($v -match '^-?\d+$') { $rate   = [int]$v } }
        if ($k -eq "VOICE_VOLUME") { if ($v -match '^\d+$')   { $volume = [int]$v } }
    }
}

# --- Speech output ----------------------------------------------------------
$tts = $null
try {
    Add-Type -AssemblyName System.Speech -ErrorAction Stop
    $tts = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $tts.Rate   = [math]::Max(-10, [math]::Min(10, $rate))
    $tts.Volume = [math]::Max(0, [math]::Min(100, $volume))
} catch {
    $tts = $null
}

function Say {
    param([string]$Text)
    if ($null -eq $tts -or $Text -eq "") { return }
    try { $tts.Speak($Text) } catch { }
}

if ($ListVoices) {
    Write-Host ""
    Write-Host "  Speech voices installed on this machine:"
    Write-Host ""
    if ($null -eq $tts) {
        Write-Host "  [ STARP-0501 ] No speech engine available."
    } else {
        foreach ($v in $tts.GetInstalledVoices()) {
            $info = $v.VoiceInfo
            $state = "disabled"
            if ($v.Enabled) { $state = "enabled" }
            Write-Host ("   - {0}  ({1}, {2}, {3})" -f $info.Name, $info.Gender, $info.Culture.Name, $state)
        }
    }
    Write-Host ""
    return
}

# --- Command registry -------------------------------------------------------
# Each entry: Phrase, Action, Target, Reply
$registry = @()
if (Test-Path -LiteralPath $Commands) {
    foreach ($line in (Get-Content -LiteralPath $Commands)) {
        $t = $line.Trim()
        if ($t -eq "" -or $t.StartsWith("#")) { continue }
        $parts = $t.Split("|")
        if ($parts.Count -lt 2) { continue }
        $entry = New-Object PSObject
        $entry | Add-Member NoteProperty Phrase $parts[0].Trim()
        $entry | Add-Member NoteProperty Action $parts[1].Trim().ToLower()
        $target = ""
        $reply  = ""
        if ($parts.Count -gt 2) { $target = $parts[2].Trim() }
        if ($parts.Count -gt 3) { $reply  = $parts[3].Trim() }
        $entry | Add-Member NoteProperty Target $target
        $entry | Add-Member NoteProperty Reply  $reply
        if ($entry.Phrase -ne "") { $registry += $entry }
    }
}

if ($registry.Count -eq 0) {
    Write-Host ""
    Write-Host "  [ STARP-0502 ] No commands loaded. Check that voice.cmds is in the system folder."
    Write-Host ""
    Say "Voice command file missing. The voice engine cannot start."
    return
}

# --- Speech input -----------------------------------------------------------
$asr     = $null
$micReady = $false
if (-not $Typed) {
    try {
        Add-Type -AssemblyName System.Speech -ErrorAction Stop
        $choices = New-Object System.Speech.Recognition.Choices
        foreach ($entry in $registry) { $choices.Add($entry.Phrase) }
        $builder = New-Object System.Speech.Recognition.GrammarBuilder
        $builder.Append($choices)
        $asr = New-Object System.Speech.Recognition.SpeechRecognitionEngine
        $asr.LoadGrammar((New-Object System.Speech.Recognition.Grammar $builder))
        $asr.SetInputToDefaultAudioDevice()
        $micReady = $true
    } catch {
        # No recogniser for this culture, or no microphone. Type instead.
        if ($null -ne $asr) { try { $asr.Dispose() } catch { }; $asr = $null }
        $micReady = $false
    }
}

# --- Screen -----------------------------------------------------------------
function Draw-Banner {
    try {
        $host.UI.RawUI.WindowTitle = "$osName Voice Control"
        Clear-Host
    } catch { }
    Write-Host "==============================================================================="
    Write-Host "                     $osName VOICE RECOGNITION CONTROL CENTER"
    Write-Host "==============================================================================="
    Write-Host ""
    if ($micReady) {
        Write-Host "  [ STATUS ] Microphone active. Say a command out loud."
    } else {
        Write-Host "  [ STATUS ] No microphone or speech recogniser. Typed command panel on."
    }
    if ($null -eq $tts) {
        Write-Host "  [ STARP-0501 ] No voice output on this machine. Replies are text only."
    }
    Write-Host ""
    Write-Host "  THINGS YOU CAN SAY:"
    foreach ($entry in $registry) {
        Write-Host ("    `"{0}`"" -f $entry.Phrase)
    }
    Write-Host ""
    Write-Host "  (type ? to redraw this list, or exit to leave)"
    Write-Host "==============================================================================="
    Write-Host ""
}

# --- Input ------------------------------------------------------------------
function Get-Spoken {
    if ($micReady) {
        Write-Host "  [ LISTENING ] Speak now..."
        try {
            $result = $asr.Recognize([TimeSpan]::FromSeconds(15))
            if ($null -eq $result) { return "" }
            Write-Host ("  [ HEARD ] " + $result.Text)
            return $result.Text
        } catch {
            # The device dropped out mid session. Fall back for good.
            $script:micReady = $false
            Write-Host ""
            Write-Host "  [ NOTICE ] Microphone lost. Switching to the typed panel..."
            Start-Sleep -Seconds 2
            return ""
        }
    }
    Write-Host -NoNewline "  $osName voice> "
    try { return [string](Read-Host) } catch { return "exit" }
}

# --- Actions ----------------------------------------------------------------
function Invoke-Entry {
    param($Entry)

    Write-Log ("Recognised: " + $Entry.Phrase)
    Say $Entry.Reply

    switch ($Entry.Action) {

        "say" { }

        "show" {
            $path = Resolve-Local $Entry.Target
            Write-Host ""
            if (Test-Path -LiteralPath $path) {
                Get-Content -LiteralPath $path | ForEach-Object { Write-Host $_ }
            } else {
                Write-Host ("  [ STARP-0402 ] File not found: " + $Entry.Target)
            }
        }

        "list" {
            $path = Resolve-Local $Entry.Target
            Write-Host ""
            if (Test-Path -LiteralPath $path) {
                Write-Host ("  " + (Resolve-Path -LiteralPath $path).Path)
                Write-Host ""
                foreach ($item in (Get-ChildItem -LiteralPath $path -ErrorAction SilentlyContinue)) {
                    if ($item.PSIsContainer) {
                        Write-Host ("   [DIR]  " + $item.Name)
                    } else {
                        Write-Host ("          " + $item.Name)
                    }
                }
            } else {
                Write-Host ("  [ STARP-0201 ] Folder not found: " + $Entry.Target)
            }
        }

        "run" {
            $target = $Entry.Target
            $path   = Resolve-Local $target
            Write-Host ""
            try {
                if ($target -like "*.ps1") {
                    if (Test-Path -LiteralPath $path) {
                        & powershell -NoProfile -ExecutionPolicy Bypass -File $path
                    } else {
                        Write-Host ("  [ STARP-0401 ] Missing: " + $target)
                    }
                } elseif ($target -like "*.bat" -or $target -like "*.cmd") {
                    if (Test-Path -LiteralPath $path) {
                        # Batch apps expect to run from the system folder.
                        Push-Location $here
                        & cmd /c $path
                        Pop-Location
                    } else {
                        Write-Host ("  [ STARP-0401 ] Missing: " + $target)
                    }
                } else {
                    # A plain command such as tasklist.
                    Push-Location $here
                    & cmd /c $target
                    Pop-Location
                }
            } catch {
                Write-Host ("  [ STARP-0403 ] That command stopped early: " + $_.Exception.Message)
            }
        }

        default {
            Write-Host ("  [ STARP-0402 ] Unknown action in voice.cmds: " + $Entry.Action)
        }
    }

    Write-Host ""
    Write-Host "  Press any key to keep listening . . ."
    try { $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { try { $null = Read-Host } catch { } }
}

# --- Main loop --------------------------------------------------------------
Draw-Banner
Write-Log "Voice engine started"
Say "Voice control online."

# Counts silences in a row. In typed mode a closed input stream makes
# Read-Host return nothing every single time, which would redraw the banner
# forever; on the microphone this is genuine silence. Either way, after
# enough empty turns in a row the engine gives up rather than spinning.
$emptyRuns = 0
$emptyLimit = 30

while ($true) {

    $spoken = Get-Spoken
    if ($null -eq $spoken) { $spoken = "" }
    $spoken = $spoken.Trim()

    if ($spoken -eq "") {
        $emptyRuns = $emptyRuns + 1
        if ($emptyRuns -ge $emptyLimit) {
            Write-Host ""
            Write-Host "  [ INFO ] Nothing heard for a long time. Closing voice control."
            Write-Log "Voice engine closed after $emptyLimit empty turns"
            break
        }
        Draw-Banner
        continue
    }

    $emptyRuns = 0

    if ($spoken -eq "?") { Draw-Banner; continue }

    $match = $null
    foreach ($entry in $registry) {
        if ([string]::Equals($entry.Phrase, $spoken, [StringComparison]::OrdinalIgnoreCase)) {
            $match = $entry
            break
        }
    }

    if ($null -eq $match) {
        Write-Log ("Unrecognised: " + $spoken)
        Write-Host ""
        Write-Host ("  [ STARP-0504 ] Command not recognised: `"" + $spoken + "`"")
        Say "Command not recognized. Please try again."
        Start-Sleep -Milliseconds 1200
        Draw-Banner
        continue
    }

    if ($match.Action -eq "exit") {
        Write-Log "Voice engine closed by user"
        Say $match.Reply
        break
    }

    Invoke-Entry $match
    Draw-Banner
}

# --- Shutdown ---------------------------------------------------------------
if ($null -ne $asr) { try { $asr.Dispose() } catch { } }
if ($null -ne $tts) { try { $tts.Dispose() } catch { } }
Write-Host ""
Write-Host "  Voice engine closed."
