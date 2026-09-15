@echo off
title VISUAL SYNTH Gallery Updater
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync_gallery.ps1"
echo.
echo Finished. You can close this window.
pause
