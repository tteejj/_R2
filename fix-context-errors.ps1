# Quick Fix Script for Context Parameter Binding Issues
# Run this to fix the immediate errors while migrating to classes

Write-Host "Applying quick fixes for parameter binding issues..." -ForegroundColor Yellow

# Fix 1: Update panels.psm1 to ensure Context is never empty
$panelsPath = Join-Path $PSScriptRoot "layout\panels.psm1"
if (Test-Path $panelsPath) {
    Write-Host "Fixing panels.psm1..." -ForegroundColor Cyan
    
    $content = Get-Content $panelsPath -Raw
    
    # Fix empty context parameters
    $content = $content -replace 'Invoke-WithErrorHandling -Component "\$\(\$self\.Name\)\.(\w+)" -Context "([^"]*)"', {
        $component = $matches[1]
        $context = $matches[2]
        if ([string]::IsNullOrWhiteSpace($context)) {
            $context = $component
        }
        "Invoke-WithErrorHandling -Component `"`$(`$self.Name).$component`" -Context `"$context`""
    }
    
    $content | Set-Content $panelsPath -Encoding UTF8
    Write-Host "✓ Fixed empty Context parameters in panels.psm1" -ForegroundColor Green
}

# Fix 2: Update dashboard screen to prevent double Context parameters
$dashboardPath = Join-Path $PSScriptRoot "screens\dashboard-screen-helios.psm1"
if (Test-Path $dashboardPath) {
    Write-Host "Fixing dashboard-screen-helios.psm1..." -ForegroundColor Cyan
    
    # Backup original
    Copy-Item $dashboardPath "$dashboardPath.bak" -Force
    
    # Read content
    $lines = Get-Content $dashboardPath
    $newLines = @()
    
    foreach ($line in $lines) {
        # Fix lines that might cause double Context parameters
        if ($line -match 'Invoke-WithErrorHandling.*-Context.*-Context') {
            Write-Host "Found double Context parameter, fixing..." -ForegroundColor Yellow
            # Remove the duplicate -Context parameter
            $line = $line -replace '(-Context\s+"[^"]*"\s*){2,}', '$1'
        }
        
        # Ensure Context is never empty
        if ($line -match 'Invoke-WithErrorHandling.*-Context\s+""') {
            $line = $line -replace '-Context\s+""', '-Context "Operation"'
        }
        
        $newLines += $line
    }
    
    $newLines | Set-Content $dashboardPath -Encoding UTF8
    Write-Host "✓ Fixed dashboard screen issues" -ForegroundColor Green
}

# Fix 3: Create a wrapper function that validates parameters
$wrapperContent = @'
# Safe wrapper for Invoke-WithErrorHandling
function global:Safe-Invoke {
    param(
        [string]$Component,
        [string]$Context,
        [scriptblock]$ScriptBlock,
        [hashtable]$AdditionalData = @{}
    )
    
    # Ensure parameters are never empty
    if ([string]::IsNullOrWhiteSpace($Component)) {
        $Component = "UnknownComponent"
    }
    if ([string]::IsNullOrWhiteSpace($Context)) {
        $Context = "UnknownContext"
    }
    
    # Remove any duplicate parameters from AdditionalData
    if ($AdditionalData.ContainsKey("Component")) {
        $AdditionalData.Remove("Component")
    }
    if ($AdditionalData.ContainsKey("Context")) {
        $AdditionalData.Remove("Context")
    }
    
    # Call the original function
    Invoke-WithErrorHandling -Component $Component -Context $Context -ScriptBlock $ScriptBlock -AdditionalData $AdditionalData
}
'@

$wrapperPath = Join-Path $PSScriptRoot "utilities\safe-invoke.psm1"
$wrapperContent | Set-Content $wrapperPath -Encoding UTF8
Write-Host "✓ Created Safe-Invoke wrapper" -ForegroundColor Green

# Fix 4: Update TUI engine render function
$enginePath = Join-Path $PSScriptRoot "modules\tui-engine-v2.psm1"
if (Test-Path $enginePath) {
    Write-Host "Fixing TUI engine render issues..." -ForegroundColor Cyan
    
    $content = Get-Content $enginePath -Raw
    
    # Fix the specific render frame issue where Context might be passed twice
    $content = $content -replace 'Invoke-WithErrorHandling\s+-Component\s+"([^"]+)"\s+-Context\s+"([^"]+)"\s+-Context', 'Invoke-WithErrorHandling -Component "$1" -Context "$2"'
    
    # Ensure AdditionalData doesn't contain Component or Context
    $content = $content -replace '(-AdditionalData\s+@\{[^}]*)(Component\s*=\s*[^;]+;?)([^}]*\})', '$1$3'
    $content = $content -replace '(-AdditionalData\s+@\{[^}]*)(Context\s*=\s*[^;]+;?)([^}]*\})', '$1$3'
    
    $content | Set-Content $enginePath -Encoding UTF8
    Write-Host "✓ Fixed TUI engine render issues" -ForegroundColor Green
}

Write-Host "`n=== Quick Fixes Applied ===" -ForegroundColor Green
Write-Host "The immediate parameter binding issues should be resolved." -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Restart your PMC Terminal application"
Write-Host "2. If issues persist, run the full migration script:"
Write-Host "   .\migrate-to-classes.ps1" -ForegroundColor White
Write-Host ""
Write-Host "3. For a clean start with the new architecture:"
Write-Host "   .\start-pmc-class.ps1" -ForegroundColor White