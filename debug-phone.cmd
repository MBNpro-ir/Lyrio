@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\debug-phone.ps1" %*
pause
