@echo off
REM PMC Terminal v5 - Launcher Script
REM AI: Simple launcher for the class-based version

echo Starting PMC Terminal v5...
echo.

REM Check if PowerShell is available
where powershell >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: PowerShell is not installed or not in PATH
    pause
    exit /b 1
)

REM Launch the application
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0main-class.ps1"

REM Check exit code
if %errorlevel% neq 0 (
    echo.
    echo Application exited with error code: %errorlevel%
    pause
)
