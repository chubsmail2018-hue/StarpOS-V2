@echo off
setlocal enabledelayedexpansion

:: ===========================================================================
::  startup.bat  -  starpOS desktop shell
::  Version 2.0
::
::  WHAT CHANGED FROM 1.2
::   * The :desktop label now exists. Every menu action ended with
::     "goto desktop" and the label was never defined, so the shell died
::     after a single action. That was the reason it kept closing.
::   * The menu is built from menu.cfg, so apps can be added without
::     touching this file.
::   * Settings are read from starpos.cfg and saved back to it, so a theme
::     survives a reboot.
::   * Speech goes through speak.vbs and voicebank.txt instead of writing a
::     temp .vbs file four lines at a time.
::   * New apps: My Notes, Log Viewer, Search, Calculator, Clock, Task
::     Manager, Real Machine Specs, Help, About.
::
::  The old version is kept at backup\startup.bat
:: ===========================================================================

:: --- Run from our own folder no matter who called us -----------------------
:: This is what stops ..\data from pointing somewhere random when starpOS is
:: launched by double clicking instead of through launcher1.bat.
set "SYS=%~dp0"
if "%SYS:~-1%"=="\" set "SYS=%SYS:~0,-1%"
pushd "%SYS%"
for %%R in ("%SYS%\..") do set "ROOT=%%~fR"

:: --- Load every setting from starpos.cfg -----------------------------------
if exist "starpos.cfg" (
    for /f "usebackq eol=# tokens=1,* delims==" %%A in ("starpos.cfg") do set "%%A=%%B"
)

:: Fall back to sensible values if the config is missing or incomplete.
if not defined OS_NAME       set "OS_NAME=starpOS"
if not defined OS_VERSION    set "OS_VERSION=1.3.0"
if not defined OS_CODENAME   set "OS_CODENAME=Northstar"
if not defined OS_DEVELOPER  set "OS_DEVELOPER=ScottSoft Team"
if not defined OS_ARCH       set "OS_ARCH=Batch 64-bit Emulation"
if not defined THEME_DESKTOP set "THEME_DESKTOP=1F"
if not defined THEME_ERROR   set "THEME_ERROR=0C"
if not defined VOICE_ENABLED set "VOICE_ENABLED=1"
if not defined DEV_MODE      set "DEV_MODE=0"
if not defined DEV_PASS      set "DEV_PASS=starp"
if not defined DEV_CONFIRM_DESTRUCTIVE set "DEV_CONFIRM_DESTRUCTIVE=1"
if not defined LOG_KERNEL    set "LOG_KERNEL=..\data\1.log"
if not defined LOG_USER      set "LOG_USER=..\data\3.log"
if not defined OS_USER       set "OS_USER=Admin"

:: bootcore.bat already sets _s1 and _s3. Honour those, and accept the
:: startup2.bat style of passing log paths as arguments too.
if not "%~1"=="" set "_s1=%~1"
if not "%~3"=="" set "_s3=%~3"
if not defined _s1 set "_s1=%LOG_KERNEL%"
if not defined _s3 set "_s3=%LOG_USER%"

:: --- Make sure the folders we write into exist -----------------------------
if not exist "..\data" mkdir "..\data" 2>nul
set "NOTEDIR=..\data\notes"
if not exist "%NOTEDIR%" mkdir "%NOTEDIR%" 2>nul

:: Counts how many times in a row the prompt came back with nothing. If
:: starpOS is ever started with its input redirected, set /p stops being
:: able to read and every empty answer would send us round the desktop loop
:: again forever. This gives the loop a way out.
set "BLANKS=0"

call :log "[SYSTEM] Desktop shell v2.0 started for %OS_USER%"
call :say DESK_WELCOME

:: ===========================================================================
::  THE DESKTOP  -  this is the label that was missing
:: ===========================================================================
:desktop
cls
color %THEME_DESKTOP%
title %OS_NAME% Desktop  (v%OS_VERSION%)

if exist "logo.txt" (
    type "logo.txt"
) else (
    echo ===============================================================================
    echo                                  %OS_NAME%
    echo ===============================================================================
)

