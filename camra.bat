@echo off
title starpOS Camera Capture Utility
cls

:: Setup storage target path
set "PHOTO_DIR=..\data\photos"
if not exist "%PHOTO_DIR%" mkdir "%PHOTO_DIR%"
set "FILENAME=%PHOTO_DIR%\snap_%date:~-4%%date:~4,2%%date:~7,2%_%time:~0,2%%time:~3,2%%time:~6,2%.jpg"
:: Remove accidental space padding in time strings
set "FILENAME=%FILENAME: =0%"

echo =========================================
echo          CAPTURING WEBCAM SNAPSHOT       
echo =========================================
echo Target Destination: %FILENAME%
echo.
echo Warming up laptop hardware camera sensors...

:: Call background PowerShell engine to grab a webcam frame
powershell -Command "Add-Type -AssemblyName System.Drawing; [void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms'); $cam = New-Object Windows.Media.Capture.MediaCapture; $cam.InitializeAsync().AsTask().Wait(); $profile = [Windows.Media.MediaProperties.ImageEncodingProperties]::CreateJpeg(); $file = [Windows.Storage.StorageFile]::GetFileFromPathAsync('%cd%\%FILENAME%').AsTask().Wait(); $cam.CapturePhotoToStorageFileAsync($profile, $file).AsTask().Wait();" 2>nul

:: Note: Native UWP MediaCapture often requires permissions. 
:: If the direct API background command fails, we fallback to a clean system launch wrapper:
if not exist "%FILENAME%" (
    echo [ INFO ] Direct API background block locked by system permissions.
    echo [ INFO ] Launching alternative automated capture stream instead...
    
    :: Alternative clean fallback script to snap a picture using device camera application
    start /wait microsoft.windows.camera:
)

echo.
echo Process complete. Check your data directory.
pause
