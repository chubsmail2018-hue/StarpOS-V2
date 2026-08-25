@echo off
setlocal enabledelayedexpansion
title starpOS Voice Recognition System

:: ===========================================================================
::  starpOS Voice Control Center
::  Usage: Voice.bat [primary_log] [reserved] [secondary_log]
::  Live microphone recognition with an automatic typed-input fallback.
:: ===========================================================================

set "v_s1=%~1"
set "v_s3=%~3"
set "V_ROOT=%~dp0"
set "V_TMP=%TEMP%\starpos_voice_result.txt"
set "V_VBS=%TEMP%\starpos_voice_say.vbs"
set "V_ASK=%TEMP%\starpos_voice_ask.vbs"

:: MIC = live speech recognition, TEXT = typed command panel
set "VOICE_MODE=MIC"

:: Counts consecutive listens that heard nothing, so a dead microphone can be
:: called out instead of looking like a recogniser that simply never matches.
set "V_SILENT=0"

:: Speak on launch: if this is not audible, the fault is the audio output and
:: not the recogniser, which is otherwise impossible to tell apart.
call :say "starpOS voice control online."

:listening_loop
cls
color 0E
echo ===============================================================================
echo                      starpOS VOICE RECOGNITION CONTROL CENTER
echo ===============================================================================
echo.
if /I "!VOICE_MODE!"=="MIC" (
    echo   [ STATUS ] Microphone active. Listening for your spoken commands...
) else (
    echo   [ STATUS ] Speech engine unavailable. Typed command panel engaged.
)
echo.
echo   COMMANDS ^(say any wording on a line^):
echo    1. "starpOS"   / "computer" / "hello"     - vocal greeting.
echo    2. "Open File" / "file explorer"          - list the folder.
echo    3. "Exit"      / "quit" / "goodbye"       - close the engine.
echo.
echo ===============================================================================
echo.

set "voice_action="
if /I "!VOICE_MODE!"=="MIC" (call :listen_mic) else (call :listen_text)

:: A silent listen offers a keyboard escape before re-arming the microphone, so
:: the session is never trapped waiting on speech the recogniser cannot hear.
if not defined voice_action if /I "!VOICE_MODE!"=="MIC" goto silent_prompt
if not defined voice_action goto listening_loop

set "V_SILENT=0"

:route_command
if /I "!voice_action!"=="starpOS"   goto voice_greetings
if /I "!voice_action!"=="Open File" goto voice_explorer
if /I "!voice_action!"=="Exit"      goto voice_exit
goto voice_unknown

:silent_prompt
set /a V_SILENT+=1
echo.
if !V_SILENT! GEQ 2 (
    echo   [ NOTICE ] Nothing has reached the microphone yet. Check that a mic is
    echo              plugged in and not muted, and that it is the default
    echo              recording device in Windows Sound settings.
    echo.
)
choice /C TQL /N /T 5 /D L /M "  [T] Type a command   [Q] Quit   (resume listening in 5s): "
if errorlevel 3 goto listening_loop
if errorlevel 2 goto voice_exit
call :listen_text
if not defined voice_action goto listening_loop
set "V_SILENT=0"
goto route_command

:: ---------------------------------------------------------------------------
:: Live microphone capture. PowerShell maps every accepted wording back onto one
:: of the three real commands, so the batch only ever sees a canonical name.
:: Exit code 2 means no usable speech engine or mic, which permanently drops the
:: session into the typed panel instead of looping on an error nobody can clear.
:: ---------------------------------------------------------------------------
:listen_mic
del "%V_TMP%" >nul 2>nul
echo   [ LISTENING ] Voice matrix processing active. Speak now...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Speech; $m = @{}; foreach ($p in @('starpOS','star pos','star p o s','star oh s','star boss','computer','system','hello','are you there')) { $m[$p] = 'starpOS' }; foreach ($p in @('open file','open files','file explorer','open explorer','show files','list files')) { $m[$p] = 'Open File' }; foreach ($p in @('exit','quit','close','shut down','goodbye','stop listening')) { $m[$p] = 'Exit' }; try { $c = New-Object System.Speech.Recognition.Choices; $c.Add([string[]]@($m.Keys)); $gb = New-Object System.Speech.Recognition.GrammarBuilder; $gb.Append($c); $r = New-Object System.Speech.Recognition.SpeechRecognitionEngine; $r.LoadGrammar((New-Object System.Speech.Recognition.Grammar $gb)); $r.SetInputToDefaultAudioDevice() } catch { exit 2 }; $res = $null; try { $res = $r.Recognize([TimeSpan]::FromSeconds(10)) } catch { }; try { $r.Dispose() } catch { }; if ($res) { [Console]::Out.Write($m[$res.Text]) }" > "%V_TMP%" 2>nul
set "V_ERR=!ERRORLEVEL!"
if !V_ERR! GEQ 2 (
    del "%V_TMP%" >nul 2>nul
    set "VOICE_MODE=TEXT"
    echo.
    echo   [ NOTICE ] No speech recognizer or microphone detected.
    echo   [ NOTICE ] Switching to the typed command panel...
    ping -n 3 127.0.0.1 >nul
    goto :eof
)
if exist "%V_TMP%" set /p voice_action=<"%V_TMP%"
del "%V_TMP%" >nul 2>nul
goto :eof

