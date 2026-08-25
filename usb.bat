@echo off

:: -------------------------------------------------------------------------------
:: PARAMETER RETENTION: Protect log targets using absolute string pointers
:: -------------------------------------------------------------------------------
set "u_s1=%~1"
set "u_s3=%~3"

:usb_menu
cls
color 0E
title starpOS USB Device Controller

echo ===============================================================================
echo                      starpOS HARDWARE USB DEVICE CONTROLLER
echo ===============================================================================
echo.
echo    1. Scan USB Hub Hardware Ports
echo    2. Mount External File System Volume
echo    3. Safely Eject / Disconnect Device
echo    4. Exit to starpOS Desktop
echo.
echo ===============================================================================
echo  Select a tool (1-4) and press Enter.
echo ===============================================================================
echo.

set "usbchoice="
set /p usbchoice="USB Controller> "

if "%usbchoice%"=="" goto usb_menu
if "%usbchoice%"=="1" goto usb_scan
if "%usbchoice%"=="2" goto usb_mount
if "%usbchoice%"=="3" goto usb_eject
if "%usbchoice%"=="4" exit /b
goto usb_menu

:usb_scan
if not "%u_s1%"=="" echo [%TIME%] [HARDWARE] Triggered hardware port inquiry loop >> "%u_s1%"
cls
echo [ HARDWARE ] Initializing hardware port scan...

:: Voice Call
echo CreateObject("SAPI.SpVoice").Speak "Scanning active system hardware ports." > "%temp%\talk.vbs"
cscript //nologo "%temp%\talk.vbs"
del "%temp%\talk.vbs"

timeout /t 1 >nul
echo [ STATUS   ] Port 01: [EMPTY]
echo [ STATUS   ] Port 02: [MASS STORAGE DEVICE DETECTED]
echo.
pause
goto usb_menu

:usb_mount
if not "%u_s1%"=="" echo [%TIME%] [HARDWARE] External file system volume mounted >> "%u_s1%"
cls
echo [ FILESYS ] Attaching volume sector map blocks...

:: Voice Call
echo CreateObject("SAPI.SpVoice").Speak "Mounting external drive storage." > "%temp%\talk.vbs"
cscript //nologo "%temp%\talk.vbs"
del "%temp%\talk.vbs"

timeout /t 2 >nul
echo [ FILESYS ] External storage allocation active on mass device storage route.
echo.
pause
goto usb_menu

:usb_eject
if not "%u_s1%"=="" echo [%TIME%] [HARDWARE] Disconnected storage device pointer >> "%u_s1%"
cls
echo [ HARDWARE ] Flushing storage volume memory arrays...

:: Voice Call
echo CreateObject("SAPI.SpVoice").Speak "Safely ejecting external storage device." > "%temp%\talk.vbs"
cscript //nologo "%temp%\talk.vbs"
del "%temp%\talk.vbs"

timeout /t 1 >nul
echo [ SUCCESS  ] Hardware can now be safely removed from system physical layers.
echo.
pause
goto usb_menu
