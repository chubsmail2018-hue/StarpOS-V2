@echo off
title starpOS v1.5.0 Northstar - Target Locked Setup Wizard

:: -------------------------------------------------------------------------------
:: STEP 1: WELCOME SCREEN (Inno Setup Wizard Style)
:: -------------------------------------------------------------------------------
:welcome_screen
cls
color 0A
echo ===============================================================================
echo         starpOS v1.5.0 Northstar Installation ^& Setup Wizard
echo ===============================================================================
echo.
echo  Welcome to the starpOS Deployment Utility.
echo.
echo  This wizard will install starpOS v1.5.0 Northstar on your computer.
echo  All tracking metrics, file structures, and backing configurations will be mapped.
echo.
echo  [ TARGET GATE ] This package will exclusively deploy using the verified
echo                  starpOS.rar archive template file sitting inside the 
echo                  download repository path directory block.
echo.
echo ===============================================================================
echo  [N] Next ^>   [C] Cancel
echo ===============================================================================
echo.
set "wizchoice="
set /p wizchoice="Setup> "

if /I "%wizchoice%"=="C" goto cancel_setup
if /I "%wizchoice%"=="N" goto verify_target_gate
goto welcome_screen

:: -------------------------------------------------------------------------------
:: STEP 2: VERIFY SECURE .RAR FOLDER TARGET PATH
:: -------------------------------------------------------------------------------
:verify_target_gate
cls
echo ===============================================================================
echo         starpOS v1.5.0 Northstar - Verifying Target Directory
echo ===============================================================================
echo.
echo  Scanning download path: C:\Users\bates\Downloads\starpOS\system\ ...
echo.

:: Establish absolute path strings
set "target_path=C:\Users\bates\Downloads\starpOS\system"
set "target_rar=%target_path%\starpOS.rar"

:: CRITICAL GATE RULE: Abort instantly with low warning beep if .rar is missing
if not exist "%target_rar%" (
    powershell -Command "[Console]::Beep(400, 300)"
    echo  [ ERROR ] Secure target validation failed!
    echo          Could not locate file: starpOS.rar
    echo          Expected Path: %target_path%\
    echo.
    echo          Please position your rar deployment package and try again.
    echo.
    echo ===============================================================================
    echo  Press any key to abort the installation layout...
    echo ===============================================================================
    pause >nul
    exit
)

:: Lock the output destination path into your system folder deployment layer
set "install_dir=system\starpOS"
goto confirm_screen

:: -------------------------------------------------------------------------------
:: STEP 3: READY TO INSTALL CONFIRMATION
:: -------------------------------------------------------------------------------
:confirm_screen
cls
echo ===============================================================================
echo         starpOS v1.5.0 Northstar - Ready to Install
echo ===============================================================================
echo.
echo  The wizard has successfully localized your verified .rar deployment package.
echo.
echo  Installation Summary:
echo   - Extraction Source: %target_rar%
echo   - Target Directory:  %install_dir%\
echo   - Est. Duration:     3 Minutes (180 Seconds)
echo   - Dependencies:      Direct Registry (.rg), PowerShell (.wp), Backups (.bak)
echo.
echo ===============================================================================
echo  [I] Install   [B] ^< Back   [C] Cancel
echo ===============================================================================
echo.
set "wizchoice="
set /p wizchoice="Setup> "

if /I "%wizchoice%"=="C" goto cancel_setup
if /I "%wizchoice%"=="B" goto welcome_screen
if /I "%wizchoice%"=="I" goto execute_install
goto confirm_screen

:: -------------------------------------------------------------------------------
:: STEP 4: 3-MINUTE CLASSIC GREEN INSTALLATION MATRIX PIPELINE 
:: -------------------------------------------------------------------------------
:execute_install
cls
color 0A

:: PHASE 1: DIRECTORY STRUCTURE MAPPING (45 Seconds)
echo ===============================================================================
echo         starpOS v1.5.0 Northstar - Installing Components...
echo ===============================================================================
echo.
echo  Extracting platform libraries and core system folders from starpOS.rar...
echo  [■■□□□□□□□□□□□□□□□□□□] 10%% Complete
echo -------------------------------------------------------------------------------
echo  Creating: %install_dir%\data\
if not exist "%install_dir%\data" mkdir "%install_dir%\data"
timeout /t 15 >nul
echo  Creating: %install_dir%\resources\
if not exist "%install_dir%\resources" mkdir "%install_dir%\resources"
timeout /t 15 >nul
echo  Creating: %install_dir%\debug\
if not exist "%install_dir%\debug" mkdir "%install_dir%\debug"
timeout /t 15 >nul
cls

