@echo off
title starpOS Voice Control Center

:: Lock incoming log pointers to completely prevent window close errors
set "v_s1=%~1"
set "v_s3=%~3"

:listening_loop
cls
color 0E
echo ===============================================================================
echo                      starpOS VOICE PROCESSOR SYSTEM
echo ===============================================================================
echo.
echo   [ STATUS ] Voice Command Portal Initialized.
echo.
echo   INSTRUCTIONS:
echo    A pop-up text entry windows will launch to process your voice inquiries.
echo.
echo   VALID COMMAND TARGETS:
echo    - "starpOS"   - To trigger an official system vocal response.
echo    - "Open File" - To instantly navigate into the File Explorer directory.
echo    - "Exit"      - To safely shut down the processing engine.
echo.
echo ===============================================================================
echo [ VOICE ] Opening input gateway interface...

:: Generate a stable visual input panel via an integrated VBS execution line
echo input = InputBox("starpOS Voice Input Portal" & vbCrLf & "Speak or type your command string below:", "starpOS Voice Control") > "%temp%\v_input.vbs"
echo WScript.Echo input >> "%temp%\v_input.vbs"

for /f "delims=" %%A in ('cscript //nologo "%temp%\v_input.vbs"') do set "voice_action=%%A"
del "%temp%\v_input.vbs"

:: Guard rule loops the script gracefully if the user cancels or submits empty lines
if "%voice_action%"=="" goto listening_loop

:: Route the input strings safely without any device parameter errors
if /I "%voice_action%"=="starpOS" goto voice_greetings
if /I "%voice_action%"=="Open File" goto voice_explorer
if /I "%voice_action%"=="Exit" 
cls
echo [ VOICE ] Unrecognized Command Matrix: "%voice_action%"
echo CreateObject("SAPI.SpVoice").Speak "." > "%temp%\talk.vbs"
cscript //nologo "%temp%\talk.vbs"
del "%temp%\talk.vbs"
goto listening_loop

:voice_greetings
if not "%v_s1%"=="" echo [%TIME%] [VOICE_CMD] User invoked system keyword profile >> "%v_s1%"
cls
echo [ VOICE ] Command Recognized: "starpOS"
echo CreateObject("SAPI.SpVoice").Speak "Yes Boss. I am online and running under your full authority. All data streams are performing flawlessly." > "%temp%\talk.vbs"
cscript //nologo "%temp%\talk.vbs"
del "%temp%\talk.vbs"
goto listening_loop

:voice_explorer
if not "%v_s1%"=="" echo [%TIME%] [VOICE_CMD] User invoked system folder shortcut >> "%v_s1%"
cls
echo [ VOICE ] Command Recognized: "Open File"
echo CreateObject("SAPI.SpVoice").Speak "Opening file explorer application map directories now." > "%temp%\talk.vbs"
cscript //nologo "%temp%\talk.vbs"
del "%temp%\talk.vbs"
cls
title starpOS File Explorer
echo === FILE EXPLORER ===
echo.
dir /b ..
echo.
pause
goto listening_loop

:voice_exit
cls
echo CreateObject("SAPI.SpVoice").Speak "Exiting voice processor control center system." > "%temp%\talk.vbs"
cscript //nologo "%temp%\talk.vbs"
del "%temp%\talk.vbs"
exit /b
