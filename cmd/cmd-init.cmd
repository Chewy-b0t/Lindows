@echo off
set "LINDOWS_HOME=%~dp0.."
set "PATH=%LINDOWS_HOME%\bin;%PATH%"
prompt $P$G
if exist "%LINDOWS_HOME%\cmd\macros.doskey" doskey /macrofile="%LINDOWS_HOME%\cmd\macros.doskey"
