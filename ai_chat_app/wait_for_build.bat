@echo off
title Wait for Build
setlocal enabledelayedexpansion

echo Waiting for web build...
for /l %%i in (1,1,10) do (
    if exist "build\web\index.html" (
        echo Build complete!
        goto :done
    )
    echo Waiting... attempt !i!
    timeout /t 30 /nobreak >nul
)

echo Build may still be running...
:done
if exist "build\web\index.html" (
    echo Opening in Chrome...
    start "" "build\web\index.html"
)
pause
