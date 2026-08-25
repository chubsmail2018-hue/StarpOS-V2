@echo off

:: -------------------------------------------------------------------------------
:: LOG ARCHITECTURE: Protect tracking paths using steady global references
:: -------------------------------------------------------------------------------
if not "%~1"=="" set "_s1=%~1"
if not "%~3"=="" set "_s3=%~3"

:: -------------------------------------------------------------------------------
:: USER PROFILE LOGIN SYSTEM (Boot Gate)
:: -------------------------------------------------------------------------------
:login_screen
cls
color 0E
title starpOS Authentication Portal

echo ===============================================================================
echo                starpOS USER AUTHENTICATION SECURE PORTAL
echo ===============================================================================
echo.
echo  Enter account security credentials below:
echo.

:: Clear fields before prompts to prevent blank Enter key crashes
set "input_user="
set "input_pass="
set /p input_user=" Username: "
set /p input_pass=" Password: "

:: Rigid quote verification to guarantee stability
if "%input_user%"=="Admin" (
    if "%input_pass%"=="1234" (
        if not "%_s1%"=="" echo [%TIME%] [AUTH] Successfully authenticated user: Admin >> "%_s1%"
        if not "%_s3%"=="" echo [%TIME%] [AUTH] Successfully authenticated user: Admin >> "%_s3%"
        echo.
        echo [ OK ] Access Granted! Loading desktop profile...
        
        :: Inline VBS Voice Execution
        echo CreateObject("SAPI.SpVoice").Speak "Access Granted. Welcome back, Admin." > "%temp%\talk.vbs"
        cscript //nologo "%temp%\talk.vbs"
        del "%temp%\talk.vbs"
        
        goto desktop
    )
)

:: Log failed entries safely without closing the command window
if not "%_s1%"=="" echo [%TIME%] [SECURITY_ALERT] Failed login attempt for user: "%input_user%" >> "%_s1%"
if not "%_s3%"=="" echo [%TIME%] [SECURITY_ALERT] Failed login attempt for user: "%input_user%" >> "%_s3%"

echo CreateObject("SAPI.SpVoice").Speak "Access denied. Invalid credentials." > "%temp%\talk.vbs"
cscript //nologo "%temp%\talk.vbs"
del "%temp%\talk.vbs"

echo.
echo [ ERROR ] Invalid username or password! Please try again.
pause
goto login_screen

:: -------------------------------------------------------------------------------
:: MAIN DESKTOP INTERFACE ENVIRONMENT
:: -------------------------------------------------------------------------------
:desktop
cls
color 2A
title %OS_NAME% Desktop (v%OS_VERSION%)

echo ===============================================================================
echo  %OS_NAME% Desktop                                         Logged in as: Admin
echo ===============================================================================
echo.
echo    1. File Explorer      2. Notepad             3. System Info
echo    4. Command Prompt     5. Settings            6. Shut Down
echo    7. Launch AI Assistant (ai.bat)
echo.
echo ===============================================================================
echo [START] Type a number (1-7) and press Enter to select an app.
echo ===============================================================================
echo.

set "choice="
set /p choice="starpOS> "

:: Prompt protection: prevents window from closing if input is blank
if "%choice%"=="" goto desktop

:: Safe logging output strings using double quotes
if not "%_s1%"=="" echo [%TIME%] [INP] Value: "%choice%" >> "%_s1%"
if not "%_s3%"=="" echo [%TIME%] [INP] Value: "%choice%" >> "%_s3%"

if "%choice%"=="1" goto explorer
if "%choice%"=="2" goto notepad
if "%choice%"=="3" goto sysinfo
if "%choice%"=="4" goto cmdprompt
if "%choice%"=="5" goto settings
if "%choice%"=="6" goto shutdown
if "%choice%"=="7" goto launch_ai

:: Catch invalid inputs smoothly
if not "%_s1%"=="" echo [%TIME%] [WARNING] Invalid command attempt: "%choice%" >> "%_s1%"
if not "%_s3%"=="" echo [%TIME%] [WARNING] Invalid command attempt: "%choice%" >> "%_s3%"
goto desktop

