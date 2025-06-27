# PMC Terminal v5 - Class-Based Main Entry Point
# AI: New main entry point following the class-based service-oriented architecture

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Get script root directory
$script:ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Minimal console output class for MVP
class ConsoleRenderer {
    hidden [int] $LastHeight = 0
    hidden [int] $LastWidth = 0
    
    [void] Clear() {
        Clear-Host
    }
    
    [void] RenderScreen([object]$screen) {
        if ($null -eq $screen) {
            return
        }
        
        # Clear and render
        $this.Clear()
        
        # Render all panels
        foreach ($panel in $screen.Panels) {
            if ($panel.Visible) {
                Write-Host -NoNewline $panel.Render()
            }
        }
        
        # Position cursor at bottom
        [Console]::SetCursorPosition(0, [Console]::WindowHeight - 1)
    }
    
    [bool] CheckConsoleSize() {
        $currentHeight = [Console]::WindowHeight
        $currentWidth = [Console]::WindowWidth
        
        if ($currentHeight -ne $this.LastHeight -or $currentWidth -ne $this.LastWidth) {
            $this.LastHeight = $currentHeight
            $this.LastWidth = $currentWidth
            return $true
        }
        
        return $false
    }
}

# Main application class
class PMCTerminalApp {
    [hashtable] $Services
    [bool] $Running = $false
    [ConsoleRenderer] $Renderer
    
    PMCTerminalApp() {
        $this.Renderer = [ConsoleRenderer]::new()
    }
    
    [void] Initialize() {
        Write-Host "Initializing PMC Terminal v5..." -ForegroundColor Cyan
        
        # Import required modules
        $this.ImportModules()
        
        # Initialize core systems
        Write-Host "Initializing core systems..." -ForegroundColor Gray
        Initialize-ErrorHandling -LogLevel "Info"
        Initialize-EventSystem
        
        # Create services
        Write-Host "Creating services..." -ForegroundColor Gray
        $this.Services = @{}
        $this.Services.DataManager = [DataManager]::new()
        
        # Pass services to navigation service
        $this.Services.Navigation = [NavigationService]::new($this.Services)
        
        Write-Host "PMC Terminal initialized successfully!" -ForegroundColor Green
        Start-Sleep -Milliseconds 500
    }
    
    hidden [void] ImportModules() {
        Write-Host "Loading modules..." -ForegroundColor Gray
        
        $modules = @(
            @{ Name = "Error Handling"; Path = "utilities\error-handling.psm1" }
            @{ Name = "Event System"; Path = "utilities\event-system.psm1" }
            @{ Name = "Models"; Path = "models.psm1" }
            @{ Name = "UI Classes"; Path = "components\ui-classes.psm1" }
            @{ Name = "Panel Classes"; Path = "components\panel-classes.psm1" }
            @{ Name = "Table Classes"; Path = "components\table-class.psm1" }
            @{ Name = "Data Manager"; Path = "services\data-manager.psm1" }
            @{ Name = "Navigation Service"; Path = "services\navigation-service.psm1" }
            @{ Name = "Screen Factory"; Path = "services\screen-factory.psm1" }
            @{ Name = "Dashboard Screen"; Path = "screens\dashboard\dashboard-screen-class.psm1" }
            @{ Name = "Task List Screen"; Path = "screens\task-list-screen-class.psm1" }
            @{ Name = "New Task Screen"; Path = "screens\new-task-screen-class.psm1" }
        )
        
        foreach ($module in $modules) {
            $modulePath = Join-Path $script:ScriptRoot $module.Path
            
            if (Test-Path $modulePath) {
                try {
                    Import-Module $modulePath -Force -Global
                    Write-Host "  ✓ $($module.Name)" -ForegroundColor DarkGreen
                }
                catch {
                    Write-Host "  ✗ $($module.Name): $_" -ForegroundColor Red
                    throw "Failed to load required module: $($module.Name)"
                }
            }
            else {
                Write-Host "  ✗ $($module.Name): File not found" -ForegroundColor Red
                throw "Required module not found: $modulePath"
            }
        }
    }
    