echo  %DATE%  %TIME%          Logged in as: %OS_USER%          v%OS_VERSION% %OS_CODENAME%
if "%DEV_MODE%"=="1" echo  *** DEVELOPER MODE UNLOCKED *** commands unlocked, safety rails off
echo ===============================================================================
echo.

if not exist "menu.cfg" goto fallback_menu

:: Lines flagged "dev" in the fifth column stay off the desktop until
:: developer mode is unlocked. A line with only four columns leaves %%E
:: empty, so every menu.cfg written before dev mode existed still works.
set "row="
set "col=0"
for /f "usebackq eol=# tokens=1,2,3,4,* delims=|" %%A in ("menu.cfg") do (
    set "show=1"
    if /I "%%E"=="dev" if not "%DEV_MODE%"=="1" set "show=0"
    if "!show!"=="1" (
        set "cell=   %%A. %%B                                                  "
        set "cell=!cell:~0,38!"
        set "row=!row!!cell!"
        set /a col+=1
        if !col! GEQ 2 (
            echo !row!
            set "row="
            set "col=0"
        )
    )
)
if defined row echo !row!
goto menu_drawn

:fallback_menu
echo    1. File Explorer                     2. Notepad
echo    4. System Info                      11. Command Prompt
echo   12. Settings                          X. Shut Down
echo.
echo   [ WARNING ] menu.cfg is missing, so this is the emergency menu.

:menu_drawn
echo.
echo ===============================================================================
echo  Type a number or letter and press Enter.   H for help, X to shut down.
echo ===============================================================================

set "choice="
set /p choice="%OS_NAME%> "

:: Blank input just redraws instead of closing the window.
if not defined choice goto blank_input

:: Strip quotes so a stray " cannot break the comparison below.
set "choice=%choice:"=%"
if not defined choice goto blank_input

set "BLANKS=0"
call :log "[INP] Value: %choice%"

:: --- Look the selection up in menu.cfg -------------------------------------
set "M_LABEL="
set "M_TYPE="
set "M_TARGET="
set "M_FLAGS="
if exist "menu.cfg" (
    for /f "usebackq eol=# tokens=1,2,3,4,* delims=|" %%A in ("menu.cfg") do (
        if /I "%%A"=="%choice%" (
            set "M_LABEL=%%B"
            set "M_TYPE=%%C"
            set "M_TARGET=%%D"
            set "M_FLAGS=%%E"
        )
    )
)

if not defined M_TYPE goto badinput

:: A hidden dev item cannot be reached by typing its letter either. Without
:: this the entries would only be invisible, not actually locked.
if /I "%M_FLAGS%"=="dev" if not "%DEV_MODE%"=="1" goto locked

if /I "%M_TYPE%"=="builtin" goto run_builtin
if /I "%M_TYPE%"=="bat"     goto run_bat
if /I "%M_TYPE%"=="ps1"     goto run_ps1
if /I "%M_TYPE%"=="vbs"     goto run_vbs
if /I "%M_TYPE%"=="cmd"     goto run_cmd
if /I "%M_TYPE%"=="show"    goto run_show

echo.
echo  [ STARP-0402 ] menu.cfg line for "%choice%" has an unknown type: %M_TYPE%
pause
goto desktop

:: --- Dispatchers -----------------------------------------------------------
:run_builtin
:: Check the routine really exists before jumping. A goto to a missing label
:: is exactly the bug that used to kill this script.
findstr /r /i /c:"^:%M_TARGET%$" "%~f0" >nul 2>&1
if errorlevel 1 (
    echo.
    echo  [ STARP-0402 ] menu.cfg points at a routine that is not in this file: %M_TARGET%
    pause
    goto desktop
)
goto %M_TARGET%

:run_bat
if not exist "%M_TARGET%" goto missing_app
call :log "[LAUNCH] %M_TARGET%"
cls
:: bootcore.bat runs EVERY .bat in this folder at boot, which means a new app
:: would also fire during startup. Apps built by mkapp.ps1 check this flag and
:: return straight away unless the desktop is the one launching them.
set "STARPOS_LAUNCH=1"
call "%M_TARGET%" "%_s1%" "" "%_s3%"
set "STARPOS_LAUNCH="
goto desktop

