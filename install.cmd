@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Install.ps1" %*
set "result=%ERRORLEVEL%"
echo.
if not "%result%"=="0" echo Installation failed. Read the error and logs, then run this command again.
if not defined NVIM_SETUP_NO_PAUSE pause
exit /b %result%
