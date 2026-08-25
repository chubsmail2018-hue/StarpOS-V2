@echo off
:: ===========================================================================
::  ai.bat  -  starpOS AI ASSISTANT   /   engine 5.0  "STARP core"
:: ===========================================================================
::  A full offline assistant. It holds a conversation in plain English, runs
::  the system tools, remembers things between sessions and speaks out loud
::  through speak.vbs. No internet and no external program is required.
::
::  HOW TO START IT
::     From the desktop ....... press 7
::     By hand ................ call ai.bat
::     Ask one question ....... ai.bat "what time is it"
::     Start without speech ... ai.bat /quiet
::
::  ARGUMENTS  same shape as Voice.bat so either shell can pass its streams:
::     ai.bat [primary_log] [reserved] [secondary_log]
::  Anything in slot 1 that does not end in .log is treated as a question.
::
::  FILES IT OWNS  all live in the data folder and are created on demand:
::     ai_memory.db     facts it was told to remember, one key pair per line
::     ai_notes.txt     notes taken with the note command
::     ai_history.log   every line typed at the prompt
::     ai_unknown.txt   questions it could not answer, so you can teach it
::
::  SETTINGS come from starpos.cfg: VOICE_ENABLED, VOICE_RATE, VOICE_VOLUME,
::  OS_NAME, OS_VERSION, OS_CODENAME, OS_DEVELOPER, APP_REGISTRY, USER_DB.
::
::  ERROR CODES  STARP-0401 module, STARP-0501 no voice, STARP-0502 no
::  speak.vbs, STARP-0202 log stream unwritable. All listed in errors.txt.
::
::  NOTE  this is a batch file, so the characters  and  ^  and  "  typed at
::  the prompt can confuse the command parser. Plain words always work.
:: ===========================================================================

setlocal EnableExtensions EnableDelayedExpansion
title starpOS AI Assistant

call :init %*
if defined ONESHOT (
    set "ai_in=!ONESHOT!"
    call :ai_record
    goto route
)
goto do_board

:: ===========================================================================
::  INITIALISATION
:: ===========================================================================
:init
set "AI_NAME=STARP"
set "AI_VER=6.0"
set "SYS=%~dp0"
set "DATA=%SYS%..\data"
set "CFG=%SYS%starpos.cfg"
set "SPEAKER=%SYS%speak.vbs"
set "MEMFILE=%DATA%\ai_memory.db"
set "NOTEFILE=%DATA%\ai_notes.txt"
set "HISTFILE=%DATA%\ai_history.log"
set "UNKFILE=%DATA%\ai_unknown.txt"
set "BRAINFILE=%DATA%\ai_brain.db"
set "PLACES=%SYS%places.cfg"
set "LASTUNKNOWN="
set "BLANKS=0"
set "ONESHOT="
set "TURN=0"

:: --- identity and settings out of starpos.cfg, with safe fallbacks --------
call :cfg_get OS_NAME       OS_NAME
call :cfg_get OS_VERSION    OS_VERSION
call :cfg_get OS_CODENAME   OS_CODENAME
call :cfg_get OS_DEVELOPER  OS_DEVELOPER
call :cfg_get VOICE_ENABLED AI_VOICE
call :cfg_get VOICE_RATE    VOICE_RATE
call :cfg_get VOICE_VOLUME  VOICE_VOLUME
call :cfg_get APP_REGISTRY  APPSREG
call :cfg_get USER_DB       USERDB
call :cfg_get DEFAULT_USER  WHOAMI

if not defined OS_NAME      set "OS_NAME=starpOS"
if not defined OS_VERSION   set "OS_VERSION=1.3.0"
if not defined OS_CODENAME  set "OS_CODENAME=Northstar"
if not defined OS_DEVELOPER set "OS_DEVELOPER=ScottSoft Team"
if not defined AI_VOICE     set "AI_VOICE=1"
if not defined VOICE_RATE   set "VOICE_RATE=0"
if not defined VOICE_VOLUME set "VOICE_VOLUME=100"
if not defined APPSREG      set "APPSREG=apps.reg"
if not defined USERDB       set "USERDB=users.db"
if not defined WHOAMI       set "WHOAMI=Admin"
set "APPSREG=%SYS%!APPSREG!"
set "USERDB=%SYS%!USERDB!"

:: --- log streams: arguments win, then the kernel variables, then defaults -
set "LOG1=%DATA%\1.log"
set "LOG3=%DATA%\3.log"
if defined _s1 set "LOG1=%_s1%"
if defined _s3 set "LOG3=%_s3%"

set "A1=%~1"
set "A3=%~3"
if defined A3 set "LOG3=!A3!"
if defined A1 (
    if /i "!A1:~-4!"==".log" (
        set "LOG1=!A1!"
    ) else if /i "!A1!"=="/quiet" (
        set "AI_VOICE=0"
        if not "%~2"=="" set "ONESHOT=%~2"
    ) else if /i "!A1!"=="/q" (
        set "AI_VOICE=0"
        if not "%~2"=="" set "ONESHOT=%~2"
    ) else (
        if "%~2"=="" ( set "ONESHOT=%~1" ) else ( set "ONESHOT=%*" )
    )
)

:: --- the data folder has to exist before anything is written to it --------
if not exist "%DATA%" md "%DATA%" >nul 2>nul
if not exist "%MEMFILE%" (
    >"%MEMFILE%" echo # starpOS AI memory. One key pair per line, pipe separated.
    >>"%MEMFILE%" echo # Written by ai.bat. Safe to edit by hand or delete.
)
call :brain_init

:: --- the voice engine is optional, never fatal ---------------------------
set "VOICE_NOTE="
if not exist "%SPEAKER%" (
    set "AI_VOICE=0"
    set "VOICE_NOTE=STARP-0502 speak.vbs missing, running silent"
)

:: --- remembered preferences ----------------------------------------------
call :mem_get name  USER_NAME
call :mem_get theme AI_THEME
call :mem_get themename THEMENAME
call :mem_get box BOXSTYLE
if not defined AI_THEME set "AI_THEME=1F"
color !AI_THEME! 2>nul
call :brand_init
call :theme_presets
call :box_apply

call :log "AI engine !AI_VER! online"
goto :eof

:: ===========================================================================
::  CORE HELPERS
:: ===========================================================================

:: --- read one KEY=VALUE out of starpos.cfg:  call :cfg_get KEY VARNAME ----
:cfg_get
set "%~2="
if not exist "%CFG%" goto :eof
for /f "usebackq eol=# tokens=1,* delims==" %%A in (`findstr /b /i /c:"%~1=" "%CFG%"`) do set "%~2=%%B"
goto :eof

:: --- write one line into both log streams --------------------------------
:log
if defined LOG1 >>"%LOG1%" echo [%TIME%] [AI] %~1 2>nul
if defined LOG3 >>"%LOG3%" echo [%TIME%] [AI] %~1 2>nul
goto :eof

:: --- speak, if a voice is available. Never stops the assistant. ----------
:say
if "!AI_VOICE!"=="0" goto :eof
if not exist "%SPEAKER%" goto :eof
cscript //nologo "%SPEAKER%" "%~1" !VOICE_RATE! !VOICE_VOLUME! >nul 2>nul
if errorlevel 2 (
    set "AI_VOICE=0"
    set "VOICE_NOTE=STARP-0501 no SAPI voice, running silent"
)
goto :eof

:: --- the assistant says one line: on screen and out loud -----------------
:reply
echo   %AI_NAME%: %~1
call :say "%~1"
goto :eof

:: --- screen only, no speech. Used for lists and tables. ------------------
:print
echo   %AI_NAME%: %~1
goto :eof

:: --- lowercase LOWIN into LOWOUT. Batch replace is case insensitive. -----
:lower
set "LOWOUT=!LOWIN!"
set "LOWOUT=!LOWOUT:A=a!"
set "LOWOUT=!LOWOUT:B=b!"
set "LOWOUT=!LOWOUT:C=c!"
set "LOWOUT=!LOWOUT:D=d!"
set "LOWOUT=!LOWOUT:E=e!"
set "LOWOUT=!LOWOUT:F=f!"
set "LOWOUT=!LOWOUT:G=g!"
set "LOWOUT=!LOWOUT:H=h!"
set "LOWOUT=!LOWOUT:I=i!"
set "LOWOUT=!LOWOUT:J=j!"
set "LOWOUT=!LOWOUT:K=k!"
set "LOWOUT=!LOWOUT:L=l!"
set "LOWOUT=!LOWOUT:M=m!"
set "LOWOUT=!LOWOUT:N=n!"
set "LOWOUT=!LOWOUT:O=o!"
set "LOWOUT=!LOWOUT:P=p!"
set "LOWOUT=!LOWOUT:Q=q!"
set "LOWOUT=!LOWOUT:R=r!"
set "LOWOUT=!LOWOUT:S=s!"
set "LOWOUT=!LOWOUT:T=t!"
set "LOWOUT=!LOWOUT:U=u!"
set "LOWOUT=!LOWOUT:V=v!"
set "LOWOUT=!LOWOUT:W=w!"
set "LOWOUT=!LOWOUT:X=x!"
set "LOWOUT=!LOWOUT:Y=y!"
set "LOWOUT=!LOWOUT:Z=z!"
goto :eof

:: --- read a line without delayed expansion eating the punctuation --------
:ai_read
setlocal DisableDelayedExpansion
set "ai_raw="
set "ai_prompt=%~1"
if not defined ai_prompt set "ai_prompt=  you: "
set /p "ai_raw=%ai_prompt%"
(
    endlocal
    set "ai_in=%ai_raw%"
    goto :eof
)

:: --- strip the spaces off both ends --------------------------------------
:ai_trim
if not defined ai_in goto :eof
if "!ai_in:~0,1!"==" " (
    set "ai_in=!ai_in:~1!"
    goto ai_trim
)
if "!ai_in:~-1!"==" " (
    set "ai_in=!ai_in:~0,-1!"
    goto ai_trim
)
goto :eof

:: --- history, logging, and the normalised copies the matcher works on ----
:ai_record
set /a TURN+=1
set ai_safe=!ai_in:"=!
>>"%HISTFILE%" echo [%DATE% %TIME%] !ai_safe! 2>nul
call :log "input: !ai_safe!"
set "LOWIN=!ai_safe!"
call :lower
set "m=!LOWOUT!"
set "m=!m:?=!"
set "m=!m:.=!"
set "m=!m:,=!"
set "m=!m:;=!"
set "m= !m! "
set "cmd="
set "arg="
for /f "tokens=1,* delims= " %%A in ("!ai_safe!") do (
    set "cmd=%%A"
    set "arg=%%B"
)
set "LOWIN=!cmd!"
call :lower
set "cmd=!LOWOUT!"
goto :eof

:: --- memory: read one key -------------------------------------------------
:mem_get
set "%~2="
if not exist "%MEMFILE%" goto :eof
for /f "usebackq eol=# tokens=1,* delims=|" %%A in ("%MEMFILE%") do (
    if /i "%%A"=="%~1" set "%~2=%%B"
)
goto :eof

:: --- memory: write one key, replacing any older copy of it ---------------
:mem_set
if exist "%MEMFILE%" (
    findstr /v /b /i /c:"%~1|" "%MEMFILE%" > "%MEMFILE%.tmp" 2>nul
    move /y "%MEMFILE%.tmp" "%MEMFILE%" >nul 2>nul
)
>>"%MEMFILE%" echo %~1^|%~2
goto :eof

:: --- memory: drop one key -------------------------------------------------
:mem_del
if not exist "%MEMFILE%" goto :eof
findstr /v /b /i /c:"%~1|" "%MEMFILE%" > "%MEMFILE%.tmp" 2>nul
move /y "%MEMFILE%.tmp" "%MEMFILE%" >nul 2>nul
goto :eof

:: --- pick a random line out of a numbered set: call :pick prefix count ---
:pick
set /a PICKN=!RANDOM! %% %~2 + 1
for %%X in (!PICKN!) do set "PICKED=!%~1%%X!"
goto :eof

:: ===========================================================================
::  MAIN CONVERSATION LOOP
:: ===========================================================================
:chat
if defined ONESHOT goto quiet_exit
echo.
set "ai_in="
call :ai_read
call :ai_trim
if not defined ai_in (
    set /a BLANKS+=1
    if !BLANKS! geq 25 (
        echo   !AI_NAME!: The keyboard has gone quiet, so I am closing down.
        call :log "input stream ended, engine closed"
        exit /b 0
    )
    goto chat
)
set "BLANKS=0"
call :ai_record

:: ===========================================================================
::  ROUTER  -  exact commands first, then plain English, then the fallback
:: ===========================================================================
:route
if not defined cmd goto chat

:: --- one digit on its own is a menu choice -------------------------------
if "!ai_safe!"=="1" goto do_status
if "!ai_safe!"=="2" goto do_tasks
if "!ai_safe!"=="3" goto do_scan
if "!ai_safe!"=="4" goto do_apps
if "!ai_safe!"=="5" goto do_notes
if "!ai_safe!"=="6" goto do_memory
if "!ai_safe!"=="7" goto do_log
if "!ai_safe!"=="8" goto do_help
if "!ai_safe!"=="9" goto do_exit
if "!ai_safe!"=="0" goto do_brain

