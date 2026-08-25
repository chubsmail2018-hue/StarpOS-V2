@echo off 

:: Set a fallback master administrator password if no account exists yet
if "%OS_USER%"=="" (
set "OS_USER=Admin"
set "OS_PASS=1234"
) 

:: -------------------------------------------------------------------------------
:: USER PROFILE LOGIN SYSTEM (Boot Gate)
:: -------------------------------------------------------------------------------
:login_screen
cls
color 0E
title %OS_NAME% Authentication Portal 

echo ===============================================================================
echo                starpOS USER AUTHENTICATION SECURE PORTAL
echo ===============================================================================
echo.
echo    1. Log In to Existing Account
echo    2. Create a New Account
echo    3. Shutdown System
echo.
echo ===============================================================================
echo  Select an option (1-3) and press Enter.
echo ===============================================================================
echo.
set "logchoice="
set /p logchoice="Auth> " 

if "%logchoice%"=="1" goto process_login
if "%logchoice%"=="2" goto create_account
if "%logchoice%"=="3" goto shutdown
goto login_screen 

:process_login
cls
echo ===============================================================================
echo                             ACCOUNT SIGN IN LOGIN
echo ===============================================================================
echo.
echo  Enter account security credentials below:
echo.
set "input_user="
set "input_pass="
set /p input_user=" Username: "
set /p input_pass=" Password: " 

:: Validate match parameters
if "%input_user%"=="%OS_USER%" (
if "%input_pass%"=="%OS_PASS%" (
echo [%TIME%] [AUTH] Successfully authenticated user: %OS_USER% >> "%~1"
echo [%TIME%] [AUTH] Successfully authenticated user: %OS_USER% >> "%~3"
echo.
echo  [ OK ] Access Granted! Loading your custom configurations...
timeout /t 1 >nul
goto desktop
)
) 

echo [%TIME%] [SECURITY_ALERT] Failed login attempt for user input: "%input_user%" >> "%~1"
echo [%TIME%] [SECURITY_ALERT] Failed login attempt for user input: "%input_user%" >> "%~3"
echo.
echo  [ ERROR ] Invalid username or password! Please try again.
pause
goto login_screen 

:create_account
cls
echo ===============================================================================
echo                           CREATE NEW USER ACCOUNT
echo ===============================================================================
echo.
echo  Configure your new username and profile access password:
echo.
set "new_user="
set "new_pass="
set /p new_user=" Set Username: "
set /p new_pass=" Set Password: " 

if "%new_user%"=="" goto create_account
if "%new_pass%"=="" goto create_account 

:: Register new global environment parameters
set "OS_USER=%new_user%"
set "OS_PASS=%new_pass%" 

echo [%TIME%] [USER_MGMT] Created new account profile: %OS_USER% >> "%~1"
echo.
echo  [ SUCCESS ] Account created successfully! Returning to portal to sign in.
pause
goto login_screen 

:: -------------------------------------------------------------------------------
:: MAIN DESKTOP INTERFACE ENVIRONMENT
:: -------------------------------------------------------------------------------
:desktop
cls
color 1F
title %OS_NAME% Desktop (v%OS_VERSION%) 