:run_ps1
if not exist "%M_TARGET%" goto missing_app
call :log "[LAUNCH] %M_TARGET%"
cls
:: No extra arguments are passed here on purpose. A script you add to
:: menu.cfg yourself will not know about starpOS switches, and PowerShell
:: refuses to start a script that is handed a parameter it does not declare.
:: The starpOS tools that do want a log path are launched by their own
:: routines further down, which pass it explicitly.
powershell -NoProfile -ExecutionPolicy Bypass -File "%M_TARGET%"
goto desktop

:run_vbs
if not exist "%M_TARGET%" goto missing_app
call :log "[LAUNCH] %M_TARGET%"
cls
cscript //nologo "%M_TARGET%"
pause
goto desktop

:run_cmd
call :log "[LAUNCH] command: %M_TARGET%"
cls
%M_TARGET%
echo.
pause
goto desktop

:run_show
if not exist "%M_TARGET%" goto missing_app
cls
type "%M_TARGET%"
echo.
pause
goto desktop

:missing_app
call :say ERR_MISSING
color %THEME_ERROR%
echo.
echo  [ STARP-0401 ] %M_LABEL% could not be started.
echo                 The file "%M_TARGET%" is not in the system folder.
echo.
pause
goto desktop

:: Every prompt in this file routes its empty answers through one of these,
:: so no loop can run away if starpOS is ever started without a keyboard
:: attached to it.
:blank_input
set /a BLANKS+=1
if !BLANKS! LSS 30 goto desktop
goto no_input

:no_input
echo.
echo  [ INFO ] Nothing has been typed for a long time and starpOS cannot read
echo           any more input, so it is closing instead of spinning forever.
timeout /t 2 >nul
goto shutdown

:locked
call :log "[SECURITY] Locked developer item refused: %M_LABEL%"
echo.
echo  [ STARP-0801 ] "%M_LABEL%" is a developer tool and developer mode is locked.
echo                 Pick D from the desktop to unlock it.
timeout /t 3 >nul
goto desktop

:badinput
call :log "[WARNING] Invalid selection: %choice%"
call :say DESK_BADCMD
echo.
echo  [ STARP-0404 ] "%choice%" is not on the menu. Type H for help.
timeout /t 2 >nul
goto desktop

:: ===========================================================================
::  APPLICATIONS
:: ===========================================================================

:: --- File Explorer, with real navigation -----------------------------------
:explorer
call :log "[ACT] Opened File Explorer"
call :say APP_EXPLORER
if not defined EXPL_PATH set "EXPL_PATH=%ROOT%"

:explorer_loop
cls
title %OS_NAME% File Explorer
echo ===============================================================================
echo  FILE EXPLORER
echo ===============================================================================
echo  Location: !EXPL_PATH!
echo -------------------------------------------------------------------------------
set "ITEMS=0"
for /d %%D in ("!EXPL_PATH!\*") do (
    set /a ITEMS+=1
    echo    [DIR]   %%~nxD
)
for %%F in ("!EXPL_PATH!\*") do (
    set /a ITEMS+=1
    echo            %%~nxF
)
if !ITEMS! EQU 0 echo    This folder is empty.
echo -------------------------------------------------------------------------------
echo  Type a folder name to open it, .. to go up, a file name to launch it,
echo  or press Enter on its own to return to the desktop.
echo.
set "nav="
set /p nav="Explorer> "
if not defined nav goto desktop
set "nav=%nav:"=%"
if not defined nav goto desktop

if "!nav!"==".." (
    for %%P in ("!EXPL_PATH!") do set "EXPL_PATH=%%~dpP"
    if "!EXPL_PATH:~-1!"=="\" set "EXPL_PATH=!EXPL_PATH:~0,-1!"
    goto explorer_loop
)
if exist "!EXPL_PATH!\!nav!\" (
    set "EXPL_PATH=!EXPL_PATH!\!nav!"
    goto explorer_loop
)
if exist "!EXPL_PATH!\!nav!" (
    call :log "[ACT] Launched file: !nav!"
    start "" "!EXPL_PATH!\!nav!"
    goto explorer_loop
)
echo.
echo  [ STARP-0402 ] Nothing here is called "!nav!".
timeout /t 2 >nul
goto explorer_loop