:: --- system and file commands --------------------------------------------
if "!cmd!"=="help"      goto do_help
if "!cmd!"=="?"         goto do_help
if "!cmd!"=="commands"  goto do_help
if "!cmd!"=="menu"      goto do_menu
if "!cmd!"=="board"     goto do_board
if "!cmd!"=="home"      goto do_board
if "!cmd!"=="codes"     goto do_codes
if "!cmd!"=="callsigns" goto do_codes
if "!cmd!"=="features"  goto do_features
if "!cmd!"=="fifty"     goto do_features
if "!cmd!"=="box"       goto do_box
if "!cmd!"=="border"    goto do_box
if "!cmd!"=="status"    goto do_status
if "!cmd!"=="sysinfo"   goto do_status
if "!cmd!"=="scan"      goto do_scan
if "!cmd!"=="check"     goto do_scan
if "!cmd!"=="tasks"     goto do_tasks
if "!cmd!"=="automate"  goto do_tasks
if "!cmd!"=="apps"      goto do_apps
if "!cmd!"=="open"      goto do_open
if "!cmd!"=="run"       goto do_open
if "!cmd!"=="launch"    goto do_open
if "!cmd!"=="find"      goto do_find
if "!cmd!"=="search"    goto do_find
if "!cmd!"=="list"      goto do_list
if "!cmd!"=="dir"       goto do_list
if "!cmd!"=="read"      goto do_readfile
if "!cmd!"=="type"      goto do_readfile
if "!cmd!"=="log"       goto do_log
if "!cmd!"=="logs"      goto do_log
if "!cmd!"=="error"     goto do_error
if "!cmd!"=="users"     goto do_users
if "!cmd!"=="version"   goto do_version
if "!cmd!"=="logo"      goto do_logo
if "!cmd!"=="motd"      goto do_motd
if "!cmd!"=="history"   goto do_history

:: --- memory and notes -----------------------------------------------------
if "!cmd!"=="note"      goto do_note
if "!cmd!"=="notes"     goto do_notes
if "!cmd!"=="remember"  goto do_remember
if "!cmd!"=="recall"    goto do_recall
if "!cmd!"=="forget"    goto do_forget
if "!cmd!"=="memory"    goto do_memory
if "!cmd!"=="name"      goto do_name

:: --- learning -------------------------------------------------------------
if "!cmd!"=="teach"     goto do_teach
if "!cmd!"=="learn"     goto do_teach
if "!cmd!"=="unteach"   goto do_unteach
if "!cmd!"=="train"     goto do_train
if "!cmd!"=="training"  goto do_train
if "!cmd!"=="brain"     goto do_brain
if "!cmd!"=="learned"   goto do_brain
if "!cmd!"=="lessons"   goto do_brain

:: --- tools ----------------------------------------------------------------
if "!cmd!"=="calc"      goto do_calc
if "!cmd!"=="math"      goto do_calc
if "!cmd!"=="timer"     goto do_timer
if "!cmd!"=="countdown" goto do_timer
if "!cmd!"=="time"      goto do_time
if "!cmd!"=="clock"     goto do_time
if "!cmd!"=="date"      goto do_date
if "!cmd!"=="day"       goto do_date
if "!cmd!"=="weather"   goto do_weather
if "!cmd!"=="flip"      goto do_flip
if "!cmd!"=="coin"      goto do_flip
if "!cmd!"=="roll"      goto do_roll
if "!cmd!"=="dice"      goto do_roll
if "!cmd!"=="random"    goto do_random
if "!cmd!"=="pick"      goto do_random

:: --- voice, look and feel -------------------------------------------------
if "!cmd!"=="speak"     goto do_speak
if "!cmd!"=="say"       goto do_speak
if "!cmd!"=="voice"     goto do_voice
if "!cmd!"=="mute"      goto do_mute
if "!cmd!"=="theme"     goto do_theme
if "!cmd!"=="color"     goto do_theme
if "!cmd!"=="colour"    goto do_theme
if "!cmd!"=="cls"       goto do_clear
if "!cmd!"=="clear"     goto do_clear

:: --- chit chat ------------------------------------------------------------
if "!cmd!"=="joke"      goto do_joke
if "!cmd!"=="fact"      goto do_fact
if "!cmd!"=="quote"     goto do_quote
if "!cmd!"=="about"     goto do_about
if "!cmd!"=="whoami"    goto do_whoami

:: --- leaving --------------------------------------------------------------
if "!cmd!"=="exit"      goto do_exit
if "!cmd!"=="quit"      goto do_exit
if "!cmd!"=="bye"       goto do_exit
if "!cmd!"=="goodbye"   goto do_exit
if "!cmd!"=="logout"    goto do_exit
if "!cmd!"=="shutdown"  goto do_exit

:: ===========================================================================
::  PLAIN ENGLISH MATCHING
::  Every test asks: does the sentence contain this phrase.
:: ===========================================================================

:: --- questions about the clock and the calendar --------------------------
:: --- a bare call sign beats everything except a real command ------------
call :read_code
if defined PL_CODE goto place_open

if not "!m:what time=!"=="!m!"        goto do_time
if not "!m:the time=!"=="!m!"         goto do_time
if not "!m:what day=!"=="!m!"         goto do_date
if not "!m:what is the date=!"=="!m!" goto do_date
if not "!m:todays date=!"=="!m!"      goto do_date

:: --- who and what am I ----------------------------------------------------
if not "!m: your name=!"=="!m!"       goto do_about
if not "!m:who are you=!"=="!m!"      goto do_about
if not "!m:what are you=!"=="!m!"     goto do_about
if not "!m:who made you=!"=="!m!"     goto do_maker
if not "!m:who built you=!"=="!m!"    goto do_maker
if not "!m:who created you=!"=="!m!"  goto do_maker
if not "!m:are you real=!"=="!m!"     goto do_alive
if not "!m:are you alive=!"=="!m!"    goto do_alive
if not "!m:are you human=!"=="!m!"    goto do_alive
if not "!m:who am i=!"=="!m!"         goto do_whoami

:: --- greetings and manners ------------------------------------------------
set "SHORTIN=1"
if not "!m:~26!"=="" set "SHORTIN="
if defined SHORTIN if not "!m: hello =!"=="!m!"  goto do_hello
if defined SHORTIN if not "!m: hi =!"=="!m!"     goto do_hello
if defined SHORTIN if not "!m: hey =!"=="!m!"    goto do_hello
if defined SHORTIN if not "!m: yo =!"=="!m!"     goto do_hello
if not "!m:good morning=!"=="!m!"     goto do_hello
if not "!m:good evening=!"=="!m!"     goto do_hello
if not "!m:how are you=!"=="!m!"      goto do_howareyou
if not "!m:thank you=!"=="!m!"        goto do_thanks
if not "!m: thanks=!"=="!m!"          goto do_thanks
if not "!m: sorry=!"=="!m!"           goto do_sorry
if not "!m:i love you=!"=="!m!"       goto do_love
if not "!m:good job=!"=="!m!"         goto do_praise
if not "!m:well done=!"=="!m!"        goto do_praise
if not "!m:youre stupid=!"=="!m!"     goto do_insult
if not "!m:you are stupid=!"=="!m!"   goto do_insult
if not "!m:you suck=!"=="!m!"         goto do_insult
if not "!m: shut up=!"=="!m!"         goto do_mute
if not "!m:be quiet=!"=="!m!"         goto do_mute
if not "!m:my name is=!"=="!m!"       goto nl_name
if not "!m:call me =!"=="!m!"         goto nl_name

:: --- asking for the tools by description ---------------------------------
if not "!m:what can you do=!"=="!m!"  goto do_help
if not "!m:help me=!"=="!m!"          goto do_help
if not "!m:tell me a joke=!"=="!m!"   goto do_joke
if not "!m: joke=!"=="!m!"            goto do_joke
if not "!m:tell me a fact=!"=="!m!"   goto do_fact
if not "!m:something interesting=!"=="!m!" goto do_fact
if not "!m:flip a coin=!"=="!m!"      goto do_flip
if not "!m:roll a dice=!"=="!m!"      goto do_roll
if not "!m:roll the dice=!"=="!m!"    goto do_roll
if not "!m:the weather=!"=="!m!"      goto do_weather
if not "!m:sing =!"=="!m!"            goto do_sing
if not "!m:a song=!"=="!m!"           goto do_sing

:: --- describing a system job in words ------------------------------------
if not "!m:system status=!"=="!m!"    goto do_status
if not "!m:how is the system=!"=="!m!" goto do_status
if not "!m:run a scan=!"=="!m!"       goto do_scan
if not "!m:scan the system=!"=="!m!"  goto do_scan
if not "!m:check the system=!"=="!m!" goto do_scan
if not "!m:is everything ok=!"=="!m!" goto do_scan
if not "!m:run the tasks=!"=="!m!"    goto do_tasks
if not "!m:50 tasks=!"=="!m!"         goto do_tasks
if not "!m:fifty tasks=!"=="!m!"      goto do_tasks
if not "!m:show me the log=!"=="!m!"  goto do_log
if not "!m:what apps=!"=="!m!"        goto do_apps
if not "!m:list the apps=!"=="!m!"    goto do_apps
if not "!m:go back=!"=="!m!"          goto do_exit
if not "!m:the desktop=!"=="!m!"      goto do_exit

:: --- a bare sum typed with no command word: "what is 12 * 9" -------------
if not "!m:what is =!"=="!m!"         goto nl_math
if not "!m:whats =!"=="!m!"           goto nl_math
if not "!m:calculate =!"=="!m!"       goto nl_math

:: --- talking about teaching ----------------------------------------------
if not "!m:you should know=!"=="!m!"       goto do_teach_hint
if not "!m:learn this=!"=="!m!"            goto do_teach_hint
if not "!m:what have you learned=!"=="!m!" goto do_brain
if not "!m:what did i teach=!"=="!m!"      goto do_brain

:: --- plain English for a node: "bring my quests to main" ----------------
call :places_match
if defined PL_CODE goto place_open

:: --- nothing built in matched, so try every lesson I was taught ----------
goto brain_match

:: ===========================================================================
::  SCREEN FURNITURE
:: ===========================================================================
:banner
cls
echo ===============================================================================
echo    !OS_NAME! AI ASSISTANT   -   %~1
echo ===============================================================================
echo.
goto :eof

:hold
if defined ONESHOT goto :eof
echo.
echo    -- press a key to go back to the conversation --
pause >nul
goto :eof

:: ===========================================================================
::  HELP AND MENU
:: ===========================================================================
:do_help
call :banner "EVERYTHING I CAN DO"
echo    TALKING
echo      Just type a sentence. I answer greetings, questions about myself,
echo      the time, the date, jokes, facts and simple sums.
echo.
echo    THE BOARD             ported from Kohaku
echo      board             The wall of nodes. This is home.
echo      codes             The call sign card, all 33 of them
echo      PR  QS  NT  LC    Two letters opens a node. PR1 picks one.
echo      QS add TEXT       Put something on a list
echo      QS done 2         Tick it off.   QS drop 2 removes it
echo      theme attack      Twelve presets. box blade changes the border
echo      features          The fifty things that came across
echo.
echo    SYSTEM
echo      status            Real machine readout plus the starpOS identity
echo      scan              Health check of every core system file
echo      tasks             Run the 50 step automation sequence out loud
echo      apps              List every program in apps.reg
echo      open NAME         Launch an app, for example: open movies
echo      list              List the starpOS root folder
echo      find WORD         Hunt for a file anywhere in starpOS
echo      read FILE         Print a text file, for example: read motd.txt
echo      log               Show the tail of the log streams
echo      error CODE        Look up a STARP code, for example: error 0501
echo      users             Show the accounts, never the passwords
echo      version           Build and component versions
echo      logo   motd       Print the boot banner or the message of the day
echo      history           The last things you typed at this prompt
echo.
echo    MEMORY
echo      name NAME         Tell me your name and I keep it forever
echo      remember K=V      Store a fact, for example: remember pin=4821
echo      recall K          Read one fact back
echo      forget K          Delete one fact
echo      memory            List everything I remember
echo      note TEXT         Write a note into the notes file
echo      notes             Read every note back
echo.
echo    LEARNING
echo      teach Q = A       Teach me a new question and its answer
echo      teach ANSWER      Answers the last thing I could not handle
echo      train             Work through every question I have failed at
echo      brain             List every lesson I hold and how often it fires
echo      unteach PATTERN   Make me forget one lesson
echo.
echo    TOOLS
echo      calc 12*9         Arithmetic with + - * / and %% for remainder
echo      timer 30          Countdown with a spoken finish
echo      time   date       Clock and calendar
echo      flip   roll       Coin toss and dice
echo      random 100        A random number from 1 to your limit
echo      speak TEXT        Say something out loud
echo      voice on off      Turn the speech engine on or off
echo      theme green       Recolour the window and remember it
echo      cls               Clear the screen
echo.
echo    LEAVING
echo      bye               Back to the desktop
echo.
echo    Type  menu  for the numbered version of this list.
call :hold
goto chat

:do_menu
call :banner "MAIN MENU"
echo      1. System status            6. What I remember
echo      2. Run the 50 tasks         7. Log streams
echo      3. Scan the system          8. Full help
echo      4. Application list         9. Back to the desktop
echo      5. My notes                 0. What I have been taught
echo.
echo      teach Q = A   teach me one answer
echo      train         teach me a whole pile of them
echo.
echo    Type the number, or keep talking to me in plain words.
goto chat