echo ===============================================================================
echo          __                       ____  _____
echo   _____ / /_ ____ _ _____ ____   / __ / ***/
echo  / // _// __ `// **// __ \ / / / /_ \
echo (**  )/ / / // // /   / // // // /***/ /
echo/****/ _*/ _*,*//*/   / .***/ _***//___*/
echo                       /*/
echo ===============================================================================
echo  Date: %DATE%   ^|   Time: %TIME%               Logged in as: %OS_USER%
echo ===============================================================================
echo.
echo    1. File Explorer       2. Notepad              3. System Info
echo    4. Command Prompt      5. Settings             6. starpOS Task Manager
echo    7. Launch AI Assistant  8. Re-login Account     9. Shut Down
echo.
echo ===============================================================================
echo  [START] Type a number (1-9) and press Enter to select an app.
echo ===============================================================================
echo. 

set "choice="
set /p choice="starpOS> " 

if "%choice%"=="" goto desktop 

echo [%TIME%] [INP] Value: "%choice%" >> "%~1"
echo [%TIME%] [INP] Value: "%choice%" >> "%~3" 

if "%choice%"=="1" goto explorer
if "%choice%"=="2" goto notepad
if "%choice%"=="3" goto sysinfo
if "%choice%"=="4" goto cmdprompt
if "%choice%"=="5" goto settings
if "%choice%"=="6" goto taskmanager
if "%choice%"=="7" goto launch_ai
if "%choice%"=="8" goto relogin_trigger
if "%choice%"=="9" goto shutdown 

echo [%TIME%] [WARNING] Invalid command attempt: "%choice%" >> "%~1"
echo [%TIME%] [WARNING] Invalid command attempt: "%choice%" >> "%~3"
goto desktop 

:explorer
echo [%TIME%] [ACT] Navigated Explorer >> "%~1"
echo [%TIME%] [ACT] Navigated Explorer >> "%~3"
cls
title starpOS File Explorer
echo === FILE EXPLORER ===
echo.
dir /b ..
echo.
pause
goto desktop 

:notepad
echo [%TIME%] [ACT] Opened Notepad >> "%~1"
echo [%TIME%] [ACT] Opened Notepad >> "%~3"
cls
title starpOS Notepad
echo === NOTEPAD ===
echo Type your note below.
echo.
set "note="
set /p note="Text: "
echo [%TIME%] [DATA] Str: "%note%" >> "%~1"
echo [%TIME%] [DATA] Str: "%note%" >> "%~3"
echo.
echo Note processed through active data streams!
pause
goto desktop 

:sysinfo
cls
title starpOS System Info
echo === SYSTEM INFORMATION ===
echo OS Name:       %OS_NAME%
echo Version:       %OS_VERSION%
echo Developer:     %OS_DEVELOPER%
echo Current Session: %OS_USER%
echo Status:        Running smoother than Windows
echo.
pause
goto desktop 

:cmdprompt
echo [%TIME%] [SHL] Console Open >> "%~1"
echo [%TIME%] [SHL] Console Open >> "%~3"
cls
title starpOS Command Line
echo starpOS Terminal Environment. Type 'exit' to return to desktop.
echo.
cmd /k
goto desktop 

:settings
cls
title starpOS Settings
echo === SETTINGS ===
echo 1. Matrix Green
echo 2. Classic Blue
set "setchoice="
set /p setchoice="Choice: "
if "%setchoice%"=="1" color 0A
if "%setchoice%"=="2" color 1F
goto desktop 

:taskmanager
echo [%TIME%] [ACT] Opened Task Manager >> "%~1"
echo [%TIME%] [ACT] Opened Task Manager >> "%~3"
cls
title starpOS Task Manager
echo ===============================================================================
echo                              starpOS TASK MANAGER
echo ===============================================================================
echo.
tasklist /NH /FI "STATUS eq RUNNING" | more
echo.
pause
goto desktop 

:launch_ai
if not exist "ai.bat" (
echo [ ERROR ] ai.bat tool could not be loaded. File is missing from system.
pause
goto desktop
)
echo [%TIME%] [ACT] Executing ai.bat module >> "%~1"
echo [%TIME%] [ACT] Executing ai.bat module >> "%~3"
cls
call ai.bat
goto desktop 

:: -------------------------------------------------------------------------------
:: RE-LOGIN INTERACTION SYSTEM
:: -------------------------------------------------------------------------------
:relogin_trigger
echo [%TIME%] [AUTH] User logged out to change sessions: %OS_USER% >> "%~1"
echo [%TIME%] [AUTH] User logged out to change sessions: %OS_USER% >> "%~3"
cls
color 0C
echo Logging out of session...
timeout /t 1 >nul
goto login_screen 

:shutdown
echo [%TIME%] [PWR] Shutdown Terminated >> "%~1"
echo [%TIME%] [PWR] Shutdown Terminated >> "%~3"
cls
color 0C
echo Shutting down %OS_NAME%...
timeout /t 2 >nul
exit