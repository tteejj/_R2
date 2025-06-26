# Helios Application Startup Script
# This script properly initializes all services and starts the TUI application

param(
    [switch]$Debug
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Get script root
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

try {
    # Clear screen
    Clear-Host
    
    Write-Host "Starting PMC Terminal v5 (Helios Edition)..." -ForegroundColor Cyan
    Write-Host ""
    
    # Import required modules
    Write-Host "Loading modules..." -ForegroundColor Gray
    
    # Core modules
    Import-Module "$scriptRoot\modules\logger.psm1" -Force
    Import-Module "$scriptRoot\modules\exceptions.psm1" -Force
    Import-Module "$scriptRoot\modules\event-system.psm1" -Force
    Import-Module "$scriptRoot\modules\models.psm1" -Force
    Import-Module "$scriptRoot\modules\tui-engine-v2.psm1" -Force
    Import-Module "$scriptRoot\modules\tui-framework.psm1" -Force
    Import-Module "$scriptRoot\modules\theme-manager.psm1" -Force
    
    # Utilities
    Import-Module "$scriptRoot\utilities\focus-manager.psm1" -Force
    
    # Components
    Import-Module "$scriptRoot\components\tui-components.psm1" -Force
    Import-Module "$scriptRoot\components\advanced-data-components.psm1" -Force
    Import-Module "$scriptRoot\layout\panels.psm1" -Force
    
    # Services
    Import-Module "$scriptRoot\services\navigation-service.psm1" -Force
    Import-Module "$scriptRoot\services\data-manager.psm1" -Force
    
    # Screens
    Import-Module "$scriptRoot\screens\dashboard-screen-helios.psm1" -Force
    Import-Module "$scriptRoot\screens\task-screen.psm1" -Force -ErrorAction SilentlyContinue
    
    Write-Host "Modules loaded successfully!" -ForegroundColor Green
    Write-Host ""
    
    # Initialize logging
    $logLevel = if ($Debug) { "Debug" } else { "Info" }
    Initialize-Logger -Level $logLevel
    Write-Log -Level Info -Message "Application starting"
    
    # Initialize event system
    Initialize-EventSystem
    Write-Log -Level Info -Message "Event system initialized"
    
    # Initialize theme
    Initialize-ThemeManager
    Write-Log -Level Info -Message "Theme manager initialized"
    
    # Initialize TUI engine
    Initialize-TuiEngine
    Initialize-TuiFramework
    Write-Log -Level Info -Message "TUI engine initialized"
    
    # Create services
    Write-Host "Creating services..." -ForegroundColor Gray
    
    # Create a proper services hashtable
    $global:Services = @{}
    
    # Initialize data manager
    $global:Services.DataManager = [DataManager]::new()
    $global:Services.DataManager.LoadData()
    Write-Log -Level Info -Message "Data manager initialized"
    
    # Initialize navigation service with all services
    $global:Services.Navigation = [NavigationService]::new($global:Services)
    Write-Log -Level Info -Message "Navigation service initialized"
    
    # Create initial data if needed
    $tasks = $global:Services.DataManager.GetTasks()
    if ($tasks.Count -eq 0) {
        Write-Host "Creating sample data..." -ForegroundColor Gray
        
        # Create sample project
        $project = [Project]::new("Sample Project", "This is a sample project")
        $project = $global:Services.DataManager.AddProject($project)
        
        # Create sample tasks
        $sampleTasks = @(
            @{ Title = "Welcome to PMC Terminal!"; Description = "Your task management system"; Priority = [TaskPriority]::High }
            @{ Title = "Press 1 for Tasks"; Description = "Navigate to task management"; Priority = [TaskPriority]::Medium }
            @{ Title = "Use arrow keys to navigate"; Description = "Move between menu items"; Priority = [TaskPriority]::Low }
        )
        
        foreach ($taskData in $sampleTasks) {
            $task = [Task]::new($taskData.Title, $taskData.Description)
            $task.Priority = $taskData.Priority
            $task.ProjectId = $project.Id
            $global:Services.DataManager.AddTask($task)
        }
    }
    
    Write-Host "Services created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Starting application..." -ForegroundColor Yellow
    Start-Sleep -Milliseconds 500
    
    # Create and start with dashboard screen
    $dashboardScreen = Get-DashboardScreen -Services $global:Services
    
    # Start the TUI loop
    Start-TuiLoop -InitialScreen $dashboardScreen
    
    Write-Host "`nThank you for using PMC Terminal v5!" -ForegroundColor Cyan
}
catch {
    Write-Host "`nFATAL ERROR:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Stack Trace:" -ForegroundColor DarkGray
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    
    if ($Debug) {
        Write-Host ""
        Write-Host "Full Exception:" -ForegroundColor DarkGray
        $_ | Format-List -Force
    }
    
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}
finally {
    # Cleanup
    try {
        if ($global:Services -and $global:Services.DataManager) {
            $global:Services.DataManager.SaveData()
        }
    }
    catch {
        Write-Warning "Failed to save data: $_"
    }
}
