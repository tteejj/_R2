#
# FILE: main.ps1
# PURPOSE: PMC Terminal v5 "Helios" - Main Entry Point
# AI: This file has been refactored to orchestrate module loading and application startup
#     with a clear, dependency-aware, service-oriented architecture.
#

# Set strict mode for better error handling and PowerShell best practices.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Get the directory where this script is located to build absolute paths for modules.
$script:BasePath = Split-Path -Parent $MyInvocation.MyCommand.Path

# AI: Corrected module load order to include 'models.psm1' before 'data-manager.psm1'.
# This is critical because the DataManager service depends on the classes defined in the models.
$script:ModulesToLoad = @(
    # Core infrastructure (no dependencies)
    @{ Name = "event-system"; Path = "modules\event-system.psm1"; Required = $true },
    @{ Name = "models"; Path = "modules\models.psm1"; Required = $true },

    # Data and theme (depend on event system and models)
    @{ Name = "data-manager"; Path = "modules\data-manager.psm1"; Required = $true },
    @{ Name = "theme-manager"; Path = "modules\theme-manager.psm1"; Required = $true },

    # Framework (depends on event system)
    @{ Name = "tui-framework"; Path = "modules\tui-framework.psm1"; Required = $true },

    # Engine (depends on theme and framework)
    @{ Name = "tui-engine-v2"; Path = "modules\tui-engine-v2.psm1"; Required = $true },

    # Dialog system (depends on engine)
    @{ Name = "dialog-system"; Path = "modules\dialog-system.psm1"; Required = $true },

    # Services
    @{ Name = "navigation-service"; Path = "services\navigation-service.psm1"; Required = $true },
    @{ Name = "keybinding-service"; Path = "services\keybinding-service.psm1"; Required = $true },

    # Layout system
    @{ Name = "layout-panels"; Path = "layout\panels.psm1"; Required = $true },

    # Focus management (depends on event system)
    @{ Name = "focus-manager"; Path = "utilities\focus-manager.psm1"; Required = $true },

    # Components (depend on engine and panels)
    @{ Name = "tui-components"; Path = "components\tui-components.psm1"; Required = $true },
    @{ Name = "advanced-input-components"; Path = "components\advanced-input-components.psm1"; Required = $false },
    @{ Name = "advanced-data-components"; Path = "components\advanced-data-components.psm1"; Required = $true }
)

# Screen modules will be loaded dynamically by the framework.
$script:ScreenModules = @(
    "dashboard-screen-helios",
    "task-screen",              # AI: Fixed - this contains Get-TaskManagementScreen
    "task-dialog-screen", 
    "project-list-screen",
    "reports-screen",
    "settings-screen",
    "simple-test-screen"        # AI: Added for consistency with navigation routes.
)

function Initialize-PMCModules {
    param([bool]$Silent = $false)
    
    return Invoke-WithErrorHandling -ScriptBlock {
        if (-not $Silent) {
            Write-Host "Verifying console environment..." -ForegroundColor Gray
        }
        $minWidth = 80
        $minHeight = 24
        if ($Host.UI.RawUI) {
            if ($Host.UI.RawUI.WindowSize.Width -lt $minWidth -or $Host.UI.RawUI.WindowSize.Height -lt $minHeight) {
                Write-Host "Console window too small. Please resize to at least $minWidth x $minHeight and restart." -ForegroundColor Yellow
                Read-Host "Press Enter to exit."
                throw "Console window too small."
            }
        }

        $loadedModules = @()
        $totalModules = $script:ModulesToLoad.Count
        $currentModule = 0

        foreach ($module in $script:ModulesToLoad) {
            $currentModule++
            $modulePath = Join-Path $script:BasePath $module.Path
            
            if (-not $Silent) {
                $percent = [Math]::Round(($currentModule / $totalModules) * 100)
                Write-Host "`rLoading modules... [$percent%] $($module.Name)" -NoNewline -ForegroundColor Cyan
            }
            
            if (Test-Path $modulePath) {
                try {
                    Import-Module $modulePath -Force -Global
                    $loadedModules += $module.Name
                } catch {
                    if ($module.Required) {
                        Write-Host "`nFATAL: Failed to load required module: $($module.Name)" -ForegroundColor Red
                        throw "Failed to load required module: $($module.Name). Error: $($_.Exception.Message)"
                    } else {
                        if (-not $Silent) { Write-Host "`nSkipping optional module: $($module.Name)" -ForegroundColor Yellow }
                    }
                }
            } else {
                if ($module.Required) {
                    throw "Required module file not found: $($module.Name) at $modulePath"
                }
            }
        }
        
        if (-not $Silent) { Write-Host "`rModules loaded successfully.                                    " -ForegroundColor Green }
        return $loadedModules
    } -Component "ModuleLoader" -Context "Initializing core and utility modules"
}

