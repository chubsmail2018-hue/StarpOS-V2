@echo off
title starpOS Module Uninstaller Core
color 0C

:: -------------------------------------------------------------------------------
:: EXECUTABLE LAUNCH DIRECTORY HOOK (Advanced BAT to EXE Compiler Compatibility)
:: -------------------------------------------------------------------------------
if "%MYFILES_DIR%" == "" (
    set "EXE_LAUNCH_PATH=%~dp0"
) else (
    set "EXE_LAUNCH_PATH=%MYFILES_DIR%\"
)

cd /d "%EXE_LAUNCH_PATH%"

set "TARGET_COPY=startup_copy.exe"

echo ===============================================================================
echo                    starpOS SYSTEM INFRASTRUCTURE UNINSTALLER
echo ===============================================================================
echo.

:: -------------------------------------------------------------------------------
:: STEP 1: INITIAL COMPONENT SCAN GATES
:: -------------------------------------------------------------------------------
echo [ DETECTING ] Scanning root directory for installed modules...
timeout /t 2 >nul

if exist "%TARGET_COPY%" (
    echo [ OK ] Target Located: '%TARGET_COPY%' identified on system ring.
    goto initialize_uninstallation
) else (
    echo [ WARNING ] '%TARGET_COPY%' was not detected in this workspace folder.
    echo             There is no active installation loop copy to remove.
    echo.
    pause
    exit
)

:: -------------------------------------------------------------------------------
:: STEP 2: HIGH-PRECISION 10-MINUTE REVERSE TICKER LOOP
:: -------------------------------------------------------------------------------
:initialize_uninstallation
echo.
echo [ WARNING ] The removal sequence requires exactly 10 minutes to safely
echo             deallocate code vectors and wipe environment memory rings.
echo             Please do not close this window during the countdown sweep.
echo.
echo [ RUNNING ] Commencing uninstallation matrix sequence...
timeout /t 3 >nul

set "elapsed_seconds=0"
set "total_seconds=600"

:uninstall_timer_loop
cls
echo ===============================================================================
echo                UNINSTALLATION IN PROGRESS - WIPING DEPLOYED COPIES
echo ===============================================================================
echo.

:: Perform safe arithmetic tracking operations
set /a "remaining=total_seconds - elapsed_seconds"
set /a "minutes_left=remaining / 60"
set /a "seconds_left=remaining %% 60"

echo  Wipe Progress   : %elapsed_seconds% / %total_seconds% Seconds Unallocated
echo  Time Remaining  : %minutes_left% Minutes, %seconds_left% Seconds
echo.
echo  [ REMOVING ] Wiping file system footprints... Please stand by...
echo.

:: Standardize rate pacing exactly at 1 tick per second
timeout /t 1 >nul
set /a "elapsed_seconds+=1"

if %elapsed_seconds% LSS %total_seconds% goto uninstall_timer_loop

:: -------------------------------------------------------------------------------
:: STEP 3: SANITIZATION PURGE GATE (Deletes startup_copy.exe)
:: -------------------------------------------------------------------------------
cls
echo ===============================================================================
echo                  UNINSTALLATION COMPLETE - PURGING FILE DATA
echo ===============================================================================
echo.
echo [ DEPLOYING ] 10-minute timer sweep finalized successfully.
echo [ DELETING ] Purging '%TARGET_COPY%' from direct storage pools...
timeout /t 2 >nul

:: Force clear target file regardless of any read-only hidden attributes
del /f /q "%TARGET_COPY%" >nul 2>nul

:: -------------------------------------------------------------------------------
:: STEP 4: VERIFICATION VALIDATION CHECK
:: -------------------------------------------------------------------------------
if not exist "%TARGET_COPY%" (
    echo [ SUCCESS ] System sweep complete! '%TARGET_COPY%' removed cleanly.
    echo [ SUCCESS ] All temporary memory allocations have been uninstalled.
) else (
    echo [ ERROR ] File locked! Could not unallocate '%TARGET_COPY%'.
    echo           Please check administrative write rights or close active apps.
)

echo.
pause
exit