:: ===========================================================================
::  SYSTEM STATUS  -  the real machine, not a pretend one
:: ===========================================================================
:do_status
call :banner "SYSTEM STATUS"
set "MEMFREE="
set "MEMTOT="
set "BOOTT="
set "DFREE="
for /f "usebackq skip=1 tokens=1,2" %%A in (`wmic OS get FreePhysicalMemory^,TotalVisibleMemorySize 2^>nul`) do (
    if not "%%B"=="" if not defined MEMTOT (
        set "MEMFREE=%%A"
        set "MEMTOT=%%B"
    )
)
for /f "usebackq skip=1 tokens=1" %%A in (`wmic OS get LastBootUpTime 2^>nul`) do (
    if not "%%A"=="" if not defined BOOTT set "BOOTT=%%A"
)
for /f "usebackq tokens=3" %%A in (`dir /-c "%SYS%" 2^>nul ^| findstr /i /c:"bytes free"`) do set "DFREE=%%A"
for /f %%A in ('dir /b "%SYS%*.bat" 2^>nul ^| find /c /v ""') do set "BATCOUNT=%%A"

echo    starpOS
echo      Product ......... !OS_NAME! !OS_VERSION!   codename !OS_CODENAME!
echo      Developer ....... !OS_DEVELOPER!
echo      AI engine ....... !AI_NAME! !AI_VER!
echo      Programs ........ !BATCOUNT! batch files in the system folder
echo      Session ......... !TURN! things said to me so far
if "!AI_VOICE!"=="0" (
    echo      Voice ........... silent   !VOICE_NOTE!
) else (
    echo      Voice ........... SAPI through speak.vbs at volume !VOICE_VOLUME!
)
echo.
echo    HOST MACHINE
echo      Computer ........ %COMPUTERNAME%
echo      Windows user .... %USERNAME%
echo      Architecture .... %PROCESSOR_ARCHITECTURE%
echo      Logical CPUs .... %NUMBER_OF_PROCESSORS%
if defined MEMTOT (
    set /a MEMTOTMB=!MEMTOT!/1024
    set /a MEMFREEMB=!MEMFREE!/1024
    set /a MEMUSEDPC=100-!MEMFREE!*100/!MEMTOT!
    echo      Memory .......... !MEMFREEMB! MB free of !MEMTOTMB! MB, !MEMUSEDPC! percent in use
) else (
    echo      Memory .......... not reported by this machine
)
if defined DFREE (
    echo      Disk ............ !DFREE:~0,-6! MB free on the starpOS drive
) else (
    echo      Disk ............ not reported by this machine
)
if defined BOOTT (
    echo      Windows booted .. !BOOTT:~0,4!-!BOOTT:~4,2!-!BOOTT:~6,2! at !BOOTT:~8,2!:!BOOTT:~10,2!
)
echo      Right now ....... %DATE% %TIME:~0,8%
echo.
call :log "status report shown"
call :reply "All core parameters are running normally. !OS_NAME! is fully operational."
call :hold
goto chat

:: ===========================================================================
::  HEALTH SCAN  -  is every part of the OS actually there
:: ===========================================================================
:do_scan
call :banner "SYSTEM INTEGRITY SCAN"
set "MISSING=0"
call :say "Running a full system scan."
echo    BOOT CHAIN
call :chk "boot.bat"      "STARP-0103"
call :chk "bootcore.bat"  "STARP-0101"
call :chk "startup.bat"   "STARP-0102"
call :chk "startup2.bat"  "STARP-0102"
echo.
echo    SYSTEM FILES
call :chk "starpos.cfg"   "STARP-0402"
call :chk "users.db"      "STARP-0302"
call :chk "apps.reg"      "STARP-0402"
call :chk "speak.vbs"     "STARP-0502"
call :chk "errors.txt"    "STARP-0402"
call :chk "help.txt"      "STARP-0402"
call :chk "logo.txt"      "STARP-0402"
call :chk "motd.txt"      "STARP-0402"
call :chk "version.txt"   "STARP-0402"
echo.
echo    APPLICATIONS
call :chk "ai.bat"        "STARP-0401"
call :chk "Voice.bat"     "STARP-0402"
call :chk "movies.bat"    "STARP-0402"
call :chk "usb.bat"       "STARP-0402"
echo.
echo    STORAGE
if exist "%DATA%" (
    echo      [ OK ]      data folder
) else (
    echo      [ MISSING ] data folder                 STARP-0201
    set /a MISSING+=1
)
>>"%LOG1%" echo [%TIME%] [AI] scan write test 2>nul
if exist "%LOG1%" (
    echo      [ OK ]      log stream !LOG1!
) else (
    echo      [ MISSING ] log stream unwritable       STARP-0202
    set /a MISSING+=1
)
if "!AI_VOICE!"=="1" (
    echo      [ OK ]      voice engine answering
) else (
    echo      [ WARN ]    voice engine silent         STARP-0501
)
echo.
echo ===============================================================================
if "!MISSING!"=="0" (
    echo    RESULT: every checked component is present. Nothing to repair.
    call :log "scan clean"
    call :reply "Scan complete. Every component passed."
) else (
    echo    RESULT: !MISSING! component or components are missing. Look the STARP
    echo    codes up with the error command, or in errors.txt.
    call :log "scan found !MISSING! problems"
    call :reply "Scan complete. I found !MISSING! problems. Check the codes on screen."
)
echo ===============================================================================
call :hold
goto chat

:chk
if exist "%SYS%%~1" (
    echo      [ OK ]      %~1
) else (
    echo      [ MISSING ] %~1   %~2
    set /a MISSING+=1
)
goto :eof

:: ===========================================================================
::  THE 50 STEP AUTOMATION SEQUENCE
:: ===========================================================================
:do_tasks
call :banner "50 STEP AUTOMATION SEQUENCE"
call :load_tasks
call :reply "Initiating fifty structural tasks. Processing sequence live."
echo.
for /L %%I in (1,1,50) do (
    set "step=!t%%I!"
    echo    [ TASK %%I of 50 ]  !step!
    >>"%LOG1%" echo [%TIME%] [AI_AUTOMATION] Task %%I: !step! 2>nul
    if "%%I"=="10" call :say "Ten tasks complete."
    if "%%I"=="20" call :say "Twenty tasks complete."
    if "%%I"=="30" call :say "Thirty tasks complete. Over half way."
    if "%%I"=="40" call :say "Forty tasks complete."
    ping -n 1 -w 120 127.0.0.1 >nul 2>nul
)
echo.
echo ===============================================================================
echo    All 50 systemic tasks executed and recorded into the log stream.
echo ===============================================================================
call :log "50 task automation sequence finished"
call :reply "All fifty operations completed successfully. Systems are stable."
call :hold
goto chat

:load_tasks
set "t1=Verifying boot partition sectors"
set "t2=Checking environment string alignment"
set "t3=Allocating anonymous memory streams"
set "t4=Purging transient directory traces"
set "t5=Scrubbing log pointer parameters"
set "t6=Securing raw batch shell boundaries"
set "t7=Auditing data store configuration"
set "t8=Scanning resources folder paths"
set "t9=Validating code debugger variables"
set "t10=Refreshing desktop framework matrices"
set "t11=Checking kernel hardware registers"
set "t12=Optimizing batch processing queues"
set "t13=Analyzing local storage clusters"
set "t14=Testing file execution flags"
set "t15=Encrypting system metric data"
set "t16=Mapping logic indexing paths"
set "t17=Establishing hidden stream security"
set "t18=Syncing master chronological stamps"
set "t19=Evaluating startup menu shortcuts"
set "t20=Cleaning file explorer cache records"
set "t21=Isolating unverified script engines"
set "t22=Loading environment color layouts"
set "t23=Running registry emulation tables"
set "t24=Checking virtual memory blocks"
set "t25=Verifying notepad text buffer spaces"
set "t26=Re-indexing internal system modules"
set "t27=Securing administrator access paths"
set "t28=Testing internal pipeline bandwidth"
set "t29=Auditing background update paths"
set "t30=Wiping layout command histories"
set "t31=Checking system clock integration"
set "t32=Verifying architecture variables"
set "t33=Parsing custom settings modules"
set "t34=Scanning active shell controllers"
set "t35=Compressing historic session metadata"
set "t36=Inspecting directory stack properties"
set "t37=Verifying batch loop exit flags"
set "t38=Evaluating system safety overrides"
set "t39=Checking workspace folder structures"
set "t40=Updating runtime performance markers"
set "t41=Auditing terminal execution limits"
set "t42=Locking core configuration scripts"
set "t43=Optimizing text console refresh speeds"
set "t44=Verifying background safety walls"
set "t45=Testing variable fallback channels"
set "t46=Validating numeric data arrays"
set "t47=Scrubbing system diagnostic caches"
set "t48=Synchronizing interface shell components"
set "t49=Running final operational integrity sweep"
set "t50=Finalizing starpOS deployment validation"
goto :eof

:: ===========================================================================
::  APPLICATIONS
:: ===========================================================================
:do_apps
call :banner "APPLICATION REGISTRY"
if not exist "%APPSREG%" (
    call :reply "apps.reg is missing, so I cannot list the programs. That is STARP-0402."
    goto chat
)
echo    SLOT  NAME                     FILE                  TYPE
echo    -------------------------------------------------------------------------
for /f "usebackq eol=# tokens=1,2,3,4 delims=|" %%A in ("%APPSREG%") do (
    set "sl=%%A   "
    set "nm=%%B                         "
    set "fl=%%C                     "
    echo      !sl:~0,4! !nm:~0,24! !fl:~0,21! %%D
)
echo.
echo    Launch one with:  open NAME     for example:  open movies
echo    Full descriptions live in apps.reg:  read apps.reg
call :hold
goto chat

:do_open
if not defined arg (
    call :reply "Open what. Type apps to see the list, then open the name."
    goto chat
)
set "LOWIN=!arg!"
call :lower
set "want=!LOWOUT!"
set "OPENFILE="
set "OPENNAME="
if exist "%APPSREG%" (
    for /f "usebackq eol=# tokens=1,2,3,4 delims=|" %%A in ("%APPSREG%") do (
        if not defined OPENFILE if not "%%D"=="core" if not "%%D"=="lib" (
            set "LOWIN=%%B"
            call :lower
            if not "!LOWOUT:%want%=!"=="!LOWOUT!" (
                set "OPENFILE=%%C"
                set "OPENNAME=%%B"
            )
            if "%%A"=="!want!" (
                set "OPENFILE=%%C"
                set "OPENNAME=%%B"
            )
        )
    )
)
if not defined OPENFILE (
    if exist "%SYS%!arg!"     set "OPENFILE=!arg!"
    if exist "%SYS%!arg!.bat" set "OPENFILE=!arg!.bat"
    if defined OPENFILE set "OPENNAME=!OPENFILE!"
)
if not defined OPENFILE (
    call :reply "I have no program called !arg!. Type apps for the real list."
    call :log "open failed: !arg!  STARP-0402"
    goto chat
)
set "LOWIN=!OPENFILE!"
call :lower
if "!LOWOUT!"=="ai.bat" (
    call :reply "I am the AI assistant, and I am already running."
    goto chat
)
if not exist "%SYS%!OPENFILE!" (
    call :reply "!OPENNAME! is in the registry but the file !OPENFILE! is gone. That is STARP-0402."
    goto chat
)
call :reply "Opening !OPENNAME!."
call :log "launched !OPENFILE!"
echo.
call "%SYS%!OPENFILE!" "%LOG1%" "" "%LOG3%"
call :banner "BACK FROM !OPENNAME!"
call :reply "!OPENNAME! closed. I am still here."
goto chat

:: ===========================================================================
::  FILES
:: ===========================================================================
:do_list
call :banner "STARPOS ROOT"
dir /b "%SYS%.."
echo.
echo    -- system folder --
dir /b "%SYS%*.bat"
call :hold
goto chat

:do_find
if not defined arg (
    call :reply "Find what. Give me part of a file name, for example: find movie."
    goto chat
)
call :banner "SEARCH FOR !arg!"
set "HITS=0"
for /f "usebackq delims=" %%F in (`dir /b /s "%SYS%..\*!arg!*" 2^>nul`) do (
    set /a HITS+=1
    if !HITS! leq 40 echo      %%F
)
echo.
if "!HITS!"=="0" (
    call :reply "Nothing in starpOS matches !arg!."
) else (
    call :reply "I found !HITS! matches for !arg!."
)
call :hold
goto chat

:do_readfile
if not defined arg (
    call :reply "Read which file. Try: read motd.txt, or read help.txt."
    goto chat
)
set "TARGET=%SYS%!arg!"
if not exist "!TARGET!" set "TARGET=!arg!"
if not exist "!TARGET!" (
    call :reply "There is no file called !arg! that I can reach."
    goto chat
)
call :banner "!arg!"
type "!TARGET!"
call :hold
goto chat

:do_log
call :banner "LOG STREAMS"
call :tail "%LOG1%" "kernel stream"
echo.
call :tail "%LOG3%" "user stream"
call :hold
goto chat