function Initialize-PMCScreens {
    param([bool]$Silent = $false)
    
    return Invoke-WithErrorHandling -ScriptBlock {
        if (-not $Silent) { Write-Host "Loading screens..." -ForegroundColor Cyan }
        
        $loadedScreens = @()
        foreach ($screenName in $script:ScreenModules) {
            $screenPath = Join-Path $script:BasePath "screens\$screenName.psm1"
            if (Test-Path $screenPath) {
                try {
                    Import-Module $screenPath -Force -Global
                    $loadedScreens += $screenName
                } catch {
                    Write-Warning "Failed to load screen module '$screenName': $_"
                }
            }
        }
        
        if (-not $Silent) { Write-Host "Screens loaded: $($loadedScreens.Count) of $($script:ScreenModules.Count)" -ForegroundColor Green }
        return $loadedScreens
    } -Component "ScreenLoader" -Context "Initializing screen modules"
}

# AI: Removed the Initialize-PMCServices function. Service initialization is now handled
#     directly and explicitly within Start-PMCTerminal for clarity and correct dependency injection.

function Start-PMCTerminal {
    param([bool]$Silent = $false)
    
    Invoke-WithErrorHandling -ScriptBlock {
        Write-Log -Level Info -Message "PMC Terminal v5 'Helios' startup initiated."
        
        # --- 1. Load Core Modules ---
        $loadedModules = Initialize-PMCModules -Silent:$Silent
        Write-Log -Level Info -Message "Core modules loaded: $($loadedModules -join ', ')"
        
        # --- 2. Load UI Screens (before services that depend on them) ---
        # AI: Moved screen loading before service initialization so screen functions are available
        $loadedScreens = Initialize-PMCScreens -Silent:$Silent
        Write-Log -Level Info -Message "Screen modules loaded: $($loadedScreens -join ', ')"
        
        # --- 3. Initialize Core Systems (in dependency order) ---
        # AI: The service initialization sequence is now explicit and ordered by dependency.
        Initialize-EventSystem
        Initialize-ThemeManager
        $dataManagerService = Initialize-DataManager
        Initialize-TuiFramework
        Initialize-FocusManager
        Initialize-DialogSystem
        
        # --- 4. Initialize and Assemble Services ---
        $services = @{
            DataManager = $dataManagerService
        }
        
        # AI: Create class-based services (screens are now loaded)
        if (-not (Get-Module "navigation-service" -ListAvailable)) {
            Write-Log -Level Warning -Message "Navigation service module not loaded via normal module loading process"
        }
        $services.Navigation = Initialize-NavigationService $services
        $services.Keybindings = Initialize-KeybindingService -EnableChords $false
        $global:Services = $services
        Write-Log -Level Info -Message "All services initialized and assembled."
        
        # --- 5. Register Navigation Routes ---
        # AI: Routes are now registered automatically in the class constructor
        Write-Log -Level Info -Message "Navigation routes registered automatically."
        
        # --- 6. Initialize TUI Engine and Navigate ---
        if (-not $Silent) { Write-Host "`nStarting TUI..." -ForegroundColor Green }
        Clear-Host
        
        Initialize-TuiEngine
        
        $startPath = if ($args -contains "-start" -and ($args.IndexOf("-start") + 1) -lt $args.Count) {
            $args[$args.IndexOf("-start") + 1]
        } else {
            "/dashboard"
        }
        
        if (-not $services.Navigation.IsValidRoute($startPath)) {
            Write-Log -Level Warning -Message "Startup path '$startPath' is not valid. Defaulting to /dashboard."
            $startPath = "/dashboard"
        }
        
        [void]$services.Navigation.GoTo($startPath)
        
        # --- 7. Start the Main Loop ---
        Start-TuiLoop
        
        Write-Log -Level Info -Message "PMC Terminal exited gracefully."
    } -Component "Application" -Context "Main startup sequence"
}

# ===================================================================
# MAIN EXECUTION BLOCK
# ===================================================================
try {
    # CRITICAL: Pre-load logger and exceptions BEFORE anything else to ensure
    # error handling and logging are available throughout the entire startup sequence.
    $loggerModulePath = Join-Path $script:BasePath "modules\logger.psm1"
    $exceptionsModulePath = Join-Path $script:BasePath "modules\exceptions.psm1"
    
    if (-not (Test-Path $exceptionsModulePath)) { throw "CRITICAL: The core exceptions module is missing at '$exceptionsModulePath'." }
    if (-not (Test-Path $loggerModulePath)) { throw "CRITICAL: The core logger module is missing at '$loggerModulePath'." }
    
    Import-Module $exceptionsModulePath -Force -Global
    Import-Module $loggerModulePath -Force -Global

    # Now that logger is available, initialize it.
    Initialize-Logger
    
    # Start the main application logic, wrapped in top-level error handling.
    Start-PMCTerminal -Silent:$false
    
} catch {
    # This is our absolute last resort error handler.
    $errorMessage = "A fatal, unhandled exception occurred during application startup: $($_.Exception.Message)"
    Write-Host "`n$errorMessage" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    
    # Try to log if possible.
    if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
        Write-Log -Level Fatal -Message $errorMessage -Data @{
            Exception = $_.Exception
            ScriptStackTrace = $_.ScriptStackTrace
        } -Force
    }
    
    # Exit with a non-zero code to indicate failure.
    exit 1
}