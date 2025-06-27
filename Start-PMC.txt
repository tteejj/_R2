# PMC Terminal v5 - PowerShell Launcher
# AI: Quick launcher script for development and testing

# Ensure we're in the correct directory
Push-Location $PSScriptRoot

try {
    # Set execution policy for this session
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

    # Clear screen
    Clear-Host
    
    # Display header
    Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          PMC Terminal v5 - Class Edition             ║" -ForegroundColor Cyan
    Write-Host "║                                                      ║" -ForegroundColor Cyan
    Write-Host "║  A PowerShell Task Management System                 ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # Launch the main application
    & ".\main-class.ps1"
}
catch {
    Write-Host "`nError launching PMC Terminal: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    Read-Host "`nPress Enter to exit"
}
finally {
    Pop-Location
}