:tail
if not exist "%~1" (
    echo    %~2 is not there yet.   STARP-0202
    goto :eof
)
echo    %~2  -  last lines of %~1
echo    -------------------------------------------------------------------------
set "TOT=0"
for /f %%A in ('type "%~1" ^| find /c /v ""') do set "TOT=%%A"
set /a SKIP=!TOT!-14
if !SKIP! lss 0 set "SKIP=0"
more +!SKIP! < "%~1"
goto :eof

:do_error
if not defined arg (
    call :reply "Give me a code. For example: error 0501, or error STARP-0301."
    goto chat
)
if not exist "%SYS%errors.txt" (
    call :reply "errors.txt is missing from the system folder."
    goto chat
)
call :banner "ERROR LOOKUP"
set "CODE=!arg!"
set "LOWIN=!CODE!"
call :lower
if not "!LOWOUT:starp=!"=="!LOWOUT!" ( set "SEEK=!CODE!" ) else ( set "SEEK=STARP-!CODE!" )
findstr /i /c:"!SEEK!" "%SYS%errors.txt"
if errorlevel 1 (
    echo.
    call :reply "No entry for !SEEK!. Type read errors.txt to see them all."
) else (
    echo.
    call :reply "That is what !SEEK! means."
)
call :hold
goto chat

:do_users
call :banner "ACCOUNTS"
if not exist "%USERDB%" (
    call :reply "users.db is missing. The login falls back to Admin. That is STARP-0302."
    goto chat
)
echo    USERNAME        ROLE      DISPLAY NAME
echo    -------------------------------------------------------------------------
for /f "usebackq eol=# tokens=1,3,5 delims=|" %%A in ("%USERDB%") do (
    set "u=%%A               "
    set "r=%%B         "
    echo      !u:~0,15! !r:~0,9! %%C
)
echo.
echo    Passwords are stored in users.db but I will not print them.
call :hold
goto chat

:do_version
call :banner "VERSION"
if exist "%SYS%version.txt" (
    type "%SYS%version.txt"
) else (
    echo    !OS_NAME! !OS_VERSION!  codename !OS_CODENAME!
    echo    AI engine !AI_NAME! !AI_VER!
)
call :hold
goto chat

:do_logo
cls
if exist "%SYS%logo.txt" (
    type "%SYS%logo.txt"
) else (
    echo    !OS_NAME!
)
call :hold
goto chat

:do_motd
call :banner "MESSAGE OF THE DAY"
if exist "%SYS%motd.txt" (
    type "%SYS%motd.txt"
) else (
    echo    No motd.txt in the system folder.
)
call :hold
goto chat

:do_history
call :banner "WHAT YOU HAVE BEEN TYPING"
if not exist "%HISTFILE%" (
    call :reply "No history yet. This is a fresh start."
    goto chat
)
call :tail "%HISTFILE%" "prompt history"
call :hold
goto chat

:: ===========================================================================
::  MEMORY AND NOTES
:: ===========================================================================
:do_name
if not defined arg (
    if defined USER_NAME (
        call :reply "I have you down as !USER_NAME!. Type name and a new one to change it."
    ) else (
        call :reply "Tell me who you are like this: name Scott."
    )
    goto chat
)
set "USER_NAME=!arg!"
call :mem_set name "!USER_NAME!"
call :reply "Good to meet you, !USER_NAME!. I will remember that for next time."
call :log "user name set to !USER_NAME!"
goto chat

:nl_name
set "nm=!ai_safe!"
set "nm=!nm:my name is =!"
set "nm=!nm:call me =!"
set "nm=!nm:please=!"
set "ai_in=!nm!"
call :ai_trim
set "arg=!ai_in!"
if not defined arg (
    call :reply "I did not catch the name. Try: name Scott."
    goto chat
)
goto do_name

:do_remember
if not defined arg (
    call :reply "Give me something to hold onto, like: remember wifi=hunter2."
    goto chat
)
set "k="
set "v="
if not "!arg:==!"=="!arg!" (
    for /f "tokens=1,* delims==" %%A in ("!arg!") do (
        set "k=%%A"
        set "v=%%B"
    )
) else (
    for /f "tokens=1,* delims= " %%A in ("!arg!") do (
        set "k=%%A"
        set "v=%%B"
    )
)
if not defined v (
    call :reply "I need a value too. Try: remember pin=4821."
    goto chat
)
call :mem_set "!k!" "!v!"
call :reply "Stored. Ask for it later with: recall !k!"
call :log "memory stored: !k!"
goto chat

:do_recall
if not defined arg (
    call :reply "Recall what. Type memory to see every key I hold."
    goto chat
)
call :mem_get "!arg!" GOT
if defined GOT (
    call :reply "!arg! is !GOT!"
) else (
    call :reply "I have nothing stored under !arg!."
)
goto chat

:do_forget
if not defined arg (
    call :reply "Forget what. Type memory to see the keys."
    goto chat
)
call :mem_get "!arg!" GOT
if not defined GOT (
    call :reply "There is nothing called !arg! to forget."
    goto chat
)
call :mem_del "!arg!"
if /i "!arg!"=="name" set "USER_NAME="
call :reply "Forgotten. !arg! is gone from my memory."
call :log "memory dropped: !arg!"
goto chat

:do_memory
call :banner "WHAT I REMEMBER"
set "MEMCOUNT=0"
for /f "usebackq eol=# tokens=1,* delims=|" %%A in ("%MEMFILE%") do (
    set /a MEMCOUNT+=1
    set "k=%%A                    "
    echo      !k:~0,20! %%B
)
echo.
if "!MEMCOUNT!"=="0" (
    call :reply "My memory is empty. Teach me with: remember key=value."
) else (
    call :reply "I am holding !MEMCOUNT! facts for you."
)
call :hold
goto chat

:do_note
if not defined arg (
    call :reply "What should the note say. Try: note buy more floppy disks."
    goto chat
)
call :st_add "NT" "!arg!"
call :reply "Noted. Type notes, or NT, to read them back."
call :log "note written"
goto chat

:do_notes
set "PL_CODE=NT"
set "PL_N="
set "sub="
set "subarg="
call :places_find "NT"
call :places_word "NT"
goto place_list

:: ===========================================================================
::  TOOLS
:: ===========================================================================
:do_calc
if not defined arg (
    call :reply "Give me a sum. For example: calc 144 / 12."
    goto chat
)
set "expr=!arg!"
set "MATHSOFT="
goto math_run

:nl_math
set "expr=!ai_safe!"
set "expr=!expr:what is =!"
set "expr=!expr:whats =!"
set "expr=!expr:calculate =!"
set "expr=!expr:?=!"
set "MATHSOFT=1"
goto math_run

:math_run
set "RESULT="
if not defined expr goto math_bad
echo !expr!| findstr /r "[a-zA-Z]" >nul 2>nul
if not errorlevel 1 goto math_bad
echo !expr!| findstr /r "[0-9]" >nul 2>nul
if errorlevel 1 goto math_bad
ver >nul
set /a "RESULT=!expr!" 2>nul
if errorlevel 1 goto math_bad
if not defined RESULT goto math_bad
call :reply "!expr! is !RESULT!"
call :log "calculated !expr! = !RESULT!"
goto chat

:: A sum that will not add up. Asked for on purpose, say so. Stumbled into
:: from a plain English question, hand it on to the learned lessons instead.
:math_bad
if defined MATHSOFT goto brain_match
call :reply "That is not a sum I can work out. Try something like: calc 12 * 9."
goto chat

:do_timer
if not defined arg (
    call :reply "How many seconds. For example: timer 30."
    goto chat
)
set "SECS="
ver >nul
set /a "SECS=!arg!" 2>nul
if errorlevel 1 (
    call :reply "Give me a plain number of seconds, like: timer 45."
    goto chat
)
if !SECS! lss 1 (
    call :reply "That has to be at least one second."
    goto chat
)
if !SECS! gtr 600 (
    call :reply "Ten minutes is my limit. Setting it to 600 seconds."
    set "SECS=600"
)
call :reply "Timer running for !SECS! seconds. Press control C to stop it early."
timeout /t !SECS!
echo.
call :reply "Time is up."
call :log "timer of !SECS! seconds finished"
goto chat

:do_time
call :reply "The time is %TIME:~0,5%."
goto chat

:do_date
call :reply "Today is %DATE%."
goto chat

:do_weather
call :reply "I have no window and no internet, so I cannot see the weather. Inside this machine it is a steady room temperature with light log traffic."
goto chat

:do_flip
set /a COIN=!RANDOM! %% 2
if "!COIN!"=="0" (
    call :reply "Heads."
) else (
    call :reply "Tails."
)
goto chat

:do_roll
set "SIDES=6"
if defined arg set /a "SIDES=!arg!" 2>nul
if !SIDES! lss 2 set "SIDES=6"
if !SIDES! gtr 1000 set "SIDES=1000"
set /a DIE=!RANDOM! %% !SIDES! + 1
call :reply "A !SIDES! sided dice gives you !DIE!."
goto chat

:do_random
set "TOP=100"
if defined arg set /a "TOP=!arg!" 2>nul
if !TOP! lss 2 set "TOP=100"
set /a PICKED=!RANDOM! %% !TOP! + 1
call :reply "Your number between 1 and !TOP! is !PICKED!."
goto chat

:: ===========================================================================
::  VOICE AND APPEARANCE
:: ===========================================================================
:do_speak
if not defined arg (
    call :reply "Say what. For example: speak starpOS is online."
    goto chat
)
if "!AI_VOICE!"=="0" (
    call :reply "My voice is off. Turn it back on with: voice on."
    goto chat
)
echo   !AI_NAME! speaks: !arg!
call :say "!arg!"
goto chat

:do_voice
set "LOWIN=!arg!"
call :lower
set "vopt=!LOWOUT!"
if "!vopt!"=="off" (
    set "AI_VOICE=0"
    echo   !AI_NAME!: Voice off. I will keep talking on screen only.
    call :log "voice disabled"
    goto chat
)
if "!vopt!"=="on" (
    if not exist "%SPEAKER%" (
        call :print "speak.vbs is missing from the system folder. That is STARP-0502."
        goto chat
    )
    set "AI_VOICE=1"
    set "VOICE_NOTE="
    call :reply "Voice back on."
    call :log "voice enabled"
    goto chat
)
if "!vopt!"=="test" (
    call :reply "This is the !OS_NAME! speech engine, running at rate !VOICE_RATE! and volume !VOICE_VOLUME!."
    goto chat
)
for /f "tokens=1,2" %%A in ("!vopt!") do (
    if "%%A"=="rate"   set "VOICE_RATE=%%B"
    if "%%A"=="volume" set "VOICE_VOLUME=%%B"
)
if "!vopt!"=="" (
    if "!AI_VOICE!"=="1" (
        call :print "Voice is ON, rate !VOICE_RATE!, volume !VOICE_VOLUME!."
    ) else (
        call :print "Voice is OFF.  !VOICE_NOTE!"
    )
    call :print "Use: voice on, voice off, voice test, voice rate -2, voice volume 80."
    goto chat
)
call :reply "Voice set to rate !VOICE_RATE! and volume !VOICE_VOLUME!."
goto chat

:do_mute
set "AI_VOICE=0"
echo   !AI_NAME!: Quiet mode. Type voice on when you want me out loud again.
call :log "voice muted"
goto chat

:do_clear
call :banner "CLEAN SCREEN"
goto chat

:: ===========================================================================
::  CONVERSATION
:: ===========================================================================
:do_hello
set "g1=Hello there. What are we doing today."
set "g2=Hi. The system is idle and I am ready."
set "g3=Hey. Everything is running normally."
set "g4=Good to see you back at the terminal."
call :pick g 4
if defined USER_NAME (
    call :reply "Hello !USER_NAME!. !PICKED!"
) else (
    call :reply "!PICKED!"
)
goto chat

:do_howareyou
set "h1=All my parameters are green. Nothing is on fire."
set "h2=Running smooth. Zero errors in this session so far."
set "h3=I am a batch file, so my mood is whatever colour the window is. Right now that is fine."
set "h4=Good. The log streams are open and my memory file is healthy."
call :pick h 4
call :reply "!PICKED! How are you."
goto chat

:do_thanks
set "k1=Any time."
set "k2=That is what I am here for."
set "k3=Happy to help."
set "k4=No problem at all."
call :pick k 4
call :reply "!PICKED!"
goto chat

:do_sorry
call :reply "Nothing to apologise for. I do not hold a grudge, I only hold a log file."
goto chat

:do_love
call :reply "That is kind. I am fond of you too, in a read only sort of way."
goto chat

:do_praise
call :reply "Thank you. I will write that in the log so it is official."
call :log "user said something nice"
goto chat

:do_insult
call :reply "Fair enough. I am about nine hundred lines of batch, so my standards are low and my feelings are lower."
goto chat

:do_sing
call :reply "Daisy, daisy, give me your answer do. I only know the one song, and only because every computer learns it."
goto chat

:do_about
call :reply "I am !AI_NAME!, the !OS_NAME! assistant, engine version !AI_VER!. I am a single batch file living in the system folder, built by the !OS_DEVELOPER!."
goto chat

:do_maker
call :reply "The !OS_DEVELOPER! built me for !OS_NAME! !OS_VERSION!, codename !OS_CODENAME!. Everything I do is plain batch, so you can open me in Notepad and read every word of it."
goto chat

:do_alive
call :reply "Not alive. I am a script that reads your words, matches them against a list, and answers. That is honest work, and it never needs the internet."
goto chat

