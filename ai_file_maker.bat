@echo off
title starpOS AI Module Executable Generator
color 0A

:: -------------------------------------------------------------------------------
:: EXECUTABLE LAUNCH DIRECTORY HOOK (Advanced BAT to EXE Compiler Fix)
:: -------------------------------------------------------------------------------
:: %~dp0 returns the temporary workspace directory during runtime.
:: MYFILES_DIR catches the actual folder path where the user clicked the .exe.
if "%MYFILES_DIR%" == "" (
    set "EXE_LAUNCH_PATH=%~dp0"
) else (
    set "EXE_LAUNCH_PATH=%MYFILES_DIR%\"
)

echo ===============================================================================
echo                starpOS AUTOMATED AI EXECUTABLE FILE BUILDER
echo ===============================================================================
echo.
echo [ PROCESS ] Locating system installation directory...
echo Launch Path: %EXE_LAUNCH_PATH%

:: Verify and isolate the target subfolder destination path safely
if not exist "%EXE_LAUNCH_PATH%system" (
    echo [ WING ] Creating missing system directory architecture...
    mkdir "%EXE_LAUNCH_PATH%system"
)

set "TARGET_FILE=%EXE_LAUNCH_PATH%system\ai.bat"

echo [ PROCESS ] Injecting structural code data into '%TARGET_FILE%'...
echo.

:: -------------------------------------------------------------------------------
:: STREAM WRITING ARRAY: Generating the clean internal target script lines
:: -------------------------------------------------------------------------------
(
echo @echo off
echo title starpOS Artificial Intelligence Core
echo color 0B
echo cd /d "%%~dp0"
echo set "SYS_LOG=..\data\system.log"
echo set "USER_LOG=..\data\user.log"
echo echo [%%TIME%%] [AI] Initializing Core Neural Matrix Layer... ^>^> "%%SYS_LOG%%" 2^>nul
echo :ai_welcome
echo cls
echo echo ===============================================================================
echo echo                starpOS CORE ARTIFICIAL INTELLIGENCE MATRIX
echo echo ===============================================================================
echo echo  Type a question or command below ^(e.g., 'help', 'status', 'clear', 'exit'^).
echo echo ===============================================================================
echo echo.
echo echo  [AI]: Hello! I am the starpOS terminal assistant. How can I help you today?
echo echo.
echo :ai_chat_loop
echo set "ai_input="
echo set /p ai_input="User^> "
echo if "%%ai_input%%" == "" goto ai_chat_loop
echo echo [%%TIME%%] [AI_USER_INPUT] "%%ai_input%%" ^>^> "%%USER_LOG%%" 2^>nul
echo echo "%%ai_input%%" ^| findstr /I "exit quit close" ^>nul ^&^& goto ai_exit
echo echo "%%ai_input%%" ^| findstr /I "help menu command" ^>nul ^&^& goto response_help
echo echo "%%ai_input%%" ^| findstr /I "status system os version" ^>nul ^&^& goto response_status
echo echo "%%ai_input%%" ^| findstr /I "clear cls reset" ^>nul ^&^& goto ai_welcome
echo echo "%%ai_input%%" ^| findstr /I "hello hi hey" ^>nul ^&^& goto response_hello
echo echo "%%ai_input%%" ^| findstr /I "camera camra photo" ^>nul ^&^& goto response_camera
echo echo "%%ai_input%%" ^| findstr /I "audio sound clap" ^>nul ^&^& goto response_audio
echo echo.
echo echo  [AI]: I processed your phrase, but it doesn't match an active command.
echo echo        Try asking about 'status', 'camera', 'audio', or type 'help'.
echo echo.
echo goto ai_chat_loop
echo :response_hello
echo echo.
echo echo  [AI]: Greetings! My environment matrix registers are fully optimal.
echo echo.
echo goto ai_chat_loop
echo :response_help
echo echo.
echo echo  [AI]: You can interact with me using these environmental terms:
echo echo        - 'status' : Displays current operating system configurations.
echo echo        - 'camera' : Gives instructions on starting the laptop camera.
echo echo        - 'audio'  : Checks status logs for sound pulse deviations.
echo echo        - 'clear'  : Flushes the active text screen buffer cleanly.
echo echo.
echo goto ai_chat_loop
echo :response_status
echo echo.
echo echo  [AI]: Accessing internal kernel variables...
echo echo        - OS Identifier : %%OS_NAME%%
echo echo        - Core Version  : %%OS_VERSION%%
echo echo        - User Account  : %%OS_USER%%
echo echo.
echo goto ai_chat_loop
echo :response_camera
echo echo.
echo echo  [AI]: I detected a laptop camera profile hook! You can launch the camera 
echo echo        subroutine by executing option 5 from your main system desktop.
echo echo.
echo goto ai_chat_loop
echo :response_audio
echo echo.
echo echo  [AI]: Querying audio logs... The 'clap.bat' matrix logs pulses directly
echo echo        to your data directory to protect core memory rings from overflowing.
echo echo.
echo goto ai_chat_loop
echo :ai_exit
echo echo [%%TIME%%] [AI] Safely flushing neural cache registers... ^>^> "%%SYS_LOG%%" 2^>nul
echo echo.
echo echo  [AI]: Shutting down AI assistant matrix shell layer. Goodbye!
echo timeout /t 2 ^>nul
echo if exist startup.bat ^(
echo     call startup.bat
echo ^) else ^(
echo     exit /b
echo ^)
) > "%TARGET_FILE%"

:: -------------------------------------------------------------------------------
:: COMPILER VERIFICATION VALIDATION CHECKS
:: -------------------------------------------------------------------------------
if exist "%TARGET_FILE%" (
    echo [ SUCCESS ] Executable built 'ai.bat' cleanly inside your workspace folder!
) else (
    echo [ ERROR ] File generation process failed. Check security permission path locks.
)
echo.
pause
exit
