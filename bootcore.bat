@echo off
title starpOS Kernel Core 

:: Set system variables
set OS_NAME=starpOS
set OS_VERSION=1.0.0
set OS_DEVELOPER=User 

:: Establish storage directory and log tracking targets
set LOG_DIR=..\data
set _s1=%LOG_DIR%\1.log
set _s2=%LOG_DIR%\2.log
set _s3=%LOG_DIR%\3.log 

echo [ CORE ] BootCore successfully initialized.
echo [ CORE ] Registering environment paths...
timeout /t 1 >nul 

echo [ CORE ] Initializing storage system...
timeout /t 1 >nul 

:: Ensure data directory exists
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" 

:: Verify data file integrity
if not exist "%LOG_DIR%\data soreerr v1.3" (
echo starpOS System Data File > "%LOG_DIR%\data soreerr v1.3"
echo Version=1.3 >> "%LOG_DIR%\data soreerr v1.3"
echo Status=Operational >> "%LOG_DIR%\data soreerr v1.3"
) 

:: Clear stream targets and stamp new session tracking markers
echo =================================== > "%_s2%"
echo starpOS SYSTEM LOG - NEW SESSION    >> "%_s2%"
echo =================================== >> "%_s2%" 

echo =================================== > "%_s3%"
echo starpOS USER LOG - NEW SESSION      >> "%_s3%"
echo =================================== >> "%_s3%" 

echo [%TIME%] [SYSTEM] BootCore started initialization sequence. >> "%_s1%"
echo [%TIME%] [SYSTEM] BootCore started initialization sequence. >> "%_s2%" 

:: Scan folder and execute external batch files automatically
echo [%TIME%] [SYSTEM] Scanning for startup batch files... >> "%_s1%"
echo [%TIME%] [SYSTEM] Scanning for startup batch files... >> "%_s2%" 

for %%F in (*.bat) do (
if /I not "%%F"=="boot.bat" (
if /I not "%%F"=="bootcore.bat" (
if /I not "%%F"=="startup.bat" (
if /I not "%%F"=="updates.bat" (
echo [%TIME%] [LAUNCH] Executing external script: %%F >> "%_s1%"
echo [%TIME%] [LAUNCH] Executing external script: %%F >> "%_s2%" 

            call "%%F"
            
            echo [%TIME%] [LAUNCH] Finished executing: %%F >> "%_s1%"
            echo [%TIME%] [LAUNCH] Finished executing: %%F >> "%_s2%"
        )
    )
)

)

) 

echo [%TIME%] [SYSTEM] Handing over control to startup.bat Desktop environment. >> "%_s1%"
echo [%TIME%] [SYSTEM] Handing over control to startup.bat Desktop environment. >> "%_s2%" 

:: Launch Desktop 
call startup.bat 