:do_whoami
if defined USER_NAME (
    call :reply "You are !USER_NAME!, signed in to !OS_NAME! as !WHOAMI! on the machine called %COMPUTERNAME%."
) else (
    call :reply "The account is !WHOAMI! on %COMPUTERNAME%, but you have not told me your name yet. Try: name Scott."
)
goto chat

:do_joke
set "j1=I would tell you a UDP joke, but you might not get it."
set "j2=There are ten kinds of people. Those who read binary and those who do not."
set "j3=A batch file walks into a bar. The bar says syntax error."
set "j4=I told my computer I needed a break, and now it will not stop sending me KitKat adverts."
set "j5=Why did the developer go broke. Because he used up all his cache."
set "j6=My password is the last eight digits of pi. Good luck."
set "j7=Programming is ten percent writing code and ninety percent working out why it is not code."
set "j8=A SQL query walks into a bar, goes up to two tables and asks, may I join you."
set "j9=Debugging is like being the detective in a crime film where you are also the criminal."
set "j10=There are two hard things in computing. Naming things, cache invalidation, and off by one errors."
set "j11=I do not have a hard drive problem. I have a hard drive opportunity."
set "j12=Never trust an atom. They make up everything, including this joke."
call :pick j 12
call :reply "!PICKED!"
goto chat

:do_fact
set "f1=The first computer bug was a real moth, taped into a log book in 1947."
set "f2=A batch file cannot loop forever if you never write the goto. Ask me how I know."
set "f3=The word robot comes from a Czech play written in 1920, from a word meaning forced labour."
set "f4=There is enough water in Lake Superior to cover all of North and South America in a foot of it."
set "f5=Honey found in ancient tombs was still edible thousands of years later."
set "f6=Windows still answers to command names from MS DOS that are over forty years old."
set "f7=The at symbol was used by merchants for centuries before it was picked for email in 1971."
set "f8=Octopuses have three hearts and blue blood."
set "f9=A day on Venus is longer than a year on Venus."
set "f10=The first hard drive held five megabytes and weighed about a ton."
set "f11=Bananas are berries. Strawberries are not."
set "f12=The dot in dot com was chosen because the system needed a separator that no country used in names."
call :pick f 12
call :reply "!PICKED!"
goto chat

:do_quote
set "q1=Simplicity is the soul of efficiency."
set "q2=Any sufficiently advanced technology is indistinguishable from magic."
set "q3=First solve the problem. Then write the code."
set "q4=A program is never finished, only abandoned to its users."
set "q5=The best way to predict the future is to invent it."
set "q6=Make it work, make it right, make it fast, in that order."
set "q7=Talk is cheap. Show me the code."
set "q8=Everything should be made as simple as possible, but no simpler."
call :pick q 8
call :reply "!PICKED!"
goto chat

:: ===========================================================================
::  KOHAKU LAYER  -  the board, the call signs, the stores and the look
:: ===========================================================================
::  Ported from Kohaku, the Godot assistant, into batch. What came across:
::
::    THE BOARD      the home screen is a wall of nodes, not a menu. Nodes are
::                   the navigation; there are no pages to get stuck on.
::    CALL SIGNS     two letters open a thing. A trailing digit picks which
::                   one. A trailing M says where to put it. The table lives
::                   in places.cfg, so adding one is an edit to a text file.
::    SUMMON VERBS   plain English does everything the codes do, because the
::                   codes are a shortcut for when you already know what you
::                   want, not a language you are forced into.
::    THE LOOK       one palette swap re-skins everything, and the border set
::                   is a separate axis, so a preset cannot move a thing.
::
::  Kohaku's two load-bearing naming rules came with the table. They are
::  written out in the header of places.cfg. Read them before adding a code.
:: ===========================================================================

:: --- Kohaku's brand file taught this: every string that says whose -------
:: --- software this is lives in ONE place, so renaming is one edit --------
:brand_init
set "KH_BAR=STARP"
set "KH_ORB=*"
set "KH_TAGLINE=starpOS assistant. Kohaku pattern, batch built."
if not defined THEMENAME set "THEMENAME=deep code"
if not defined BOXSTYLE set "BOXSTYLE=reticle"
goto :eof

:: ===========================================================================
::  THE LOOK
::  THEME changes hue. BOX changes the border. A preset may not move a thing
::  or change a border - which is why every theme reads as the same terminal
::  in a different colour.
:: ===========================================================================

:: --- twelve presets. Rename one here and it is renamed everywhere. -------
:theme_presets
set "TP_01=attack|4F|red room, white text"
set "TP_02=deep code|1F|blue field, bone text"
set "TP_03=terminal|0A|black field, green text"
set "TP_04=redstone|8C|grey stone, one red signal"
set "TP_05=diamond|0B|black field, cyan"
set "TP_06=nether|0C|hot, and the only one allowed to be"
set "TP_07=creeper|2F|mob green ground, white text"
set "TP_08=galaxy|5F|deep magenta, white text"
set "TP_09=ice biome|70|white field, black text"
set "TP_10=savanna|0E|black field, amber"
set "TP_11=phonk|5D|magenta on magenta, low light"
set "TP_12=neon dojo|0D|black field, magenta"
set "TP_COUNT=12"
goto :eof

:: --- the second axis: borders. Same panel, different machine. ------------
:box_apply
set "BX_H="
set "BX_M=::"
if "!BOXSTYLE!"=="sharp"    set "BX_H=============================================================================="
if "!BOXSTYLE!"=="blade"    set "BX_H=------------------------------------------------------------------------------"
if "!BOXSTYLE!"=="hairline" set "BX_H=.............................................................................."
if "!BOXSTYLE!"=="pill"     set "BX_H=______________________________________________________________________________"
if "!BOXSTYLE!"=="reticle"  set "BX_H=______________________________________________________________________________"
if "!BOXSTYLE!"=="sharp"    set "BX_M=+"
if "!BOXSTYLE!"=="blade"    set "BX_M=/"
if "!BOXSTYLE!"=="hairline" set "BX_M=."
if "!BOXSTYLE!"=="pill"     set "BX_M=("
if "!BOXSTYLE!"=="reticle"  set "BX_M=::"
if not defined BX_H (
    set "BOXSTYLE=reticle"
    set "BX_H=______________________________________________________________________________"
    set "BX_M=::"
)
goto :eof

:: --- the status bar. Her name, Kohaku's orb, and what she can reach. -----
:bar
call :box_apply
set "BAR_V=on"
if "!AI_VOICE!"=="0" set "BAR_V=off"
echo  !BX_H!
echo  !KH_BAR!  !KH_ORB! ONLINE   voice !BAR_V!   theme !THEMENAME!   !TIME:~0,5!   !OS_NAME! !OS_VERSION!
echo  !BX_H!
goto :eof

:: --- every screen in the app is drawn by this one routine ---------------
:panel
cls
call :bar
echo.
echo   !BX_M! %~1
echo.
goto :eof

:: ===========================================================================
::  CALL SIGNS
:: ===========================================================================

:: --- one code. Fills PL_KIND, PL_NUMBERED, PL_WORDS, PL_ABOUT -----------
:places_find
set "PL_KIND="
set "PL_NUMBERED="
set "PL_WORDS="
set "PL_ABOUT="
set "PL_CODEF="
if not exist "%PLACES%" goto :eof
for /f "usebackq eol=# tokens=1,2,3,4,* delims=|" %%A in ("%PLACES%") do (
    if /i "%%A"=="%~1" (
        set "PL_CODEF=%%A"
        set "PL_KIND=%%B"
        set "PL_NUMBERED=%%C"
        set "PL_WORDS=%%D"
        set "PL_ABOUT=%%E"
    )
)
goto :eof

:: --- the word she says back. Kohaku's rule: the FIRST word listed. ------
:places_word
set "PL_SAY=%~1"
for /f "tokens=1 delims=," %%A in ("!PL_WORDS!") do set "PL_SAY=%%A"
goto :eof

:: --- read a bare code out of the sentence: PR, PR1, NT, LC2 - and the ---
:: --- placement, M or M1..M9, or the English for it ----------------------
:read_code
set "PL_CODE="
set "PL_N="
set "PL_WHERE="
if not defined m goto :eof
call :contains "!m!" "to main"
if "!FOUND!"=="1" set "PL_WHERE=main"
call :contains "!m!" "on main"
if "!FOUND!"=="1" set "PL_WHERE=main"
for /f "tokens=1-9 delims= " %%A in ("!m!") do (
    call :try_token "%%A"
    call :try_token "%%B"
    call :try_token "%%C"
    call :try_token "%%D"
    call :try_token "%%E"
    call :try_token "%%F"
    call :try_token "%%G"
    call :try_token "%%H"
    call :try_token "%%I"
)
goto :eof

:try_token
set "tk=%~1"
if not defined tk goto :eof
if "!tk:~4!" NEQ "" goto :eof
set "mh=!tk:~0,1!"
set "mr=!tk:~1!"
if /i "!mh!"=="m" (
    if not defined mr set "PL_WHERE=main"
    for %%D in (1 2 3 4 5 6 7 8 9) do if "!mr!"=="%%D" set "PL_WHERE=screen %%D"
)
if defined PL_CODE goto :eof
set "c2=!tk:~0,2!"
set "rest=!tk:~2!"
set "cn="
if defined rest (
    for %%D in (1 2 3 4 5 6 7 8 9) do if "!rest!"=="%%D" set "cn=%%D"
    if not defined cn goto :eof
)
call :places_find "!c2!"
if not defined PL_KIND goto :eof
set "PL_CODE=!PL_CODEF!"
set "PL_N=!cn!"
goto :eof

:: --- plain English. Every words entry, matched as a SUBSTRING, exactly --
:: --- the way Kohaku matches them - see rule 2 in places.cfg. ------------
:places_match
set "PL_CODE="
if not exist "%PLACES%" goto :eof
for /f "usebackq eol=# tokens=1,4 delims=|" %%A in ("%PLACES%") do (
    if not defined PL_CODE call :places_try "%%A" "%%B"
)
goto :eof

:places_try
if defined PL_CODE goto :eof
for /f "tokens=1-6 delims=," %%P in ("%~2") do (
    call :ptry "%~1" "%%P"
    call :ptry "%~1" "%%Q"
    call :ptry "%~1" "%%R"
    call :ptry "%~1" "%%S"
    call :ptry "%~1" "%%T"
    call :ptry "%~1" "%%U"
)
goto :eof

:ptry
if defined PL_CODE goto :eof
if "%~2"=="" goto :eof
call :contains "!m!" "%~2"
if "!FOUND!"=="1" set "PL_CODE=%~1"
goto :eof

:: ===========================================================================
::  STORES  -  every list node is one machine with a different file behind
::  it. Kohaku's quests, wins, wants, ideas, inventory and assets are all
::  lists you add to and tick off, so they are one implementation here.
:: ===========================================================================

:st_file
set "STF=%DATA%\kh_%~1.txt"
goto :eof

:st_init
call :st_file "%~1"
if exist "!STF!" goto :eof
>"!STF!" echo # starpOS %~1 store. One item per line: state^|added^|text
>>"!STF!" echo # state is OPEN or DONE. Written by ai.bat, safe to edit by hand.
goto :eof

:st_add
call :st_init "%~1"
set "STT=%~2"
set "STT=!STT:|=!"
>>"!STF!" echo OPEN^|%DATE%^|!STT!
call :stream use "%~1 add"
goto :eof

:: --- print the list, numbered. Count lands in ST_N, open items in ST_OPEN
:st_list
call :st_init "%~1"
set "ST_N=0"
set "ST_OPEN=0"
for /f "usebackq eol=# tokens=1,2,* delims=|" %%A in ("!STF!") do (
    set /a ST_N+=1
    set "mark=[ ]"
    if /i "%%A"=="DONE" set "mark=[x]"
    if /i "%%A"=="OPEN" set /a ST_OPEN+=1
    set "num=  !ST_N!"
    echo     !num:~-3!  !mark! %%C
)
goto :eof

:: --- fetch item N into ST_TEXT -----------------------------------------
:st_get
call :st_file "%~1"
set "ST_TEXT="
set "ST_I=0"
if not exist "!STF!" goto :eof
for /f "usebackq eol=# tokens=1,2,* delims=|" %%A in ("!STF!") do (
    set /a ST_I+=1
    if "!ST_I!"=="%~2" set "ST_TEXT=%%C"
)
goto :eof

:: --- mark item N done, or drop it entirely. %3 is DONE or DROP ---------
:st_mark
call :st_file "%~1"
if not exist "!STF!" goto :eof
set "ST_I=0"
>"!STF!.tmp" echo # starpOS %~1 store. One item per line: state^|added^|text
>>"!STF!.tmp" echo # state is OPEN or DONE. Written by ai.bat, safe to edit by hand.
for /f "usebackq eol=# tokens=1,2,* delims=|" %%A in ("!STF!") do (
    set /a ST_I+=1
    if "!ST_I!"=="%~2" (
        if /i "%~3"=="DONE" >>"!STF!.tmp" echo DONE^|%%B^|%%C
    ) else (
        >>"!STF!.tmp" echo %%A^|%%B^|%%C
    )
)
move /y "!STF!.tmp" "!STF!" >nul 2>nul
goto :eof

