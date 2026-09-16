@echo off
title VISUAL SYNTH Gallery Publisher
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0publish_gallery.ps1"
echo.
pause