:: PHASE 2: APPLICATION EXECUTION EXTRACTION (45 Seconds)
echo ===============================================================================
echo         starpOS v1.5.0 Northstar - Installing Components...
echo ===============================================================================
echo.
echo  Extracting compiled binaries and script utilities...
echo  [■■■■■■□□□□□□□□□□□□□□] 30%% Complete
echo -------------------------------------------------------------------------------
echo  Extracting: %install_dir%\ai.exe
timeout /t 11 >nul
echo  Extracting: %install_dir%\movies.bat
timeout /t 11 >nul
echo  Extracting: %install_dir%\voice.bat
timeout /t 11 >nul
echo  Extracting: %install_dir%\usb.bat
timeout /t 12 >nul
cls

:: PHASE 3: CONFIGURATION AND REGISTRY INJECTIONS (45 Seconds)
echo ===============================================================================
echo         starpOS v1.5.0 Northstar - Installing Components...
echo ===============================================================================
echo.
echo  Writing environment configuration schemas and script matrix hooks...
echo  [■■■■■■■■■■■■□□□□□□□□] 60%% Complete
echo -------------------------------------------------------------------------------
echo  Extracting: %install_dir%\config.cfg
echo OS_NAME=starpOS > "%install_dir%\config.cfg"
echo OS_VERSION=1.5.0 >> "%install_dir%\config.cfg"
echo THEME=MATRIX_GREEN >> "%install_dir%\config.cfg"
echo VOICE=ON >> "%install_dir%\config.cfg"
timeout /t 15 >nul

echo  Extracting: %install_dir%\registry.rg
echo [HKEY_LOCAL_MACHINE\SOFTWARE\starpOS] > "%install_dir%\registry.rg"
echo "Build"="v1.5.0_Northstar" >> "%install_dir%\registry.rg"
timeout /t 15 >nul

echo  Extracting: %install_dir%\automation.wp
echo # starpOS Windows PowerShell Command Bridge Matrix > "%install_dir%\automation.wp"
echo Write-Output 'Pipeline Hook Stabilized' >> "%install_dir%\automation.wp"
timeout /t 15 >nul
cls

:: PHASE 4: BACKEND ENGINE CODE ^& LEGACY RECOVERY IMAGES (45 Seconds)
echo ===============================================================================
echo         starpOS v1.5.0 Northstar - Installing Components...
echo ===============================================================================
echo.
echo  Mirroring legacy snapshots and generating internal file verification caches...
echo  [■■■■■■■■■■■■■■■■□□□□] 80%% Complete
echo -------------------------------------------------------------------------------
echo  Extracting: %install_dir%\engine.cs
timeout /t 11 >nul

echo  Extracting: %install_dir%\backup\v1.2_snapshot.bak
if not exist "%install_dir%\backup" mkdir "%install_dir%\backup"
echo [BACKUP_IMAGE_V1.2_OPERATIONAL] > "%install_dir%\backup\v1.2_snapshot.bak"
timeout /t 11 >nul

echo  Extracting: %install_dir%\backup\v1.3_snapshot.bak
echo [BACKUP_IMAGE_V1.3_OPERATIONAL] > "%install_dir%\backup\v1.3_snapshot.bak"
timeout /t 11 >nul
echo  Extracting: %install_dir%\builds\
if not exist "%install_dir%\builds" mkdir "%install_dir%\builds"
timeout /t 12 >nul
cls

:: PHASE 5: RE-REGISTRATION CLOSURE (Final Uptime Sync)
echo ===============================================================================
echo         starpOS v1.5.0 Northstar - Installing Components...
echo ===============================================================================
echo.
echo  Finalizing system installation setup tracks...
echo  [■■■■■■■■■■■■■■■■■■■■] 100%% Complete
echo -------------------------------------------------------------------------------
echo  Finalizing dependency registration chains...
timeout /t 3 >nul
goto install_complete

:: -------------------------------------------------------------------------------
:: STEP 5: COMPLETED STATUS SCREEN WITH HIGH-PITCHED DING
:: -------------------------------------------------------------------------------
:install_complete
cls
:: Xylophone High-Pitch Chime Signal Trigger (1200Hz for 150ms)
powershell -Command "[Console]::Beep(1200, 150)"

echo ===============================================================================
echo         starpOS v1.5.0 Northstar Installation Completed!
echo ===============================================================================
echo.
echo  Setup has finished installing starpOS v1.5.0 Northstar inside your target.
echo  The application environment may be launched directly via your system folder.
echo.
echo  Target Path: %install_dir%\
echo  Source File: %target_rar%
echo.
echo ===============================================================================
echo  Press any key to exit the installation wizard utility...
echo ===============================================================================
pause >nul
exit