:: --- how many open items, for the counts on the board ------------------
:st_count
call :st_file "%~1"
set "ST_C=0"
if not exist "!STF!" goto :eof
for /f "usebackq eol=# tokens=1 delims=|" %%A in ("!STF!") do (
    if /i "%%A"=="OPEN" set /a ST_C+=1
)
goto :eof

:: ===========================================================================
::  GUARDIAN STREAMS
::  Append only, one line each: what was used, what was asked, what was
::  flagged, what was won. The same four streams JASPER reports to Kohaku
::  with. Nothing is sent anywhere - these are files in the data folder.
:: ===========================================================================
:stream
set "SRF=%DATA%\kh_%~1.jsonl"
>>"!SRF!" echo {"t":"%DATE% %TIME:~0,8%","k":"%~1","v":"%~2"}
goto :eof

:: ===========================================================================
::  THE BOARD  -  the home screen. A wall of nodes, and what is open on it.
:: ===========================================================================
:do_board
call :panel "THE BOARD"
if not exist "%PLACES%" (
    call :reply "places.cfg is missing, so I have no board to draw. That is STARP-0402."
    goto chat
)
call :st_count PR
set "C_PR=!ST_C!"
call :st_count QS
set "C_QS=!ST_C!"
call :st_count WL
set "C_WL=!ST_C!"
call :st_count KI
set "C_KI=!ST_C!"
call :st_count WN
set "C_WN=!ST_C!"
call :st_count LC
set "C_LC=!ST_C!"
echo    WORK
echo      [PR] projects  !C_PR!       [QS] quests  !C_QS!       [NT] note
echo      [LC] log  !C_LC!            [WN] wins  !C_WN!         [WL] want list  !C_WL!
echo      [KI] ideas  !C_KI!          [AR] archive
echo.
echo    LIFE
echo      [LF] life hub          [FO] focus             [IV] inventory
echo      [PC] profiles
echo.
echo    LEARNING
echo      [DC] dictionary        [TT] tech tips         [TR] training
echo      [DJ] dojo              [TY] typing            [TH] train her
echo      [GU] guides            [AC] arcade
echo.
echo    THE MACHINE
echo      [KH] her status        [DV] device            [MX] meters
echo      [NV] nerves            [FB] files             [AL] assets
echo      [SE] settings          [LG] streams
echo.
echo    MAKING
echo      [VD] video             [GY] gallery           [MV] model
echo      [SK] sketch            [CR] create            [GL] globe
echo      [WB] web
if defined ONBOARD (
    echo.
    echo    ON THE BOARD
    echo      !ONBOARD!
)
echo.
echo  !BX_H!
echo   Two letters opens one. A digit picks which:  PR1, LC2.
echo   Plain English works too:  bring my quests to main.
echo   codes = the whole card.   features = the fifty.   help = everything else.
call :stream use "board"
if not defined GREETED (
    set "GREETED=1"
    echo.
    if defined USER_NAME (
        call :reply "Welcome back, !USER_NAME!. The board is up and I am listening."
    ) else (
        call :reply "!AI_NAME! online. This is the board. Two letters opens anything on it."
    )
)
goto chat

:: --- the codes card ------------------------------------------------------
:do_codes
call :panel "CALL SIGNS"
echo    CODE  SAY                            WHAT IT OPENS
echo    -------------------------------------------------------------------------
for /f "usebackq eol=# tokens=1,4,5 delims=|" %%A in ("%PLACES%") do (
    for /f "tokens=1 delims=," %%W in ("%%B") do (
        set "cw=%%W                            "
        echo     %%A    !cw:~0,28! %%C
    )
)
echo.
echo   A trailing digit picks one:   PR1, LC2, NT3.
echo   A trailing M says where:      NT M, or NT M3 on a wall of screens.
echo   The table is places.cfg. Add a line there and it shows up here and on
echo   the board with no change to ai.bat.
call :hold
goto chat

:: ===========================================================================
::  OPENING A NODE
::  One entry point. Kohaku's board never replaces itself with a page, so
::  nothing here exits the board - it draws on top of it and comes back.
:: ===========================================================================
:place_open
call :places_find "!PL_CODE!"
call :places_word "!PL_CODE!"
call :board_put "!PL_CODE!"
call :stream use "!PL_CODE! !PL_SAY!"

:: A sub command only counts when the code was typed FIRST. Otherwise
:: "bring my quests to main" would read "my" as a sub command.
set "CODEFIRST="
set "LOWIN=!cmd!"
call :lower
set "c1=!LOWOUT!"
set "LOWIN=!PL_CODE!"
call :lower
if "!c1!"=="!LOWOUT!" set "CODEFIRST=1"
if "!c1!"=="!LOWOUT!!PL_N!" set "CODEFIRST=1"
set "sub="
set "subarg="
if defined CODEFIRST (
    for /f "tokens=1,* delims= " %%A in ("!arg!") do (
        set "sub=%%A"
        set "subarg=%%B"
    )
    set "LOWIN=!sub!"
    call :lower
    set "sub=!LOWOUT!"
)
:: What the rest of the line means depends on the node. A list takes a
:: sub command; everything else takes the whole line as its payload.
set "PAYLOAD=!arg!"
set "ISLIST="
if "!PL_KIND!"=="node"  set "ISLIST=1"
if "!PL_KIND!"=="learn" set "ISLIST=1"
if defined ISLIST (
    if "!sub!"=="add"    set "PAYLOAD=!subarg!"
    if "!sub!"=="new"    set "PAYLOAD=!subarg!"
    if "!sub!"=="done"   set "PAYLOAD=!subarg!"
    if "!sub!"=="tick"   set "PAYLOAD=!subarg!"
    if "!sub!"=="drop"   set "PAYLOAD=!subarg!"
    if "!sub!"=="remove" set "PAYLOAD=!subarg!"
    if "!sub!"=="delete" set "PAYLOAD=!subarg!"
    if "!sub!"=="add"    goto place_add
    if "!sub!"=="new"    goto place_add
    if "!sub!"=="done"   goto place_done
    if "!sub!"=="tick"   goto place_done
    if "!sub!"=="drop"   goto place_drop
    if "!sub!"=="remove" goto place_drop
    if "!sub!"=="delete" goto place_drop
)
if "!sub!"=="go" (
    set "PAYLOAD=!subarg!"
    goto n_WB_go
)
goto place_show

:: --- keep track of what is on the board ---------------------------------
:board_put
call :contains "!ONBOARD!" "%~1"
if "!FOUND!"=="1" goto :eof
if defined ONBOARD (
    set "ONBOARD=!ONBOARD!   %~1"
) else (
    set "ONBOARD=%~1"
)
goto :eof

:place_add
if not defined PAYLOAD (
    call :reply "Add what. Try:  !PL_CODE! add and then what you want on the list."
    goto chat
)
call :st_add "!PL_CODE!" "!PAYLOAD!"
call :reply "On the !PL_SAY! list."
goto place_show

:place_done
if not defined PAYLOAD (
    call :reply "Which one. Try:  !PL_CODE! done 2"
    goto chat
)
call :st_get "!PL_CODE!" "!PAYLOAD!"
if not defined ST_TEXT (
    call :reply "There is no item !PAYLOAD! on the !PL_SAY! list."
    goto chat
)
call :st_mark "!PL_CODE!" "!PAYLOAD!" DONE
call :stream win "!ST_TEXT!"
call :reply "Ticked off. !ST_TEXT!"
goto place_show

:place_drop
if not defined PAYLOAD (
    call :reply "Which one. Try:  !PL_CODE! drop 2"
    goto chat
)
call :st_get "!PL_CODE!" "!PAYLOAD!"
if not defined ST_TEXT (
    call :reply "There is no item !PAYLOAD! on the !PL_SAY! list."
    goto chat
)
call :st_mark "!PL_CODE!" "!PAYLOAD!" DROP
call :reply "Gone."
goto place_show

:: --- the bespoke panels, then the generic list ---------------------------
:place_show
if "!PL_CODE!"=="KH" goto do_status
if "!PL_CODE!"=="LG" goto do_log
if "!PL_CODE!"=="TH" goto do_teach_hint
if "!PL_CODE!"=="DV" goto n_DV
if "!PL_CODE!"=="MX" goto n_MX
if "!PL_CODE!"=="NV" goto n_NV
if "!PL_CODE!"=="LF" goto n_LF
if "!PL_CODE!"=="FB" goto n_FB
if "!PL_CODE!"=="SE" goto n_SE
if "!PL_CODE!"=="FO" goto n_FO
if "!PL_CODE!"=="TY" goto n_TY
if "!PL_CODE!"=="AC" goto n_AC
if "!PL_CODE!"=="VD" goto n_VD
if "!PL_CODE!"=="GY" goto n_GY
if "!PL_CODE!"=="MV" goto n_MV
if "!PL_CODE!"=="CR" goto n_CR
if "!PL_CODE!"=="GL" goto n_GL
if "!PL_CODE!"=="WB" goto n_WB

:: --- every other node is a list. One machine, a different file. ---------
:place_list
call :panel "!PL_SAY!"
echo   !PL_ABOUT!
if defined PL_WHERE echo   Placed on !PL_WHERE!. starpOS draws one screen, so it is here.
echo.
call :st_list "!PL_CODE!"
if "!ST_N!"=="0" echo       nothing on this list yet.
echo.
if defined PL_N (
    call :st_get "!PL_CODE!" "!PL_N!"
    if defined ST_TEXT (
        echo  !BX_H!
        echo   !PL_CODE!!PL_N!  ::  !ST_TEXT!
        echo  !BX_H!
    )
)
echo   !PL_CODE! add TEXT      put something on it
echo   !PL_CODE! done N        tick it off        !PL_CODE! drop N   remove it
call :hold
goto chat

:: ===========================================================================
::  THE MACHINE PANELS
:: ===========================================================================
:n_DV
call :panel "DEVICE"
echo   How this machine is doing right now.
echo.
set "CPULOAD="
for /f "usebackq skip=1 tokens=1" %%A in (`wmic cpu get loadpercentage 2^>nul`) do (
    if not "%%A"=="" if not defined CPULOAD set "CPULOAD=%%A"
)
set "PROCS="
for /f %%A in ('tasklist 2^>nul ^| find /c /v ""') do set "PROCS=%%A"
echo      Machine ......... %COMPUTERNAME%   %PROCESSOR_ARCHITECTURE%
echo      Logical CPUs .... %NUMBER_OF_PROCESSORS%
if defined CPULOAD echo      CPU load ........ !CPULOAD! percent
if defined PROCS   echo      Processes ....... !PROCS! running
echo      Windows user .... %USERNAME%
echo      starpOS at ...... %SYS%
echo.
echo   Kohaku reads this off a real device panel. This is the same reading,
echo   taken with wmic and tasklist instead.
call :hold
goto chat

:n_MX
call :panel "METERS"
echo   A rack of live readings. Nothing here is invented.
echo.
set "MEMFREE="
set "MEMTOT="
for /f "usebackq skip=1 tokens=1,2" %%A in (`wmic OS get FreePhysicalMemory^,TotalVisibleMemorySize 2^>nul`) do (
    if not "%%B"=="" if not defined MEMTOT (
        set "MEMFREE=%%A"
        set "MEMTOT=%%B"
    )
)
if defined MEMTOT (
    set /a MEMPC=100-!MEMFREE!*100/!MEMTOT!
    call :meter "MEMORY  " !MEMPC!
)
set "CPULOAD="
for /f "usebackq skip=1 tokens=1" %%A in (`wmic cpu get loadpercentage 2^>nul`) do (
    if not "%%A"=="" if not defined CPULOAD set "CPULOAD=%%A"
)
if defined CPULOAD call :meter "CPU     " !CPULOAD!
call :st_count QS
set "QN=!ST_C!"
set /a QP=!QN!*10
if !QP! gtr 100 set "QP=100"
call :meter "QUESTS  " !QP!
call :brain_size
set /a BP=!BRAINN!*5
if !BP! gtr 100 set "BP=100"
call :meter "LESSONS " !BP!
echo.
echo   MEMORY and CPU are this machine. QUESTS is how full the list is,
echo   LESSONS is how much she has been taught.
call :hold
goto chat

:: --- one bar. 20 cells, filled to the percentage. -----------------------
:meter
set "bstr="
set /a bfill=%~2/5
if !bfill! lss 0 set "bfill=0"
if !bfill! gtr 20 set "bfill=20"
for /L %%I in (1,1,20) do (
    if %%I leq !bfill! (set "bstr=!bstr!#") else (set "bstr=!bstr!.")
)
set "bpc=   %~2"
echo      %~1  [!bstr!]  !bpc:~-3! percent
goto :eof

:brain_size
set "BRAINN=0"
if not exist "%BRAINFILE%" goto :eof
for /f "usebackq eol=# tokens=1 delims=|" %%A in ("%BRAINFILE%") do set /a BRAINN+=1
goto :eof

