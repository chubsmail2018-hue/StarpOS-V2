@echo off
cls
color 0B
title starpOS Boot Loader

echo ===================================================
echo                 starpOS BOOT SYSTEM                
echo ===================================================
echo.
echo [ INFO ] Initializing starpOS hardware check...

:: 1. Dynamic Inline VBS Voice (Speaks during hardware check)
echo CreateObject("SAPI.SpVoice").Speak "Initializing starpOS hardware check." > "%temp%\talk.vbs"
cscript //nologo "%temp%\talk.vbs"
del "%temp%\talk.vbs"

timeout /t 1 >nul

:: Double-check if the critical engine files are in place before loading
if not exist bootcore.bat (
    echo [ ERROR ] bootcore.bat is missing!
    pause
    exit
)
if not exist startup.bat (
    echo [ ERROR ] startup.bat is missing!
    pause
    exit
)

echo [ OK ] Hardware verification successful.
echo [ OK ] Loading kernel structures...

:: 2. Dynamic Inline VBS Voice (Speaks right before handing control to the kernel)
echo CreateObject("SAPI.SpVoice").Speak "Hardware verification successful. Loading kernel structures." > "%temp%\talk.vbs"
cscript //nologo "%temp%\talk.vbs"
del "%temp%\talk.vbs"

timeout /t 1 >nul
goto loading

:loading
cls
echo Loading starpOS
echo [■■□□□□□□□□] 20%%
timeout /t 1 >nul
cls
echo Loading starpOS
echo [■■■■■■□□□□] 60%%
timeout /t 1 >nul
cls
echo Loading starpOS
echo [■■■■■■■■■■] 100%%
timeout /t 1 >nul

:: Pass control directly over to your core kernel
call startup.bat
