@echo off
color 02
title starpOS Launcher 2
goto :2nd bach


:2nd bach
@echo off
title loading
cd system
call bootcore.bat
goto :fille bach


:fille bach
title good by
cd system
call boot.bat
pause
exit