:explorer
if not "%_s1%"=="" echo [%TIME%] [ACT] Navigated Explorer >> "%_s1%"
if not "%_s3%"=="" echo [%TIME%] [ACT] Navigated Explorer >> "%_s3%"
cls
title starpOS File Explorer
echo CreateObject("SAPI.SpVoice").Speak "Opening file explorer." > "%temp%\talk.vbs"
cscript //nologo "%temp%\talk.vbs"
del "%temp%\talk.vbs"
echo === FILE EXPLORER ===
echo.
dir /b ..
echo.
pause
goto desktop

:notepad
if not "%_s1%"=="" echo [%TIME%] [ACT] Opened Notepad >> "%_s1%"
if not "%_s3%"=="" echo [%TIME%] [ACT] Opened Notepad >> "%_s3%"
cls
title starpOS Notepad
echo CreateObject("SAPI.SpVoice").Speak "Notepad ready." > "%temp%\talk.vbs"
cscript //nologo "%temp%\talk.vbs"
del "%temp%\talk.vbs"
echo === NOTEPAD ===
echo Type your note below.
echo.
set "note="
set /p note="Text: "
if not "%_s1%"=="" echo [%TIME%] [DATA] Str: "%note%" >> "%_s1%"
if not "%_s3%"=="" echo [%TIME%] [DATA] Str: "%note%" >> "%_s3%"
goto desktop

:sysinfo
cls
title starpOS System Info
echo CreateObject("SAPI.SpVoice").Speak "Displaying system properties." > "%temp%\talk.vbs"
cscript //nologo "%temp%\talk.vbs"
del "%temp%\talk.vbs"
echo === SYSTEM INFORMATION ===
echo OS Name: %OS_NAME%
echo Version: %OS_VERSION%
echo Architecture: Batch 64-bit Emulation
echo Status: Running smoother than Windows
echo.
pause
goto desktop

:cmdprompt
if not "%_s1%"=="" echo [%TIME%] [SHL] Console Open >> "%_s1%"
if not "%_s3%"=="" echo [%TIME%] [SHL] Console Open >> "%_s3%"
cls
title starpOS Command Line
echo CreateObject("SAPI.SpVoice").Speak "Terminal shell opened." > "%temp%\talk.vbs"
cscript //nologo "%temp%\talk.vbs"
del "%temp%\talk.vbs"
echo starpOS Terminal Environment. Type 'exit' to return to desktop.
echo.
cmd /k
goto desktop

:settings
cls
title starpOS Settings
echo CreateObject("SAPI.SpVoice").Speak "Opening configuration panel." > "%temp%\talk.vbs"
cscript //nologo "%temp%\talk.vbs"
del "%temp%\talk.vbs"
echo === SETTINGS ===
echo 1. Matrix Green
echo 2. Classic Blue
set "setchoice="
set /p setchoice="Choice: "
if "%setchoice%"=="1" color 0A
if "%setchoice%"=="2" color 1F
goto desktop

:launch_ai
if not "%_s1%"=="" echo [%TIME%] [ACT] Executing ai.bat module >> "%_s1%"
if not "%_s3%"=="" echo [%TIME%] [ACT] Executing ai.bat module >> "%_s3%"
cls
if exist ai.bat (
    call ai.bat
) else (
    echo CreateObject("SAPI.SpVoice").Speak "Error. AI batch module is missing." > "%temp%\talk.vbs"
    cscript //nologo "%temp%\talk.vbs"
    del "%temp%\talk.vbs"
    echo [ ERROR ] ai.bat tool missing!
    pause
)
goto desktop

:shutdown
if not "%_s1%"=="" echo [%TIME%] [PWR] Shutdown Terminated >> "%_s1%"
if not "%_s3%"=="" echo [%TIME%] [PWR] Shutdown Terminated >> "%_s3%"
cls
color 0C
echo CreateObject("SAPI.SpVoice").Speak "Shutting down starpOS. Goodbye." > "%temp%\talk.vbs"
cscript //nologo "%temp%\talk.vbs"
del "%temp%\talk.vbs"
echo Shutting down %OS_NAME%...
timeout /t 2 >nul