:: --- Notepad, now multi line and saved to disk -----------------------------
:notepad
call :log "[ACT] Opened Notepad"
call :say APP_NOTEPAD
cls
title %OS_NAME% Notepad
echo ===============================================================================
echo  NOTEPAD
echo ===============================================================================
echo  Notes are saved into %NOTEDIR% so they are still there next boot.
echo.
set "notename="
set /p notename="Note name (blank cancels)> "
if not defined notename goto desktop

:: Strip anything that is not allowed in a file name.
set "notename=%notename:"=%"
set "notename=%notename:\=%"
set "notename=%notename:/=%"
set "notename=%notename::=%"
set "notename=%notename:<=%"
set "notename=%notename:>=%"
set "notename=%notename:|=%"
if not defined notename goto desktop

:: A wildcard in the name would make the redirect below fail, so refuse it
:: rather than silently writing to the wrong file.
echo %notename%| findstr /r "[*?]" >nul
if not errorlevel 1 (
    echo.
    echo  [ ERROR ] A note name cannot contain * or ?
    timeout /t 2 ^>nul
    goto desktop
)

set "notefile=%NOTEDIR%\%notename%.txt"
echo.
echo  Writing to %notefile%
echo  Type your note. Put a single dot on a line by itself to save and exit.
echo -------------------------------------------------------------------------------
>>"%notefile%" echo.
>>"%notefile%" echo === %notename% - %DATE% %TIME% ===

set "BLANKS=0"