:: ---------------------------------------------------------------------------
:: Typed command panel, used as the fallback and as the keyboard escape.
:: ---------------------------------------------------------------------------
:listen_text
> "%V_ASK%" echo input = InputBox("starpOS Voice Input Portal" ^& vbCrLf ^& "Speak or type your command below:", "starpOS Voice Control")
>>"%V_ASK%" echo WScript.Echo input
for /f "usebackq delims=" %%A in (`cscript //nologo "%V_ASK%"`) do set "voice_action=%%A"
del "%V_ASK%" >nul 2>nul
call :canonical
goto :eof

:: Folds a typed wording onto a canonical command name.
:canonical
if not defined voice_action goto :eof
for %%W in (starpOS "star pos" computer system hello) do if /I "!voice_action!"=="%%~W" set "voice_action=starpOS"
for %%W in ("open file" "open files" "file explorer" "open explorer" "show files" "list files") do if /I "!voice_action!"=="%%~W" set "voice_action=Open File"
for %%W in (exit quit close "shut down" goodbye "stop listening") do if /I "!voice_action!"=="%%~W" set "voice_action=Exit"
goto :eof

:: ---------------------------------------------------------------------------
:: Spoken output helper. Call as: call :say "Sentence to speak."
:: ---------------------------------------------------------------------------
:say
> "%V_VBS%" echo CreateObject("SAPI.SpVoice").Speak %1
cscript //nologo "%V_VBS%" >nul 2>nul
del "%V_VBS%" >nul 2>nul
:: Let the speakers fall quiet before listening resumes. Every reply says
:: "starpOS", and the microphone will happily recognise our own wake word.
ping -n 2 127.0.0.1 >nul
goto :eof

:: ---------------------------------------------------------------------------
:: Log helper. Call as: call :log "message"
:: ---------------------------------------------------------------------------
:log
if not "%v_s1%"=="" echo [%TIME%] [VOICE_CMD] %~1 >> "%v_s1%"
if not "%v_s3%"=="" echo [%TIME%] [VOICE_CMD] %~1 >> "%v_s3%"
goto :eof

:voice_greetings
call :log "User spoke name keyword: starpOS"
cls
echo [ VOICE ] Command Recognized: "starpOS"
echo.
call :say "Yes Boss. I am here."
goto listening_loop

:voice_explorer
call :log "User spoke file command: Open File"
cls
title starpOS File Explorer
echo [ VOICE ] Command Recognized: "Open File"
echo.
call :say "Opening file explorer application window now."
echo === FILE EXPLORER ===
echo.
dir /b "%V_ROOT%.."
echo.
pause
title starpOS Voice Recognition System
goto listening_loop

:voice_unknown
call :log "Unrecognized command"
cls
echo [ VOICE ] Unrecognized Command Matrix: "!voice_action!"
echo.
call :say "Command not recognized. Please try again."
ping -n 2 127.0.0.1 >nul
goto listening_loop

:voice_exit
call :log "User closed the voice engine"
cls
echo [ VOICE ] Shutting down voice engine...
call :say "Exiting voice control system."
del "%V_TMP%" >nul 2>nul
del "%V_VBS%" >nul 2>nul
del "%V_ASK%" >nul 2>nul
endlocal
exit /b 0
