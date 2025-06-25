# Migration Script - From Hashtable Components to PowerShell Classes
# Run this to update your PMC Terminal v5 to use the new class-based architecture

param(
    [switch]$TestOnly,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Write-Host "=== PMC Terminal v5 - Class Migration Script ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Backup current configuration
Write-Host "Step 1: Creating backup..." -ForegroundColor Yellow
$backupPath = Join-Path $PSScriptRoot "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
if (-not $TestOnly) {
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    Copy-Item -Path "$PSScriptRoot\*" -Destination $backupPath -Recurse -Exclude "backup_*"
    Write-Host "Backup created at: $backupPath" -ForegroundColor Green
} else {
    Write-Host "TEST MODE: Backup would be created at: $backupPath" -ForegroundColor Gray
}

# Step 2: Import new modules
Write-Host "`nStep 2: Loading new class-based modules..." -ForegroundColor Yellow
try {
    # Import base classes first
    Import-Module "$PSScriptRoot\components\ui-classes.psm1" -Force
    Import-Module "$PSScriptRoot\components\panel-classes.psm1" -Force
    Import-Module "$PSScriptRoot\utilities\error-handling-fix.psm1" -Force
    
    Write-Host "Base classes loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to load base classes: $_" -ForegroundColor Red
    exit 1
}

# Step 3: Update initialization scripts
Write-Host "`nStep 3: Updating initialization scripts..." -ForegroundColor Yellow

$initScriptContent = @'
# PMC Terminal v5 - Class-Based Initialization
# Updated initialization script using PowerShell classes

param(
    [string]$InitialScreen = "DashboardScreen"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Import all required modules in correct order
$modulesToLoad = @(
    # Utilities first
    "utilities\logging.psm1"
    "utilities\events.psm1"
    "utilities\exceptions.psm1"
    "utilities\error-handling-fix.psm1"
    
    # Base classes
    "components\ui-classes.psm1"
    "components\panel-classes.psm1"
    
    # Services (class-based)
    "services\navigation-service-class.psm1"
    "services\data-manager.psm1"
    
    # Screens (class-based)
    "screens\dashboard\dashboard-screen-class.psm1"
    
    # TUI Engine
    "modules\tui-engine-v2.psm1"
)

foreach ($module in $modulesToLoad) {
    $modulePath = Join-Path $PSScriptRoot $module
    if (Test-Path $modulePath) {
        try {
            Import-Module $modulePath -Force
            Write-Host "Loaded: $module" -ForegroundColor Gray
        } catch {
            Write-Host "ERROR loading $module`: $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "WARNING: Module not found: $module" -ForegroundColor Yellow
    }
}

# Initialize services
Write-Host "`nInitializing services..." -ForegroundColor Cyan
$services = @{}

try {
    # Create navigation service
    $services.Navigation = [NavigationService]::new($services)
    
    # Create data manager (if it exists)
    if (Get-Command -Name "Get-DataManager" -ErrorAction SilentlyContinue) {
        $services.DataManager = Get-DataManager
    }
    
    # Register class-based screens with the factory
    if (Get-Command -Name "Get-DashboardScreen" -ErrorAction SilentlyContinue) {
        # Still using legacy screen
        Write-Host "Using legacy dashboard screen" -ForegroundColor Yellow
    } else {
        # Using new class-based screen
        $services.Navigation.ScreenFactory.RegisterScreen("DashboardScreen", [DashboardScreen])
        Write-Host "Registered class-based dashboard screen" -ForegroundColor Green
    }
    
} catch {
    Write-Host "ERROR initializing services: $_" -ForegroundColor Red
    exit 1
}

# Start the application
Write-Host "`nStarting PMC Terminal v5..." -ForegroundColor Green
try {
    Initialize-TuiEngine
    
    # Push initial screen
    $services.Navigation.PushScreen($InitialScreen)
    
    # Start main loop
    Start-TuiLoop
    
} catch {
    Write-Host "`nFATAL ERROR: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
} finally {
    Write-Host "`nShutting down..." -ForegroundColor Yellow
    if (Get-Command -Name "Cleanup-TuiEngine" -ErrorAction SilentlyContinue) {
        Cleanup-TuiEngine
    }
}

Write-Host "PMC Terminal v5 terminated." -ForegroundColor Cyan
'@

if (-not $TestOnly) {
    $initScriptContent | Set-Content -Path "$PSScriptRoot\start-pmc-class.ps1" -Encoding UTF8
    Write-Host "Created new initialization script: start-pmc-class.ps1" -ForegroundColor Green
} else {
    Write-Host "TEST MODE: Would create start-pmc-class.ps1" -ForegroundColor Gray
}

# Step 4: Test the new architecture
Write-Host "`nStep 4: Testing new architecture..." -ForegroundColor Yellow

try {
    # Test class instantiation
    $testServices = @{}
    $testScreen = [DashboardScreen]::new($testServices)
    Write-Host "✓ Dashboard screen class instantiation successful" -ForegroundColor Green
    
    # Test panel classes
    $testPanel = [BorderPanel]::new("TestPanel", 0, 0, 50, 20)
    Write-Host "✓ Panel class instantiation successful" -ForegroundColor Green
    
    # Test navigation service
    $testNav = [NavigationService]::new($testServices)
    Write-Host "✓ Navigation service instantiation successful" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Test failed: $_" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor DarkGray
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}

# Step 5: Migration checklist
Write-Host "`n=== Migration Checklist ===" -ForegroundColor Cyan
Write-Host "1. [ ] Update all Invoke-WithErrorHandling calls to use Invoke-ClassMethod in classes"
Write-Host "2. [ ] Convert remaining screens to PowerShell classes"
Write-Host "3. [ ] Update all component factories to return class instances"
Write-Host "4. [ ] Remove all \$script: scope variables (use class properties instead)"
Write-Host "5. [ ] Update event handlers to use class methods"
Write-Host "6. [ ] Test all navigation paths"
Write-Host "7. [ ] Update documentation"

# Step 6: Next steps
Write-Host "`n=== Next Steps ===" -ForegroundColor Yellow
Write-Host "1. Run the new initialization script:"
Write-Host "   .\start-pmc-class.ps1" -ForegroundColor White
Write-Host ""
Write-Host "2. If issues occur, restore from backup:"
Write-Host "   Copy-Item -Path '$backupPath\*' -Destination '$PSScriptRoot' -Recurse -Force" -ForegroundColor White
Write-Host ""
Write-Host "3. Continue migrating screens using the artifact:"
Write-Host "   - Use dashboard-screen-class.psm1 as a template"
Write-Host "   - Follow the patterns in ui-classes.psm1"
Write-Host ""

Write-Host "Migration script completed!" -ForegroundColor Green