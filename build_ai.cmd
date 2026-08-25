@echo off
:: ===========================================================================
::  build_ai.cmd  -  compile ai.cs into ai.exe
:: ===========================================================================
::  Uses the C# compiler that ships inside Windows. Nothing is downloaded and
::  nothing needs the internet, which is the same promise the assistant makes.
::
::  Run it from anywhere:   build_ai.cmd
::
::  WHY .cmd AND NOT .bat
::  bootcore.bat runs every *.bat in this folder at boot. A build script named
::  build_ai.bat would therefore recompile the assistant every single time
::  starpOS started. The extension is the whole fix.
:: ===========================================================================

setlocal
set "HERE=%~dp0"
set "CSC=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
set "SPEECH=C:\Windows\Microsoft.NET\assembly\GAC_MSIL\System.Speech\v4.0_4.0.0.0__31bf3856ad364e35\System.Speech.dll"

echo.
echo  === starpOS AI  -  native build =========================================
echo.

if not exist "%CSC%" (
    echo  [ ERROR ] No C# compiler at:
    echo            %CSC%
    echo            Look in C:\Windows\Microsoft.NET\Framework64 for another
    echo            v4 folder and point CSC at the csc.exe inside it.
    exit /b 1
)
if not exist "%HERE%ai.cs" (
    echo  [ ERROR ] ai.cs is not next to this script.
    exit /b 1
)

set "REFS=/r:System.Drawing.dll /r:System.Windows.Forms.dll"
if exist "%SPEECH%" (
    set "REFS=%REFS% /r:%SPEECH%"
) else (
    echo  [ WARN ] System.Speech.dll not found. Building without a voice.
    echo           That is STARP-0501 and nothing else breaks.
)

echo  Compiling ai.cs ...

:: Build to a side name first. Windows will not let the compiler WRITE an exe
:: that is currently running, but it will happily RENAME one - so the new
:: build is swapped in instead of written over the top. That means you can
:: rebuild while the assistant is open on screen.
"%CSC%" /nologo /target:winexe /out:"%HERE%ai.new.exe" %REFS% "%HERE%ai.cs" "%HERE%ai_tools.cs"
if errorlevel 1 (
    echo.
    echo  [ FAILED ] The compiler refused it. The errors are above.
    if exist "%HERE%ai.new.exe" del "%HERE%ai.new.exe" >nul 2>nul
    exit /b 1
)

if exist "%HERE%ai.exe" (
    del "%HERE%ai.old.exe" >nul 2>nul
    move /y "%HERE%ai.exe" "%HERE%ai.old.exe" >nul 2>nul
)
move /y "%HERE%ai.new.exe" "%HERE%ai.exe" >nul
if errorlevel 1 (
    echo  [ FAILED ] Built, but could not put ai.exe in place.
    exit /b 1
)
:: The old one only deletes once whatever was running it lets go.
del "%HERE%ai.old.exe" >nul 2>nul

echo.
echo  [ OK ] ai.exe built.
for %%F in ("%HERE%ai.exe") do echo         %%~zF bytes   %%~tF
echo.
echo  Run it with:  ai.exe        or from the desktop menu.
echo  The console version, ai.bat, still works and shares every file.
echo.
endlocal