    [void] Run() {
        $this.Running = $true
        
        try {
            # Load initial data
            Write-Host "`nLoading data..." -ForegroundColor Gray
            $this.Services.DataManager.LoadData()
            
            # Add some sample data if none exists
            $tasks = $this.Services.DataManager.GetTasks()
            if ($tasks.Count -eq 0) {
                Write-Host "Creating sample data..." -ForegroundColor Gray
                $this.CreateSampleData()
            }
            
            # Navigate to dashboard
            $this.Services.Navigation.PushScreen("DashboardScreen")
            
            # Main application loop
            $this.MainLoop()
        }
        catch {
            Write-Host "`nFATAL ERROR: $_" -ForegroundColor Red
            Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
            Read-Host "`nPress Enter to exit"
        }
        finally {
            # Save data before exit
            try {
                $this.Services.DataManager.SaveData()
            }
            catch {
                Write-Host "Warning: Failed to save data: $_" -ForegroundColor Yellow
            }
        }
    }
    
    hidden [void] MainLoop() {
        while ($this.Running) {
            # Get current screen
            $currentScreen = $this.Services.Navigation.GetCurrentScreen()
            
            if ($null -eq $currentScreen) {
                Write-Host "No active screen. Exiting..." -ForegroundColor Yellow
                break
            }
            
            # Render screen
            $this.Renderer.RenderScreen($currentScreen)
            
            # Handle input
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                
                # Global hotkeys
                if ($key.Key -eq [ConsoleKey]::Q -and $key.Modifiers -eq [ConsoleModifiers]::Control) {
                    if ($this.ConfirmExit()) {
                        $this.Running = $false
                        break
                    }
                }
                else {
                    # Pass to current screen
                    try {
                        $currentScreen.HandleInput($key)
                    }
                    catch {
                        Write-Log -Level Error -Message "Error handling input: $_" -Component "MainLoop"
                    }
                }
            }
            
            # Check for navigation exit request
            if ($this.Services.Navigation.GetStackDepth() -eq 0) {
                $this.Running = $false
            }
            
            # Small delay to prevent CPU spinning
            Start-Sleep -Milliseconds 50
        }
    }
    
    hidden [bool] ConfirmExit() {
        $this.Renderer.Clear()
        Write-Host "`n`n  Are you sure you want to exit PMC Terminal?" -ForegroundColor Yellow
        Write-Host "`n  Press [Y] to exit or any other key to continue" -ForegroundColor Gray
        
        $key = [Console]::ReadKey($true)
        return $key.Key -eq [ConsoleKey]::Y
    }
    
    hidden [void] CreateSampleData() {
        # Create sample project
        $project = [Project]::new("Sample Project", "This is a sample project to get you started")
        $project = $this.Services.DataManager.AddProject($project)
        
        # Create sample tasks
        $tasks = @(
            @{
                Title = "Welcome to PMC Terminal v5!"
                Description = "This is your task management system"
                Priority = [TaskPriority]::High
            },
            @{
                Title = "Press N to create a new task"
                Description = "You can create tasks from the dashboard or task list"
                Priority = [TaskPriority]::Medium
            },
            @{
                Title = "Navigate with arrow keys"
                Description = "Use arrow keys to move between tasks"
                Priority = [TaskPriority]::Medium
            },
            @{
                Title = "Press Space to toggle task completion"
                Description = "Mark tasks as completed or active"
                Priority = [TaskPriority]::Low
            }
        )
        
        foreach ($taskData in $tasks) {
            $task = [Task]::new($taskData.Title, $taskData.Description)
            $task.Priority = $taskData.Priority
            $task.ProjectId = $project.Id
            $this.Services.DataManager.AddTask($task)
        }
    }
}

# Entry point
try {
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        throw "PMC Terminal requires PowerShell 5.0 or higher"
    }
    
    # Check console
    if ($null -eq $Host.UI.RawUI) {
        throw "PMC Terminal requires an interactive console"
    }
    
    # Create and run application
    $app = [PMCTerminalApp]::new()
    $app.Initialize()
    $app.Run()
    
    Write-Host "`nThank you for using PMC Terminal v5!" -ForegroundColor Cyan
}
catch {
    Write-Host "`nStartup Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    Read-Host "`nPress Enter to exit"
    exit 1
}