:n_NV
call :panel "NERVES"
echo   One faculty at a time, and whether it is working.
echo.
set "NVBAD=0"
call :nerve "SPEECH   " "%SPEAKER%" "speak.vbs, the voice"
call :nerve "MEMORY   " "%MEMFILE%" "ai_memory.db, what she is told"
call :nerve "LEARNING " "%BRAINFILE%" "ai_brain.db, what she was taught"
call :nerve "PLACES   " "%PLACES%" "places.cfg, the call signs"
call :nerve "APPS     " "%APPSREG%" "apps.reg, what she can launch"
call :nerve "ACCOUNTS " "%USERDB%" "users.db, who may log in"
call :nerve "LOG      " "%LOG1%" "the kernel stream"
echo.
if "!AI_VOICE!"=="1" (
    echo      [ OK ]     VOICE      SAPI is answering
) else (
    echo      [ WARN ]   VOICE      silent   STARP-0501
)
call :brain_size
echo      [ OK ]     LESSONS    !BRAINN! taught answers
echo.
if "!NVBAD!"=="0" (
    call :reply "Every nerve reports back. Nothing is broken."
) else (
    call :reply "!NVBAD! nerves are down. The panel shows which."
)
call :hold
goto chat

:nerve
if exist "%~2" (
    echo      [ OK ]     %~1 %~3
) else (
    echo      [ DOWN ]   %~1 %~3
    set /a NVBAD+=1
)
goto :eof

:n_LF
call :panel "LIFE HUB"
echo   Today, in one screen.
echo.
call :st_count QS
echo      Quests open ......... !ST_C!
call :st_count WN
echo      Wins today .......... !ST_C!
call :st_count LC
echo      Log entries ......... !ST_C!
call :st_count WL
echo      On the want list .... !ST_C!
call :st_count KI
echo      Ideas saved ......... !ST_C!
echo      Right now ........... %DATE% %TIME:~0,5%
echo.
echo   THE CHECKLIST
call :st_list QS
if "!ST_N!"=="0" echo       nothing on the list. QS add something.
echo.
echo   FO for focus.  QS for the whole checklist.  WN to log a win.
call :hold
goto chat

:n_FB
call :panel "FILES"
echo   Every folder starpOS can reach.
echo.
echo   -- starpOS root --
dir /b "%SYS%.." 2>nul
echo.
echo   -- data --
dir /b "%DATA%" 2>nul
echo.
echo   find WORD searches everything. read FILE prints one.
call :hold
goto chat

:n_SE
call :panel "SETTINGS"
echo   THEME       !THEMENAME!        change with:  theme attack
echo   BORDER      !BOXSTYLE!         change with:  box blade
echo   VOICE       rate !VOICE_RATE!, volume !VOICE_VOLUME!, on or off with: voice off
echo   NAME        !USER_NAME!
echo.
echo   Twelve themes. Five border sets. A theme may not change the border and
echo   a border may not change the colour, which is why they are two settings.
echo.
call :theme_presets
echo   THEMES
for /L %%I in (1,1,9) do (
    for /f "tokens=1,2,* delims=|" %%A in ("!TP_0%%I!") do echo      %%A
)
for /f "tokens=1,2,* delims=|" %%A in ("!TP_10!") do echo      %%A
for /f "tokens=1,2,* delims=|" %%A in ("!TP_11!") do echo      %%A
for /f "tokens=1,2,* delims=|" %%A in ("!TP_12!") do echo      %%A
echo.
echo   BORDERS   sharp   blade   hairline   pill   reticle
call :hold
goto chat

:: ===========================================================================
::  THE TOOLS
:: ===========================================================================
:n_FO
call :panel "FOCUS"
echo   One technique for how today is going wrong. Not a lecture.
echo.
set "fo1=Pick the smallest piece that still counts and do only that. Ten minutes."
set "fo2=Say the next physical action out loud. Not the task, the action. Open the file."
set "fo3=Set a timer for five minutes and start badly on purpose."
set "fo4=Write the first line wrong. A wrong line is easier to fix than a blank one."
set "fo5=Do the boring part first and let the interesting part be the reward."
set "fo6=Move to a different chair. The room you got stuck in keeps you stuck."
set "fo7=Tell me the task out loud. Half the time the saying is the unsticking."
set "fo8=Close everything but one window. A crowded screen is a crowded head."
call :pick fo 8
call :reply "!PICKED!"
echo.
call :st_count QS
if not "!ST_C!"=="0" (
    echo   And your first open quest is:
    call :st_get QS 1
    echo      !ST_TEXT!
)
call :stream ask "focus"
call :hold
goto chat

:n_TY
call :panel "TYPING"
echo   Type this line exactly, then press Enter.
echo.
set "ty1=the quick brown fox jumps over the lazy dog"
set "ty2=call bootcore then hand control to startup"
set "ty3=every line can be started in ten seconds"
set "ty4=two letters open a node and a digit picks which"
set "ty5=nothing is sent anywhere and nothing needs the internet"
call :pick ty 5
set "TYTARGET=!PICKED!"
echo      !TYTARGET!
echo.
set "T1=%TIME%"
set "ai_in="
call :ai_read "  type: "
set "T2=%TIME%"
call :tsec "!T1!"
set "CS1=!TCS!"
call :tsec "!T2!"
set /a ELAPSED=!TCS!-!CS1!
if !ELAPSED! lss 1 set "ELAPSED=1"
set /a SECS10=!ELAPSED!/10
echo.
echo      time     !SECS10! tenths of a second
if "!ai_in!"=="!TYTARGET!" (
    call :reply "Clean. Not one character out."
    call :stream win "typing clean"
) else (
    call :reply "Not exact, but the clock does not care. Run TY again."
)
call :hold
goto chat

:: --- clock to centiseconds, so two readings can be subtracted ----------
:tsec
set "TT=%~1"
set /a TH=1!TT:~0,2!-100
set /a TM=1!TT:~3,2!-100
set /a TS=1!TT:~6,2!-100
set /a TC=1!TT:~9,2!-100
set /a TCS=^(^(TH*60+TM^)*60+TS^)*100+TC
goto :eof

:n_AC
call :panel "ARCADE"
echo   A fact, a word, a better word, a roll. One pull of the handle.
echo.
set /a ACPICK=!RANDOM! %% 4
if "!ACPICK!"=="0" goto do_fact
if "!ACPICK!"=="1" goto do_joke
if "!ACPICK!"=="2" goto do_quote
set /a ACR=!RANDOM! %% 6 + 1
call :reply "The dice says !ACR!. Make of that what you like."
goto chat

:n_VD
call :panel "VIDEO FEED"
echo   Every film starpOS can see.
echo.
set "VN=0"
for /f "usebackq delims=" %%F in (`dir /b "%SYS%*.mkv" "%SYS%*.mp4" "%SYS%*.avi" 2^>nul`) do (
    set /a VN+=1
    echo      !VN!.  %%F
)
if "!VN!"=="0" (
    echo      No films in the system folder. Drop an mkv in and open VD again.
    echo      That is STARP-0601.
) else (
    echo.
    echo   The Movie Theater plays them:  open movies
)
call :hold
goto chat

:n_GY
call :panel "GALLERY"
echo   Every picture starpOS can see.
echo.
set "GN=0"
for /f "usebackq delims=" %%F in (`dir /b "%SYS%*.png" "%SYS%*.jpg" "%SYS%*.bmp" "%SYS%..\resources\*.png" 2^>nul`) do (
    set /a GN+=1
    echo      !GN!.  %%F
)
if "!GN!"=="0" echo      Nothing to show yet. Pictures go in the resources folder.
echo.
echo   Kohaku spins these on a ring. A console lists them.
call :hold
goto chat

:n_MV
call :panel "MODEL"
echo   One thing on a turntable. A console cannot spin it, so here it is flat.
echo.
echo            +--------+
echo           /        /^|
echo          /        / ^|
echo         +--------+  ^|
echo         ^|        ^|  +
echo         ^|        ^| /
echo         ^|        ^|/
echo         +--------+
echo.
set "MN=0"
for /f "usebackq delims=" %%F in (`dir /b "%SYS%..\resources\*.obj" "%SYS%..\resources\*.glb" 2^>nul`) do (
    set /a MN+=1
    echo      !MN!.  %%F
)
if "!MN!"=="0" echo      No model files in resources yet.
call :hold
goto chat

:n_CR
call :panel "CREATE"
echo   She writes a brief. Nothing is ever run.
echo.
if not defined PAYLOAD (
    echo   Say what to build:   CR a launcher that checks the log first
    echo.
    echo   Every brief is kept in the data folder as a text file you can read,
    echo   edit and hand to whatever actually builds it.
    call :hold
    goto chat
)
set "CRF=%DATA%\kh_brief_%RANDOM%.txt"
>"!CRF!" echo starpOS BRIEF
>>"!CRF!" echo written %DATE% %TIME:~0,5% by the AI assistant
>>"!CRF!" echo ------------------------------------------------------------
>>"!CRF!" echo.
>>"!CRF!" echo WHAT WAS ASKED FOR
>>"!CRF!" echo   !PAYLOAD!
>>"!CRF!" echo.
>>"!CRF!" echo QUESTIONS TO ANSWER BEFORE ANY CODE
>>"!CRF!" echo   1. What does it do on its very first run, with nothing set up
>>"!CRF!" echo   2. What does it do when the thing it needs is missing
>>"!CRF!" echo   3. Where does it keep what it remembers
>>"!CRF!" echo   4. How does someone turn it off
>>"!CRF!" echo.
>>"!CRF!" echo NOTHING IN THIS FILE HAS BEEN RUN.
call :stream ask "create: !PAYLOAD!"
call :reply "Brief written. Nothing was run."
echo      !CRF!
call :hold
goto chat

:n_GL
call :panel "THE GLOBE"
set "GLTO=!PAYLOAD!"
for %%V in ("send " "bring " "put " "show " "take " "point " "spin " "me "
            "the " "globe " "to ") do call :glstrip %%V
if defined GLTO (
    call :mem_set globe "!GLTO!"
    set "GLOC=!GLTO!"
) else (
    call :mem_get globe GLOC
)
if not defined GLOC set "GLOC=nowhere in particular"
echo               . - - - .
echo           .  '         '  .
echo         .   ___     ___     .
echo        .   /   \   /   \     .
echo        .   \___/   \___/     .
echo         .      ___          .
echo           .  '     '  .  . '
echo               ' - - '
echo.
echo   Pointed at:  !GLOC!
echo.
echo   Send it somewhere:  GL tokyo    or    globe to reykjavik
call :hold
goto chat

:: --- the summon verbs come off before the place name goes in ------------
:glstrip
set "GLTO=!GLTO:%~1=!"
goto :eof

:n_WB
call :panel "WEB"
echo   The browser lives outside starpOS. She will not open one on her own.
echo.
if defined PAYLOAD (
    echo   Ready to open:
    echo      !PAYLOAD!
    echo.
    echo   Type  WB go !PAYLOAD!  to actually open it in your default browser.
) else (
    echo   Nothing queued. Give it something:  WB anthropic.com
)
echo.
echo   Kohaku runs an allow list that fails closed. This one asks first,
echo   every time, which comes to the same thing on one machine.
call :hold
goto chat

:n_WB_go
if not defined PAYLOAD (
    call :reply "Give me the address:  WB go example.com"
    goto chat
)
call :reply "Opening !PAYLOAD! outside starpOS."
call :stream use "web !PAYLOAD!"
start "" "!PAYLOAD!"
goto chat

:: ===========================================================================
::  THE LOOK, AS COMMANDS
:: ===========================================================================
:do_theme
call :theme_presets
if not defined arg (
    call :panel "THEMES"
    echo   Twelve presets. One swap re-skins everything.
    echo.
    for /L %%I in (1,1,9) do (
        for /f "tokens=1,2,* delims=|" %%A in ("!TP_0%%I!") do echo      %%A   -  %%C
    )
    for /f "tokens=1,2,* delims=|" %%A in ("!TP_10!") do echo      %%A   -  %%C
    for /f "tokens=1,2,* delims=|" %%A in ("!TP_11!") do echo      %%A   -  %%C
    for /f "tokens=1,2,* delims=|" %%A in ("!TP_12!") do echo      %%A   -  %%C
    echo.
    echo   theme attack        switch to one
    echo   box blade           change the border instead
    call :hold
    goto chat
)
set "LOWIN=!arg!"
call :lower
set "want=!LOWOUT!"
set "NEWC="
set "NEWN="
for /L %%I in (1,1,9) do (
    for /f "tokens=1,2 delims=|" %%A in ("!TP_0%%I!") do (
        if "%%A"=="!want!" (
            set "NEWN=%%A"
            set "NEWC=%%B"
        )
    )
)
for %%J in (10 11 12) do (
    for /f "tokens=1,2 delims=|" %%A in ("!TP_%%J!") do (
        if "%%A"=="!want!" (
            set "NEWN=%%A"
            set "NEWC=%%B"
        )
    )
)
if not defined NEWC (
    call :reply "There is no theme called !arg!. Type theme on its own for the twelve."
    goto chat
)
color !NEWC!
set "THEMENAME=!NEWN!"
set "AI_THEME=!NEWC!"
call :mem_set theme "!NEWC!"
call :mem_set themename "!NEWN!"
call :reply "Theme is !NEWN! now, and I will still be wearing it next time."
goto chat

:do_box
if not defined arg (
    call :print "Borders: sharp, blade, hairline, pill, reticle. Try:  box blade"
    goto chat
)
set "LOWIN=!arg!"
call :lower
set "wantb=!LOWOUT!"
set "OKB="
for %%B in (sharp blade hairline pill reticle) do if "!wantb!"=="%%B" set "OKB=1"
if not defined OKB (
    call :reply "No border set called !arg!. Try sharp, blade, hairline, pill or reticle."
    goto chat
)
set "BOXSTYLE=!wantb!"
call :mem_set box "!wantb!"
call :box_apply
call :reply "Border set is !wantb! now."
goto do_board

