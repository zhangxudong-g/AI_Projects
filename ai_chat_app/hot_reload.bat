@echo off
title Hot Reload
set "PATH=C:\Users\admin\flutter\flutter\bin;%PATH%"
cd /d "%~dp0"
echo Sending hot reload...
echo r > .flutter-dev-tools
echo Hot reload sent!
pause