:notepad_line
set "nline="
set /p nline="| "
if "!nline!"=="." goto notepad_save
if not defined nline goto notepad_blank
set "BLANKS=0"
>>"%notefile%" echo(!nline!
goto notepad_line

:: A blank line in the middle of a note is fine and gets written out. Thirty
:: of them in a row is not a person typing, so the note is saved and closed
:: rather than growing the file forever.
:notepad_blank
set /a BLANKS+=1
if !BLANKS! GEQ 30 goto notepad_save
>>"%notefile%" echo(
goto notepad_line

:notepad_save
call :log "[DATA] Saved note: %notename%"
call :say APP_NOTESAVED
echo.
echo  [ OK ] Saved to %notefile%
timeout /t 2 >nul
goto desktop

:: --- My Notes --------------------------------------------------------------
:notes
call :log "[ACT] Opened My Notes"
cls
title %OS_NAME% My Notes
echo ===============================================================================
echo  MY NOTES
echo ===============================================================================
echo  Folder: %NOTEDIR%
echo -------------------------------------------------------------------------------
dir /b "%NOTEDIR%\*.txt" 2>nul
if errorlevel 1 (
    echo    You have not written any notes yet. Use Notepad to make one.
    echo.
    pause
    goto desktop
)
echo -------------------------------------------------------------------------------
echo  Type a note name to read it, or press Enter to go back.
echo.
set "pick="
set /p pick="Notes> "
if not defined pick goto desktop
set "pick=%pick:"=%"
if not defined pick goto desktop

if exist "%NOTEDIR%\%pick%" (
    cls
    type "%NOTEDIR%\%pick%"
) else if exist "%NOTEDIR%\%pick%.txt" (
    cls
    type "%NOTEDIR%\%pick%.txt"
) else (
    echo.
    echo  [ STARP-0402 ] No note called "%pick%".
)
echo.
pause
goto notes

:: --- System Info, the starpOS identity block -------------------------------
:sysinfo
call :log "[ACT] Opened System Info"
call :say APP_SYSINFO
cls
title %OS_NAME% System Info
echo ===============================================================================
echo  SYSTEM INFORMATION
echo ===============================================================================
echo.
echo   OS Name       : %OS_NAME%
echo   Version       : %OS_VERSION%  "%OS_CODENAME%"
echo   Build         : %OS_BUILD%
echo   Architecture  : %OS_ARCH%
echo   Developer     : %OS_DEVELOPER%
echo   Session user  : %OS_USER%
echo   Shell         : startup.bat v2.0
echo   System folder : %SYS%
echo   Root folder   : %ROOT%
echo   Kernel log    : %_s1%
echo   User log      : %_s3%
echo   Voice output  : %VOICE_ENABLED%
echo   Theme         : %THEME_DESKTOP%
echo.
echo   For the real CPU, memory and disk figures, pick Real Machine Specs
echo   from the desktop instead.
echo.
pause
goto desktop

:: --- Real machine specs ----------------------------------------------------
:realinfo
call :log "[ACT] Opened Real Machine Specs"
call :say APP_REALINFO
cls
if not exist "sysinfo.ps1" (
    set "M_LABEL=Real Machine Specs"
    set "M_TARGET=sysinfo.ps1"
    goto missing_app
)
powershell -NoProfile -ExecutionPolicy Bypass -File "sysinfo.ps1"
goto desktop

:: --- Voice control ---------------------------------------------------------
:: Launched from here rather than straight from menu.cfg so the log path can
:: be handed over, which the generic ps1 launcher deliberately does not do.
:voicectl
call :log "[ACT] Opened Voice Control"
call :say APP_VOICE
cls
if not exist "voice.ps1" (
    set "M_LABEL=Voice Control"
    set "M_TARGET=voice.ps1"
    goto missing_app
)
powershell -NoProfile -ExecutionPolicy Bypass -File "voice.ps1" -Log "%_s1%"
goto desktop

:: --- Log viewer ------------------------------------------------------------
:logs
call :log "[ACT] Opened Log Viewer"
call :say APP_LOGS
cls
if not exist "logview.ps1" (
    set "M_LABEL=Log Viewer"
    set "M_TARGET=logview.ps1"
    goto missing_app
)
powershell -NoProfile -ExecutionPolicy Bypass -File "logview.ps1"
goto desktop

:: --- Task manager ----------------------------------------------------------
:tasks
call :log "[ACT] Opened Task Manager"
call :say APP_TASKS
cls
title %OS_NAME% Task Manager
echo ===============================================================================
echo  TASK MANAGER
echo ===============================================================================
echo.
tasklist /NH /FI "STATUS eq RUNNING"
echo.
echo -------------------------------------------------------------------------------
pause
goto desktop

:: --- Search ----------------------------------------------------------------
:search
call :log "[ACT] Opened Search"
cls
title %OS_NAME% Search
echo ===============================================================================
echo  SEARCH FILES
echo ===============================================================================
echo  Searches everything under %ROOT%
echo.
set "term="
set /p term="Find files named> "
if not defined term goto desktop
set "term=%term:"=%"
if not defined term goto desktop

call :say APP_SEARCH
echo.
echo  Searching for *%term%* ...
echo -------------------------------------------------------------------------------
dir /s /b "%ROOT%\*%term%*" 2>nul
if errorlevel 1 (
    echo.
    echo  [ STARP-0402 ] Nothing matched "%term%".
)
echo -------------------------------------------------------------------------------
echo.
pause
goto desktop

:: --- Calculator ------------------------------------------------------------
:calc
call :log "[ACT] Opened Calculator"
call :say APP_CALC
cls
if not exist "calc.ps1" (
    set "M_LABEL=Calculator"
    set "M_TARGET=calc.ps1"
    goto missing_app
)
powershell -NoProfile -ExecutionPolicy Bypass -File "calc.ps1"
goto desktop

:: --- Clock -----------------------------------------------------------------
:clock
call :log "[ACT] Opened Clock"
title %OS_NAME% Clock

:clock_loop
cls
echo.
echo.
echo ===============================================================================
echo.
echo                                %TIME:~0,8%
echo.
echo                              %DATE%
echo.
echo ===============================================================================
echo.
echo                        Press Q to return to the desktop.
:: choice waits one second then ticks over on its own, so the clock updates
:: without the window sitting there frozen waiting for a key.
choice /c QR /n /t 1 /d R >nul
if errorlevel 2 goto clock_loop
goto desktop

:: --- Command prompt --------------------------------------------------------
:cmdprompt
call :log "[SHL] Console opened"
call :say APP_SHELL
cls
title %OS_NAME% Command Line
echo ===============================================================================
echo  %OS_NAME% TERMINAL
echo ===============================================================================
echo  This is a real command prompt. Type exit to come back to the desktop.
echo.
cmd /k
goto desktop

:: --- Settings, and they actually save now ----------------------------------
:settings
call :log "[ACT] Opened Settings"
call :say APP_SETTINGS

:settings_loop
cls
title %OS_NAME% Settings
echo ===============================================================================
echo  SETTINGS
echo ===============================================================================
echo.
echo   Current theme : %THEME_DESKTOP%          Voice output : %VOICE_ENABLED%
echo.
echo   THEME
echo     1. Classic Blue      2. Matrix Green     3. Amber Terminal
echo     4. Hacker Red        5. Paper White      6. Midnight
echo.
echo   OTHER
echo     7. Turn voice output on or off
echo     8. Save this look as the default for every boot
echo     9. Change the session user name
echo     0. Back to the desktop
echo.
echo ===============================================================================
set "sc="
set /p sc="Settings> "
if not defined sc goto settings_blank
set "BLANKS=0"

if "%sc%"=="1" set "THEME_DESKTOP=1F"
if "%sc%"=="2" set "THEME_DESKTOP=0A"
if "%sc%"=="3" set "THEME_DESKTOP=06"
if "%sc%"=="4" set "THEME_DESKTOP=4E"
if "%sc%"=="5" set "THEME_DESKTOP=F0"
if "%sc%"=="6" set "THEME_DESKTOP=17"
if "%sc%"=="7" goto settings_voice
if "%sc%"=="8" goto settings_save
if "%sc%"=="9" goto settings_user
if "%sc%"=="0" goto desktop

color %THEME_DESKTOP%
goto settings_loop

:settings_blank
set /a BLANKS+=1
if !BLANKS! LSS 30 goto settings_loop
goto no_input

:settings_voice
if "%VOICE_ENABLED%"=="1" (
    set "VOICE_ENABLED=0"
    echo.
    echo  Voice output is now OFF.
) else (
    set "VOICE_ENABLED=1"
    call :say SET_VOICEON
    echo.
    echo  Voice output is now ON.
)
timeout /t 1 >nul
goto settings_loop

:settings_user
echo.
set "nu="
set /p nu="New session name> "
if not defined nu goto settings_loop
set "nu=%nu:"=%"
if not defined nu goto settings_loop
set "OS_USER=%nu%"
call :log "[USER_MGMT] Session name changed to %OS_USER%"
goto settings_loop

:settings_save
if not exist "setcfg.ps1" (
    echo.
    echo  [ STARP-0402 ] setcfg.ps1 is missing, so settings cannot be saved.
    pause
    goto settings_loop
)
echo.
echo  Saving into starpos.cfg ...
powershell -NoProfile -ExecutionPolicy Bypass -File "setcfg.ps1" -Key THEME_DESKTOP -Value "%THEME_DESKTOP%"
powershell -NoProfile -ExecutionPolicy Bypass -File "setcfg.ps1" -Key VOICE_ENABLED -Value "%VOICE_ENABLED%"
call :log "[SYSTEM] Settings saved to starpos.cfg"
call :say SET_SAVED
echo.
pause
goto settings_loop

:: --- Help ------------------------------------------------------------------
:help
call :log "[ACT] Opened Help"
call :say APP_HELP
cls
title %OS_NAME% Help
if exist "help.txt" (
    type "help.txt"
) else (
    echo  help.txt is missing from the system folder.
)
echo.
echo  Menu items come from menu.cfg. Open it in Notepad to add your own apps.
echo  Error numbers are explained in errors.txt.
echo.
pause
goto desktop

:: --- About -----------------------------------------------------------------
:about
cls
title About %OS_NAME%
if exist "logo.txt" type "logo.txt"
echo.
if exist "version.txt" (
    type "version.txt"
) else (
    echo   %OS_NAME% v%OS_VERSION%  "%OS_CODENAME%"
    echo   Built by %OS_DEVELOPER%
)
echo.
pause
goto desktop

:: ===========================================================================
::  DEVELOPER MODE
::  Everything below is gated on DEV_MODE=1. Unlocking turns on the raw
::  command console, reveals every menu.cfg line flagged "dev", and lets the
::  repair, scan, log editing, app building and install tools run.
:: ===========================================================================
:devmode
if "%DEV_MODE%"=="1" goto devmode_menu

cls
color %THEME_ERROR%
title %OS_NAME% Developer Unlock
echo ===============================================================================
echo  DEVELOPER MODE
echo ===============================================================================
echo.
echo   Developer mode unlocks tools that can change and delete real files:
echo.
echo     - a console that runs any command you type, with nothing blocked
echo     - a repair tool that rewrites broken config and rebuilds folders
echo     - a log editor that can delete lines and wipe whole streams
echo     - an installer that registers new programs into starpOS
echo.
echo   [WARN] this is your own risk one wrong move an the system is gone ples be carfull.
echo.
echo   Press Enter on its own to go back to the desktop.
echo ===============================================================================
echo.
set "dpass="
set /p dpass="Developer password> "
if not defined dpass goto desktop

if not "%dpass%"=="%DEV_PASS%" (
    call :log "[SECURITY_ALERT] Failed developer unlock attempt"
    echo.
    echo  [ STARP-0802 ] Wrong password. Developer mode stays locked.
    timeout /t 3 >nul
    goto desktop
)

set "DEV_MODE=1"
call :log "[DEV] Developer mode unlocked by %OS_USER%"
echo.
echo  [ OK ] Developer mode unlocked for this session.
timeout /t 2 >nul

:devmode_menu
cls
color %THEME_ERROR%
title %OS_NAME% Developer Tools
echo ===============================================================================
echo  DEVELOPER TOOLS                                        %OS_NAME% v%OS_VERSION%
echo ===============================================================================
echo.
echo    1. Dev Console            Run any command. Nothing is blocked.
echo    2. Advanced System Scan   Deep read-only check of every file
echo    3. Instant Error Repair   Find known faults and fix them
echo    4. Log Editor             View, filter, delete and add log lines
echo    5. Create New App         Build a working app from a template
echo    6. Install App            Register a program onto the desktop
echo.
echo    7. Reload config and menu without rebooting
echo    8. Remember developer mode for next boot
echo    9. Lock developer mode again
echo    0. Back to the desktop
echo.
echo ===============================================================================
echo  Dev items on the desktop right now: C S R L N I
echo ===============================================================================
echo.
set "dv="
set /p dv="DEV> "
if not defined dv goto devmode_blank
set "BLANKS=0"

if "%dv%"=="1" goto devconsole
if "%dv%"=="2" goto devscan
if "%dv%"=="3" goto devrepair
if "%dv%"=="4" goto devlogs
if "%dv%"=="5" goto devnew
if "%dv%"=="6" goto devinstall
if "%dv%"=="7" goto devreload
if "%dv%"=="8" goto devremember
if "%dv%"=="9" goto devlock
if "%dv%"=="0" goto desktop
goto devmode_menu

:devmode_blank
set /a BLANKS+=1
if !BLANKS! LSS 30 goto devmode_menu
goto no_input

:: --- The unlocked console --------------------------------------------------
:devconsole
call :log "[DEV] Opened dev console"
cls
color %THEME_ERROR%
title %OS_NAME% Developer Console
echo ===============================================================================
echo  DEVELOPER CONSOLE                              everything you type is logged
echo ===============================================================================
echo.
echo   Whatever you type runs exactly as typed. There is no filtering here.
echo   Type  exit  to go back to the developer menu.
echo.
echo   Handy ones:
echo     dir /b              list this folder
echo     type menu.cfg       read the desktop menu
echo     tasklist            everything running
echo     ipconfig            network settings
echo     powershell -NoProfile -Command "Get-Date"
echo.
echo ===============================================================================

:devconsole_loop
echo.
set "dcmd="
set /p dcmd="DEV %CD%> "
if not defined dcmd goto devconsole_blank
set "BLANKS=0"
if /I "!dcmd!"=="exit" goto devmode_menu
if /I "!dcmd!"=="quit" goto devmode_menu

call :log "[DEV] Console command: !dcmd!"
echo -------------------------------------------------------------------------------
!dcmd!
echo -------------------------------------------------------------------------------
goto devconsole_loop

:devconsole_blank
set /a BLANKS+=1
if !BLANKS! LSS 30 goto devconsole_loop
goto no_input

:: --- Developer tools that live in their own files --------------------------
:devscan
call :log "[DEV] Ran advanced system scan"
cls
if not exist "scan.ps1" (
    set "M_LABEL=Advanced System Scan"
    set "M_TARGET=scan.ps1"
    goto missing_app
)
powershell -NoProfile -ExecutionPolicy Bypass -File "scan.ps1" -Log "%_s1%"
goto devmode_menu

:devrepair
call :log "[DEV] Ran error repair"
cls
if not exist "repair.ps1" (
    set "M_LABEL=Instant Error Repair"
    set "M_TARGET=repair.ps1"
    goto missing_app
)
powershell -NoProfile -ExecutionPolicy Bypass -File "repair.ps1" -Log "%_s1%"
goto devmode_menu

:devlogs
call :log "[DEV] Opened log editor"
cls
if not exist "logedit.ps1" (
    set "M_LABEL=Log Editor"
    set "M_TARGET=logedit.ps1"
    goto missing_app
)
powershell -NoProfile -ExecutionPolicy Bypass -File "logedit.ps1"
goto devmode_menu

:devnew
call :log "[DEV] Opened app builder"
cls
if not exist "mkapp.ps1" (
    set "M_LABEL=Create New App"
    set "M_TARGET=mkapp.ps1"
    goto missing_app
)
powershell -NoProfile -ExecutionPolicy Bypass -File "mkapp.ps1"
goto devmode_menu

:devinstall
call :log "[DEV] Opened installer"
cls
if not exist "install.ps1" (
    set "M_LABEL=Install App"
    set "M_TARGET=install.ps1"
    goto missing_app
)
powershell -NoProfile -ExecutionPolicy Bypass -File "install.ps1"
goto devmode_menu

:: --- Reload without rebooting ----------------------------------------------
:devreload
echo.
echo  Re-reading starpos.cfg ...
if exist "starpos.cfg" (
    for /f "usebackq eol=# tokens=1,* delims==" %%A in ("starpos.cfg") do set "%%A=%%B"
)
:: A reload must not lock the session out from under itself, so dev mode
:: stays on until it is turned off deliberately.
set "DEV_MODE=1"
call :log "[DEV] Reloaded configuration"
echo  [ OK ] Config reloaded. menu.cfg is read fresh every time the desktop draws,
echo         so any menu changes are already live.
echo.
pause
goto devmode_menu

:devremember
if not exist "setcfg.ps1" (
    echo.
    echo  [ STARP-0402 ] setcfg.ps1 is missing, so this cannot be saved.
    pause
    goto devmode_menu
)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "setcfg.ps1" -Key DEV_MODE -Value 1
call :log "[DEV] Developer mode saved as the default"
echo.
echo  starpOS will now boot straight into developer mode. Pick 9 and save
echo  again to undo that.
echo.
pause
goto devmode_menu

:devlock
set "DEV_MODE=0"
call :log "[DEV] Developer mode locked"
if exist "setcfg.ps1" powershell -NoProfile -ExecutionPolicy Bypass -File "setcfg.ps1" -Key DEV_MODE -Value 0 -Quiet
echo.
echo  [ OK ] Developer mode locked and saved. The dev items are hidden again.
timeout /t 2 >nul
goto desktop

:: --- Shut down -------------------------------------------------------------
:shutdown
call :log "[PWR] Shutdown requested by %OS_USER%"
call :say PWR_DOWN
cls
color %THEME_ERROR%
echo.
echo ===============================================================================
echo                        Shutting down %OS_NAME% ...
echo ===============================================================================
echo.
timeout /t 2 >nul
popd
endlocal
exit

:: ===========================================================================
::  HELPER ROUTINES
:: ===========================================================================

:: Write one line to both log streams.
:log
if defined _s1 >>"%_s1%" echo [%TIME%] %~1
if defined _s3 >>"%_s3%" echo [%TIME%] %~1
goto :eof

:: Speak a phrase looked up by ID from voicebank.txt.
:say
if not "%VOICE_ENABLED%"=="1" goto :eof
if not exist "speak.vbs" goto :eof
if not exist "voicebank.txt" goto :eof
set "_ph="
for /f "usebackq eol=# tokens=1,* delims=|" %%A in ("voicebank.txt") do (
    if /I "%%A"=="%~1" set "_ph=%%B"
)
if defined _ph cscript //nologo "speak.vbs" "!_ph!" >nul 2>&1
goto :eof