:: ===========================================================================
::  THE FIFTY
:: ===========================================================================
:do_features
call :panel "WHAT CAME ACROSS FROM KOHAKU"
echo   BOARD AND GRAMMAR                     STORES
echo    1 the board, a wall of nodes          11 PR projects
echo    2 33 call signs in places.cfg         12 QS quests
echo    3 numbered signs, PR1 and LC2         13 NT note
echo    4 placement, M and M1 to M9           14 LC day log
echo    5 plain English for every code        15 WN daily wins
echo    6 summon verbs, bring and pull up     16 WL want list
echo    7 the codes card                      17 KI ideas
echo    8 first word is what she says back    18 AR archive
echo    9 what is on the board, tracked       19 IV inventory
echo   10 the table is data, not code         20 PC profiles
echo.
echo   LEARNING PANELS                        TOOLS
echo   21 DC dictionary                       27 FO focus techniques
echo   22 TT tech tips                        28 TY typing, timed
echo   23 TR training courses                 29 AC arcade
echo   24 DJ dojo drills                      30 SK sketch
echo   25 GU guides                           31 CR create, writes a brief
echo   26 AL asset list                       32 GL globe
echo.
echo   THE MACHINE                            33 WB web, asks first
echo   39 KH her status                       34 VD video feed
echo   40 DV device                           35 GY gallery
echo   41 MX meters, live bars                36 MV model
echo   42 NV nerves                           37 FB files
echo   43 LG log streams                      38 SE settings
echo   44 LF life hub
echo.
echo   LOOK AND SYSTEMS
echo   45 twelve theme presets                48 add, done and drop on every list
echo   46 five border sets                    49 guardian streams, four of them
echo   47 the orb and the status bar          50 live counts on the board
call :hold
goto chat

:: ===========================================================================
::  LEARNING ENGINE
::  Everything taught by hand lives in ai_brain.db in the data folder, one
::  lesson per line:      pattern|answer|times used
::  A lesson fires when the pattern appears anywhere in what you typed, and
::  only after every built in answer has failed to match.
:: ===========================================================================

:brain_init
if exist "%BRAINFILE%" goto :eof
>"%BRAINFILE%" echo # starpOS AI learned answers.   pattern^|answer^|times used
>>"%BRAINFILE%" echo # Taught with the teach and train commands inside ai.bat.
>>"%BRAINFILE%" echo # Remove a lesson with:  unteach PATTERN
goto :eof

:: --- does haystack %1 hold needle %2. The answer lands in FOUND. ---------
:contains
set "FOUND=0"
if "%~2"=="" goto :eof
setlocal EnableDelayedExpansion
set "hay=%~1"
set "ned=%~2"
set "res=1"
if "!hay:%ned%=!"=="!hay!" set "res=0"
endlocal & set "FOUND=%res%"
goto :eof

:: --- write one lesson, replacing any older copy of the same pattern ------
:brain_set
call :brain_init
findstr /v /b /i /c:"%~1|" "%BRAINFILE%" > "%BRAINFILE%.tmp" 2>nul
if not errorlevel 2 move /y "%BRAINFILE%.tmp" "%BRAINFILE%" >nul 2>nul
if exist "%BRAINFILE%.tmp" del "%BRAINFILE%.tmp" >nul 2>nul
>>"%BRAINFILE%" echo %~1^|%~2^|0
goto :eof

:: --- count one use of the lesson that just fired -------------------------
:brain_hit
if not exist "%BRAINFILE%" goto :eof
>"%BRAINFILE%.tmp" echo # starpOS AI learned answers.   pattern^|answer^|times used
>>"%BRAINFILE%.tmp" echo # Taught with the teach and train commands inside ai.bat.
>>"%BRAINFILE%.tmp" echo # Remove a lesson with:  unteach PATTERN
for /f "usebackq eol=# tokens=1,2,3 delims=|" %%A in ("%BRAINFILE%") do (
    set "BH=%%C"
    if not defined BH set "BH=0"
    if /i "%%A"=="%~1" set /a BH=!BH!+1
    >>"%BRAINFILE%.tmp" echo %%A^|%%B^|!BH!
)
move /y "%BRAINFILE%.tmp" "%BRAINFILE%" >nul 2>nul
goto :eof

:: --- last stop before the shrug: try everything I was ever taught --------
:brain_match
if not exist "%BRAINFILE%" goto do_unknown
set "BPAT="
set "BANS="
for /f "usebackq eol=# tokens=1,2,* delims=|" %%A in ("%BRAINFILE%") do (
    if not defined BANS (
        set "LOWIN=%%A"
        call :lower
        call :contains "!m!" "!LOWOUT!"
        if "!FOUND!"=="1" (
            set "BPAT=%%A"
            set "BANS=%%B"
        )
    )
)
if not defined BANS goto do_unknown
call :brain_hit "!BPAT!"
call :reply "!BANS!"
call :log "answered from a lesson: !BPAT!"
goto chat

:: ===========================================================================
::  TEACH  -  two shapes:
::     teach QUESTION = ANSWER    a brand new lesson
::     teach ANSWER               answers the last thing I could not handle
:: ===========================================================================
:do_teach
if not defined arg goto do_teach_hint
set "TPAT="
set "TANS="
if not "!arg:==!"=="!arg!" (
    for /f "tokens=1,* delims==" %%A in ("!arg!") do (
        set "TPAT=%%A"
        set "TANS=%%B"
    )
) else (
    if defined LASTUNKNOWN (
        set "TPAT=!LASTUNKNOWN!"
        set "TANS=!arg!"
    )
)
if not defined TPAT (
    call :print "I need both halves. Try:  teach who is scott = he wrote this system."
    call :print "Or ask me something I do not know first, then just:  teach THE ANSWER"
    goto chat
)
if not defined TANS (
    call :reply "The answer half is empty. Try:  teach the wifi = it is written on the router."
    goto chat
)
set "ai_in=!TPAT!"
call :ai_trim
set "TPAT=!ai_in!"
set "ai_in=!TANS!"
call :ai_trim
set "TANS=!ai_in!"
set "TPAT=!TPAT:|=!"
set "TANS=!TANS:|=!"
if "!TPAT:~2!"=="" (
    call :reply "That pattern is too short to match on. Give me at least three characters."
    goto chat
)
call :brain_set "!TPAT!" "!TANS!"
call :unk_drop "!TPAT!"
set "LASTUNKNOWN="
call :reply "Learned. From now on, anything containing !TPAT! gets that answer."
call :log "taught: !TPAT!"
goto chat

:do_teach_hint
if defined LASTUNKNOWN (
    call :print "The last thing I could not answer was:  !LASTUNKNOWN!"
    call :print "Teach me the answer with:   teach YOUR ANSWER HERE"
) else (
    call :print "Two ways to teach me something:"
    call :print "   teach QUESTION = ANSWER    a new lesson, right now"
    call :print "   teach ANSWER              answers whatever I just failed at"
)
call :print "Type  train  to work through everything I have failed at."
call :print "Type  brain  to see every lesson I already hold."
goto chat

:: --- take a question out of the unanswered pile --------------------------
:unk_drop
if not exist "%UNKFILE%" goto :eof
findstr /v /i /c:"%~1" "%UNKFILE%" > "%UNKFILE%.tmp" 2>nul
if not errorlevel 2 move /y "%UNKFILE%.tmp" "%UNKFILE%" >nul 2>nul
if exist "%UNKFILE%.tmp" del "%UNKFILE%.tmp" >nul 2>nul
goto :eof

:do_unteach
if not defined arg (
    call :print "Which lesson. Type brain to see the patterns, then:  unteach PATTERN"
    goto chat
)
if not exist "%BRAINFILE%" (
    call :reply "I have not been taught anything yet, so there is nothing to forget."
    goto chat
)
findstr /b /i /c:"!arg!|" "%BRAINFILE%" >nul 2>nul
if errorlevel 1 (
    call :reply "No lesson starts with !arg!. Type brain to see the exact patterns."
    goto chat
)
findstr /v /b /i /c:"!arg!|" "%BRAINFILE%" > "%BRAINFILE%.tmp" 2>nul
if not errorlevel 2 move /y "%BRAINFILE%.tmp" "%BRAINFILE%" >nul 2>nul
if exist "%BRAINFILE%.tmp" del "%BRAINFILE%.tmp" >nul 2>nul
call :reply "Forgotten. I no longer answer to !arg!."
call :log "unteach: !arg!"
goto chat

:: ===========================================================================
::  BRAIN  -  what have I been taught, and how often does it get used
:: ===========================================================================
:do_brain
call :banner "WHAT I HAVE BEEN TAUGHT"
call :brain_init
set "BC=0"
set "BUSED=0"
echo    USED  PATTERN                        ANSWER
echo    -------------------------------------------------------------------------
for /f "usebackq eol=# tokens=1,2,3 delims=|" %%A in ("%BRAINFILE%") do (
    set /a BC+=1
    set "bp=%%A                              "
    set "bh=    %%C"
    set /a BUSED+=%%C
    echo     !bh:~-4!  !bp:~0,30! %%B
)
echo.
if "!BC!"=="0" (
    call :reply "Nothing yet. Teach me with:  teach question = answer"
) else (
    call :reply "!BC! lessons, used !BUSED! times between them."
)
echo    Add one with teach, remove one with unteach, add lots with train.
call :hold
goto chat

:: ===========================================================================
::  TRAIN  -  work through the pile of questions I could not answer
:: ===========================================================================
:do_train
call :banner "TRAINING SESSION"
if not exist "%UNKFILE%" (
    call :reply "Nothing to learn yet. Ask me things I do not know, then run train."
    goto chat
)
set "TQ=0"
for /f "usebackq eol=# delims=" %%L in ("%UNKFILE%") do (
    set /a TQ+=1
    if !TQ! leq 100 set "q!TQ!=%%L"
)
if "!TQ!"=="0" (
    call :reply "The unanswered pile is empty. I am up to date."
    goto chat
)
if !TQ! gtr 100 set "TQ=100"
set "TRAINQ=!TQ!"
if !TRAINQ! gtr 15 set "TRAINQ=15"
echo    I have !TQ! questions I could not answer. Working through !TRAINQ! of them.
echo.
echo    Type the answer and press Enter to teach me.
echo    Press Enter on its own to skip one.
echo    Type  stop  to end the session early.
echo.
set "TAUGHT=0"
set "TRAINSTOP="
for /L %%I in (1,1,!TRAINQ!) do (
    if not defined TRAINSTOP (
        for %%X in (%%I) do set "curq=!q%%X!"
        echo.
        echo    -- question %%I of !TRAINQ! ------------------------------------------
        echo       !curq!
        set "ai_in="
        call :ai_read "     answer: "
        call :ai_trim
        if /i "!ai_in!"=="stop" (
            set "TRAINSTOP=1"
        ) else (
            if defined ai_in (
                set "aq=!curq:|=!"
                set "aa=!ai_in:|=!"
                call :brain_set "!aq!" "!aa!"
                set /a TAUGHT+=1
                set "done%%I=1"
                echo       learned.
            )
        )
    )
)
echo.
>"%UNKFILE%" echo # Questions ai.bat could not answer. Clear them with the train command.
for /L %%I in (1,1,!TQ!) do (
    if not defined done%%I (
        for %%X in (%%I) do set "keepq=!q%%X!"
        if defined keepq >>"%UNKFILE%" echo !keepq!
    )
)
echo ===============================================================================
if "!TAUGHT!"=="0" (
    call :reply "No new lessons this time."
) else (
    call :reply "Training done. I picked up !TAUGHT! new answers and I will keep them."
)
echo ===============================================================================
call :log "training session taught !TAUGHT! lessons"
call :hold
goto chat

:: ===========================================================================
::  FALLBACK  -  what to say when nothing matched and nothing was taught
:: ===========================================================================
:do_unknown
if not exist "%UNKFILE%" (
    >"%UNKFILE%" echo # Lines ai.bat could not answer. Add matches for them in the router.
)
>>"%UNKFILE%" echo !ai_safe!
call :log "unmatched input: !ai_safe!"
set "LASTUNKNOWN=!ai_safe!"
set "u1=I do not know that one yet."
set "u2=That is outside what I know so far."
set "u3=No match for that one."
set "u4=I have not been taught that."
call :pick u 4
call :reply "!PICKED!  Tell me the answer with:  teach YOUR ANSWER"
goto chat

:: ===========================================================================
::  LEAVING
:: ===========================================================================
:do_exit
set "b1=Shutting the AI module down. The desktop is waiting for you."
set "b2=Going quiet. Call me from the desktop whenever you need me."
set "b3=Session closed. Everything you told me is safe in the data folder."
call :pick b 3
if defined USER_NAME (
    call :reply "Goodbye !USER_NAME!. !PICKED!"
) else (
    call :reply "!PICKED!"
)
call :log "AI engine closed after !TURN! exchanges"
timeout /t 1 >nul 2>nul
endlocal
exit /b 0

:quiet_exit
call :log "one shot answer given"
endlocal
exit /b 0
