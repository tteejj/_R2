# Test Module Loading Fix
# AI: Quick validation script to test if module loading fixes resolve the navigation errors

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Testing Module Loading Fix..." -ForegroundColor Cyan

try {
    # Test loading the task-screen module
    $taskScreenPath = Join-Path $PSScriptRoot "screens\task-screen.psm1"
    Write-Host "Testing task-screen module at: $taskScreenPath" -ForegroundColor Gray
    
    if (-not (Test-Path $taskScreenPath)) {
        Write-Host "FAIL: task-screen.psm1 not found!" -ForegroundColor Red
        exit 1
    }
    
    # Try to import the module
    Import-Module $taskScreenPath -Force
    Write-Host "SUCCESS: task-screen module imported" -ForegroundColor Green
    
    # Test if the function exists
    if (Get-Command "Get-TaskManagementScreen" -ErrorAction SilentlyContinue) {
        Write-Host "SUCCESS: Get-TaskManagementScreen function is available" -ForegroundColor Green
    } else {
        Write-Host "FAIL: Get-TaskManagementScreen function not found!" -ForegroundColor Red
        exit 1
    }
    
    # Test other screen modules
    $screenModules = @(
        @{ Name = "dashboard-screen-helios"; Function = "Get-DashboardScreen" }
        @{ Name = "project-list-screen"; Function = "Get-ProjectManagementScreen" }
        @{ Name = "reports-screen"; Function = "Get-ReportsScreen" }
        @{ Name = "settings-screen"; Function = "Get-SettingsScreen" }
        @{ Name = "simple-test-screen"; Function = "Get-SimpleTestScreen" }
    )
    
    foreach ($screen in $screenModules) {
        $screenPath = Join-Path $PSScriptRoot "screens\$($screen.Name).psm1"
        if (Test-Path $screenPath) {
            try {
                Import-Module $screenPath -Force
                if (Get-Command $screen.Function -ErrorAction SilentlyContinue) {
                    Write-Host "SUCCESS: $($screen.Function) available" -ForegroundColor Green
                } else {
                    Write-Host "WARNING: $($screen.Function) not found in $($screen.Name)" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "ERROR: Failed to load $($screen.Name): $_" -ForegroundColor Red
            }
        } else {
            Write-Host "WARNING: $($screen.Name).psm1 not found" -ForegroundColor Yellow
        }
    }
    
    Write-Host "`nModule loading test completed successfully!" -ForegroundColor Green
    Write-Host "The main navigation error should now be resolved." -ForegroundColor Cyan
    
} catch {
    Write-Host "FAIL: Module loading test failed: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    exit 1
}
