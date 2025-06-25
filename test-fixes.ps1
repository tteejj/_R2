# Test script to verify the fixes made to the HELIOS refactored application

# Set up the environment
$script:BasePath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $script:BasePath

Write-Host "PMC Terminal v5 'HELIOS' - Fix Validation Test" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Import required modules first
Write-Host "Importing core modules..." -ForegroundColor Yellow
try {
    Import-Module ".\modules\logger.psm1" -Force -Global
    Import-Module ".\modules\exceptions.psm1" -Force -Global
    Initialize-Logger
    Write-Host "✓ Logger and exceptions loaded" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to load core modules: $_" -ForegroundColor Red
    exit 1
}

# Test 1: Verify New-TuiTextBlock -> New-TuiLabel fix
Write-Host "`nTest 1: Checking dashboard screen for New-TuiLabel usage..." -ForegroundColor Yellow
$dashboardContent = Get-Content ".\screens\dashboard-screen-helios.psm1" -Raw
if ($dashboardContent -match "New-TuiTextBlock") {
    Write-Host "✗ Dashboard still contains New-TuiTextBlock (should be New-TuiLabel)" -ForegroundColor Red
} else {
    Write-Host "✓ Dashboard correctly uses New-TuiLabel" -ForegroundColor Green
}

# Test 2: Check for Context parameter issues in components
Write-Host "`nTest 2: Checking for Context parameter issues..." -ForegroundColor Yellow
$componentFiles = @(
    ".\components\tui-components.psm1",
    ".\components\advanced-data-components.psm1",
    ".\components\advanced-input-components.psm1"
)

$contextIssues = 0
foreach ($file in $componentFiles) {
    if (Test-Path $file) {
        $content = Get-Content $file -Raw
        # Check for -Context @{ pattern (should use -AdditionalData instead)
        if ($content -match '-Context\s+@\{') {
            Write-Host "✗ $file contains -Context with hashtable (should use -AdditionalData)" -ForegroundColor Red
            $contextIssues++
        }
    }
}

if ($contextIssues -eq 0) {
    Write-Host "✓ No Context parameter issues found" -ForegroundColor Green
} else {
    Write-Host "✗ Found $contextIssues files with Context parameter issues" -ForegroundColor Red
}

# Test 3: Verify required modules are available
Write-Host "`nTest 3: Checking module availability..." -ForegroundColor Yellow
$requiredModules = @(
    ".\layout\panels.psm1",
    ".\components\tui-components.psm1",
    ".\components\advanced-data-components.psm1"
)

$missingModules = 0
foreach ($module in $requiredModules) {
    if (Test-Path $module) {
        Write-Host "✓ Found: $module" -ForegroundColor Green
    } else {
        Write-Host "✗ Missing: $module" -ForegroundColor Red
        $missingModules++
    }
}

# Test 4: Try to import the fixed modules
Write-Host "`nTest 4: Testing module imports..." -ForegroundColor Yellow
$importErrors = 0

try {
    Import-Module ".\layout\panels.psm1" -Force -Global
    Write-Host "✓ panels.psm1 imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import panels.psm1: $_" -ForegroundColor Red
    $importErrors++
}

try {
    Import-Module ".\components\tui-components.psm1" -Force -Global
    Write-Host "✓ tui-components.psm1 imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import tui-components.psm1: $_" -ForegroundColor Red
    $importErrors++
}

try {
    Import-Module ".\components\advanced-data-components.psm1" -Force -Global
    Write-Host "✓ advanced-data-components.psm1 imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import advanced-data-components.psm1: $_" -ForegroundColor Red
    $importErrors++
}

# Test 5: Verify functions are available
Write-Host "`nTest 5: Checking function availability..." -ForegroundColor Yellow
$requiredFunctions = @(
    "New-TuiLabel",
    "New-TuiStackPanel",
    "New-TuiDataTable"
)

$missingFunctions = 0
foreach ($func in $requiredFunctions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "✓ Function available: $func" -ForegroundColor Green
    } else {
        Write-Host "✗ Function missing: $func" -ForegroundColor Red
        $missingFunctions++
    }
}

# Summary
Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "SUMMARY:" -ForegroundColor Cyan

$totalIssues = $contextIssues + $missingModules + $importErrors + $missingFunctions

if ($totalIssues -eq 0) {
    Write-Host "✓ All tests passed! The fixes appear to be working correctly." -ForegroundColor Green
    Write-Host "  You should now be able to run main.ps1 without the reported errors." -ForegroundColor Green
} else {
    Write-Host "✗ Found $totalIssues issues that need attention." -ForegroundColor Red
    Write-Host "  Please review the errors above and fix them before running main.ps1." -ForegroundColor Yellow
}

Write-Host "`nTo run the application: .\main.ps1" -ForegroundColor Cyan