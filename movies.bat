@echo off

:: -------------------------------------------------------------------------------
:: PARAMETER RETENTION: Protect log targets using absolute string pointers
:: -------------------------------------------------------------------------------
if not "%~1"=="" set "_s1=%~1"
if not "%~3"=="" set "_s3=%~3"

:movie_menu
cls
color 0D
title starpOS Movie Theater Hub

echo ===============================================================================
echo                      starpOS SYSTEM MOVIE THEATER INTERACTIVE HUB
echo ===============================================================================
echo.
echo    1. Scan System Folder (.\) for Real MKV Video Files
echo    2. Launch and Play the Detected MKV Video File
echo    3. Review Media Codec System Properties
echo    4. Exit to starpOS Desktop
echo.
echo ===============================================================================
echo  Place your real movie files (.mkv) directly inside the "system" folder!
echo ===============================================================================
echo.

set "moviechoice="
set /p moviechoice="Theater Box> "

if "%moviechoice%"=="" goto movie_menu
if "%moviechoice%"=="1" goto movie_scan
if "%moviechoice%"=="2" goto movie_play
if "%moviechoice%"=="3" goto movie_codec
if "%moviechoice%"=="4" exit /b
goto movie_menu

:movie_scan
if not "%_s1%"=="" echo [%TIME%] [THEATER] Triggered system folder MKV scanning cycle >> "%_s1%"
cls
echo [ THEATER ] Scanning "system/" folder for real playable .mkv video features...
echo.

echo CreateObject("SAPI.SpVoice").Speak "Scanning system directory for m k v video features." > "%temp%\talk.vbs"
cscript //nologo "%temp%\talk.vbs"
del "%temp%\talk.vbs"

dir "*.mkv" /b 2>nul
if errorlevel 1 (
    echo  [ INFO ] No .mkv files were found inside the system folder.
    echo          Drop some real .mkv video files into "system/" to play them!
)
echo.
pause
goto movie_menu

:movie_play
cls
echo [ MEDIA ] Searching for video file target...
echo.

set "target_movie="
for %%A in (*.mkv) do (
    set "target_movie=%%A"
)

:: -------------------------------------------------------------------------------
:: OPTION 2 CRITICAL CLOSE FIX: Dummy text anchor stops instant window crashes
:: -------------------------------------------------------------------------------
if "%target_movie%X"=="X" (
    echo  [ ERROR ] No .mkv file detected inside the system directory.
    echo           Please add a video file and try again.
    echo CreateObject("SAPI.SpVoice").Speak "Error... No video container file found to play." > "%temp%\talk.vbs"
    cscript //nologo "%temp%\talk.vbs"
    del "%temp%\talk.vbs"
    pause
    goto movie_menu
)

if not "%_s1%"=="" echo [%TIME%] [THEATER] User launched video playback: %target_movie% >> "%_s1%"

echo  [ OK ] Target Found: %target_movie%
echo  [ OK ] Triggering core Windows shell execution path...
echo.

echo CreateObject("SAPI.SpVoice").Speak "Launching movie feature file now. Enjoy the video." > "%temp%\talk.vbs"
cscript //nologo "%temp%\talk.vbs"
del "%temp%\talk.vbs"

timeout /t 1 >nul

:: Double-quoted launch protection shields against filenames with spaces
start "" "%target_movie%"

echo  [ STATUS ] %target_movie% successfully launched in your media player!
echo.
pause
goto movie_menu

:movie_codec
cls
echo [ ENGINES ] Checking system digital rendering configurations...
echo CreateObject("SAPI.SpVoice").Speak "Displaying active movie codec configuration status." > "%temp%\talk.vbs"
cscript //nologo "%temp%\talk.vbs"
del "%temp%\talk.vbs"
echo.
echo === CODEC SYSTEM STATUS ===
echo  Video Decoder:  DirectShow Native Host Media Pipeline
echo  Audio Decoder:  Windows Core SAPI Snd Engine Audio Mapper
echo  Target Path:    Local system directory folder
echo  Formats:        Natively handles real .mkv multimedia container files
echo.
pause
goto movie_menu
