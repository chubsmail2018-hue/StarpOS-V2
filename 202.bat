@echo off
setlocal enabledelayedexpansion

:: ===========================================================================
::  202.bat  -  202
::  202
::
::  Built by mkapp.ps1. Launched from the starpOS desktop as slot 59.
::  Everything you want to change is between the CHANGE ME markers.
:: ===========================================================================

:: bootcore.bat runs every .bat in this folder when starpOS boots. Without
:: this line, this app would also open during startup. The desktop sets
:: STARPOS_LAUNCH before it calls an app, so this only runs on purpose.
if not "%STARPOS_LAUNCH%"=="1" goto :eof

:: Log targets handed over by the desktop.
set "_s1=%~1"
set "_s3=%~3"
if not defined _s1 set "_s1=..\data\1.log"

set "BLANKS=0"

:app_menu
cls
title starpOS - 202
echo ===============================================================================
echo  202
echo ===============================================================================
echo.

:: ------------------------------- CHANGE ME ---------------------------------
echo    1. Say hello
echo    2. Show the time
echo    0. Back to the starpOS desktop
:: ----------------------------- END CHANGE ME -------------------------------

echo.
echo ===============================================================================
echo.
set "pick="
set /p pick="202> "
if not defined pick goto app_blank
set "BLANKS=0"

call :log "[APP] 202 selection: !pick!"

:: ------------------------------- CHANGE ME ---------------------------------
if "!pick!"=="0" goto app_done
if "!pick!"=="1" goto say_hello
if "!pick!"=="2" goto show_time
:: ----------------------------- END CHANGE ME -------------------------------

echo.
echo  Not an option.
timeout /t 2 >nul
goto app_menu

:: ------------------------------- CHANGE ME ---------------------------------
:say_hello
echo.
echo  Hello from 202.
echo.
pause
goto app_menu

:show_time
echo.
echo  It is %TIME:~0,8% on %DATE%
echo.
pause
goto app_menu
:: ----------------------------- END CHANGE ME -------------------------------

:app_blank
set /a BLANKS+=1
if !BLANKS! LSS 30 goto app_menu

:app_done
call :log "[APP] 202 closed"
:: exit /b hands control back to the desktop. A bare "exit" would close the
:: whole starpOS window instead, which is a very easy mistake to make.
endlocal
exit /b

:log
if defined _s1 >>"%_s1%" echo [%TIME%] %~1
if defined _s3 >>"%_s3%" echo [%TIME%] %~1
goto :eof