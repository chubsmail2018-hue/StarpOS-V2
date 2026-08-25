@echo off
title starpOS Voice Recognition System

:: Lock incoming log pointers to prevent any window close errors
set "v_s1=%~1"
set "u_s3=%~3"

:listening_loop
cls
color 0E
echo ===============================================================================
echo                      starpOS VOICE RECOGNITION CONTROL CENTER
echo ===============================================================================
echo.
echo   [ STATUS ] Microphone Active. Listening for your spoken commands...
echo.
echo   SPEAK NOW:
echo    1. Say "starpOS"   - To trigger an official system vocal greeting.
echo    2. Say "Open File" - To instantly launch the File Explorer menu.
echo    3. Say "Exit"      - To close the voice engine and return to desktop.
echo.
echo ===============================================================================

:: Dynamic PowerShell script that hooks into your microphone and listens for specific phrases
powershell -Command " + ^
    $choices = New-Object System.Speech.Recognition.Choices; + ^
    $choices.Add(@('starpOS', 'Open File', 'Exit')); + ^
    $gb = New-Object System.Speech.Recognition.GrammarBuilder; + ^
    $gb.Append($choices); + ^
    $grammar = New-Object System.Speech.Recognition.Grammar($gb); + ^
    $recognizer = New-Object System.Speech.Recognition.SpeechRecognitionEngine; + ^
    $recognizer.LoadGrammar($grammar); + ^
    $recognizer.SetInputToDefaultAudioDevice(); + ^
    echo '[ LISTENING ] Voice matrix processing active...'; + ^
    $result = $recognizer.Recognize(); + ^
    Write-Output $result.Text" > "%temp%\voice_cmd.txt"

:: Read what word was captured by your microphone
set /p voice_action=<"%temp%\voice_cmd.txt"
del "%temp%\voice_cmd.txt"

:: Check the recognized voice command and route it without crashing
if "%voice_action%"=="starpOS" goto voice_greetings
if "%voice_action%"=="Open File" goto voice_explorer
if "%voice_action%"=="Exit" goto voice_exit
goto listening_loop

:voice_greetings
if not "%v_s1%"=="" echo [%TIME%] [VOICE_CMD] User spoke name keyword: starpOS >> "%v_s1%"
cls
echo [ VOICE ] Command Recognized: "starpOS"
echo.
echo CreateObject("SAPI.SpVoice").Speak "Yes Boss. I am listening. All starpOS core systems are fully online and tracking your speech parameters smoothly." > "%temp%\talk.vbs"
cscript //nologo "%temp%\talk.vbs"
del "%temp%\talk.vbs"
goto listening_loop

:voice_explorer
if not "%v_s1%"=="" echo [%TIME%] [VOICE_CMD] User spoke file command: Open File >> "%v_s1%"
cls
echo [ VOICE ] Command Recognized: "Open File"
echo.
echo CreateObject("SAPI.SpVoice").Speak "Opening file explorer application window now." > "%temp%\talk.vbs"
cscript //nologo "%temp%\talk.vbs"
del "%temp%\talk.vbs"
cls
title starpOS File Explorer
echo === FILE EXPLORER ===
dir /b ..
echo.
pause
goto listening_loop

:voice_exit
cls
echo CreateObject("SAPI.SpVoice").Speak "Exiting voice control system." > "%temp%\talk.vbs"
cscript //nologo "%temp%\talk.vbs"
del "%temp%\talk.vbs"
exit /b
