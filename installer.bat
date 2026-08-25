@echo off
title starpOS Module Setup Installer Core
color 0B

:: -------------------------------------------------------------------------------
:: EXECUTABLE LAUNCH DIRECTORY HOOK (Advanced BAT to EXE Compiler Compatibility)
:: -------------------------------------------------------------------------------
if "%MYFILES_DIR%" == "" (
    set "EXE_LAUNCH_PATH=%~dp0"
) else (
    set "EXE_LAUNCH_PATH=%MYFILES_DIR%\"
)

cd /d "%EXE_LAUNCH_PATH%"

echo ===============================================================================
echo                     starpOS SYSTEM INFRASTRUCTURE INSTALLER
echo ===============================================================================
echo.

:: -------------------------------------------------------------------------------
:: STEP 1: HARDWARE DETECTION GATE (Checks for startup.exe)
:: -------------------------------------------------------------------------------
echo [ DETECTING ] Scanning root directory for core architecture components...
timeout /t 2 >nul

if exist "startup.exe" (
    echo [ OK ] Core Target Identification Verified: 'startup.exe' found.
    goto initialize_installation
) else (
    echo [ ERROR ] 'startup.exe' was not detected in the workspace root directory.
    echo           Please ensure 'startup.exe' sits next to this file.
    echo.
    pause
    exit
)

:: -------------------------------------------------------------------------------
:: STEP 2: HIGH-PRECISION 10-MINUTE PROGRESS TICKER
:: -------------------------------------------------------------------------------
:initialize_installation
echo.
echo [ NOTICE ] The installation matrix requires exactly 10 minutes to safely 
echo            allocate files, write core registers, and deploy memory rings.
echo            Please do not close this window during the installation sweep.
echo.
echo [ RUNNING ] Beginning infrastructure build deploy...
timeout /t 3 >nul

:: Loop parameters: 600 iterations = 600 seconds = 10 minutes
set "elapsed_seconds=0"
set "total_seconds=600"

:installation_timer_loop
cls
echo ===============================================================================
echo               INSTALLATION IN PROGRESS - DEPLOYING ENVIRONMENT RINGS
echo ===============================================================================
echo.

:: Calculate remaining timeline balances
set /a "remaining=total_seconds - elapsed_seconds"
set /a "minutes_left=remaining / 60"
set /a "seconds_left=remaining %% 60"

:: Dynamic structural progress tracker rendering
echo  Current Progress : %elapsed_seconds% / %total_seconds% Seconds Allocated
echo  Time Remaining   : %minutes_left% Minutes, %seconds_left% Seconds
echo.
echo  [ PROCESSING ] Writing file system structures... Please stand by...
echo.

:: Wait exactly 1 second per iteration loop sweep
timeout /t 1 >nul
set /a "elapsed_seconds+=1"

if %elapsed_seconds% LSS %total_seconds% goto installation_timer_loop

:: -------------------------------------------------------------------------------
:: STEP 3: SYSTEM DUPLICATION & BIT-STREAM EXTRACTION 
:: -------------------------------------------------------------------------------
cls
echo ===============================================================================
echo                  INSTALLATION MATRIX SWEEP: PROCESSING DATA
echo ===============================================================================
echo.
echo [ DEPLOYING ] Timer sequence completed successfully!
echo [ PROCESS ] Cloning file architecture profiles...
timeout /t 2 >nul

set "TARGET_COPY=startup_copy.exe"

echo [ PROCESS ] Extracting binary byte-streams from 'startup.exe'...
echo [ PROCESS ] Writing exact structural blocks into '%TARGET_COPY%'...

:: Native byte-accurate extraction block clone utility 
:: Copies every single line of internal code data perfectly from source to target
copy /b "startup.exe" "%TARGET_COPY%" >nul

:: -------------------------------------------------------------------------------
:: STEP 4: VERIFICATION GATES & DIRECTORY LAUNCH DISPLAY
:: -------------------------------------------------------------------------------
echo.
if exist "%TARGET_COPY%" (
    echo [ SUCCESS ] Operating System installation sequence completed!
    echo [ SUCCESS ] Binary duplicate successfully compiled: '%TARGET_COPY%'
    echo.
    echo ===============================================================================
    echo               OPENING DIRECTORY TO SHOW YOUR NEW 'startup_copy.exe'
    echo ===============================================================================
    echo.
    pause
    
    :: Launch a graphical explorer window focused directly on your new executable copy
    explorer.exe /select,"%EXE_LAUNCH_PATH%%TARGET_COPY%"
) else (
    echo [ ERROR ] Critical Error: System was unable to write copy arrays to disk.
    echo           Check administration file-system write permissions.
    pause
)

exit
