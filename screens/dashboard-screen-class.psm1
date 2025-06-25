# Dashboard Screen Class Module for PMC Terminal v5
# Implements the main dashboard screen with task summary and navigation
# AI: Implements Phase 3.1 of the class migration plan - Dashboard Screen

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Import base classes
using module '..\components\ui-classes.psm1'
using module '..\layout\panels-class.psm1'
using module '..\components\table-class.psm1'
using module '..\components\navigation-class.psm1'

# Import utilities for error handling
Import-Module -Name "$PSScriptRoot\..\utilities\error-handling.psm1" -Force

# DashboardScreen - Main application screen
class DashboardScreen : Screen {
    # UI Components
    [BorderPanel] $MainPanel
    [ContentPanel] $SummaryPanel
    [Table] $TaskTable
    [NavigationMenu] $NavMenu
    [BorderPanel] $StatusPanel
    
    # Screen state
    [hashtable] $TaskSummary = @{
        Total = 0
        Active = 0
        Completed = 0
        Overdue = 0
    }
    
    DashboardScreen([hashtable]$services) : base("DashboardScreen", $services) {
    }
    
    [void] Initialize() {
        try {
            Write-Log -Level Info -Message "Initializing Dashboard Screen" -Component $this.Name
            
            # Create main container panel
            $this.MainPanel = [BorderPanel]::new("MainPanel", 0, 0, 120, 30)
            $this.MainPanel.Title = "PMC Terminal v5 - Dashboard"
            $this.MainPanel.BorderStyle = "Double"
            $this.MainPanel.TitleColor = [ConsoleColor]::Cyan
            $this.AddPanel($this.MainPanel)
            
            # Create summary panel (top-left)
            $this.SummaryPanel = [ContentPanel]::new("SummaryPanel", 2, 2, 40, 10)
            $this.MainPanel.AddChild($this.SummaryPanel)
            
            # Create task table panel with border
            $tablePanel = [BorderPanel]::new("TablePanel", 44, 2, 74, 20)
            $tablePanel.Title = "Active Tasks"
            $tablePanel.BorderStyle = "Single"
            $this.MainPanel.AddChild($tablePanel)
            
            # Create task table
            $this.TaskTable = [Table]::new("TaskTable")
            $this.TaskTable.ShowHeaders = $true
            $this.TaskTable.MaxVisibleRows = 17  # Account for border
            $this.SetupTaskTableColumns()
            $tablePanel.AddChild($this.TaskTable)
            
            # Create status panel (bottom)
            $this.StatusPanel = [BorderPanel]::new("StatusPanel", 2, 23, 116, 5)
            $this.StatusPanel.Title = "Navigation"
            $this.StatusPanel.BorderStyle = "Single"
            $this.MainPanel.AddChild($this.StatusPanel)
            
            # Create navigation menu
            $this.NavMenu = [NavigationMenu]::new("NavMenu", $this.Services)
            $this.NavMenu.Orientation = "Horizontal"
            $this.SetupNavigation()
            $this.StatusPanel.AddChild($this.NavMenu)
            
            # Subscribe to events
            $this.SubscribeToEvents()
            
            # Initial data load
            $this.RefreshData()
            
            # Call base initialization
            ([Screen]$this).Initialize()
            
        }
        catch {
            Write-Log -Level Error -Message "Failed to initialize DashboardScreen: $_" -Component $this.Name
            throw
        }
    }
    
    hidden [void] SetupTaskTableColumns() {
        $columns = @(
            [TableColumn]::new("Title", "Task Title", 35),
            [TableColumn]::new("Status", "Status", 12),
            [TableColumn]::new("Priority", "Priority", 10),
            [TableColumn]::new("DueDate", "Due Date", 12)
        )
        
        # Set column formatters
        $columns[1].Formatter = {
            param($value)
            switch ($value) {
                "Active" { return $value }
                "Completed" { return "✓ $value" }
                "Overdue" { return "! $value" }
                default { return $value }
            }
        }
        
        $columns[2].Alignment = "Center"
        $columns[2].Formatter = {
            param($value)
            switch ($value) {
                "High" { return "★★★" }
                "Medium" { return "★★" }
                "Low" { return "★" }
                default { return $value }
            }
        }
        
        $columns[3].Formatter = {
            param($value)
            if ($null -eq $value) { return "N/A" }
            if ($value -is [DateTime]) {
                return $value.ToString("yyyy-MM-dd")
            }
            return $value.ToString()
        }
        
        $this.TaskTable.SetColumns($columns)
    }
    
    hidden [void] SetupNavigation() {
        # Build context-aware navigation menu
        $this.NavMenu.BuildContextMenu("Dashboard")
        
        # Add additional dashboard-specific items
        $refreshItem = [NavigationItem]::new("R", "Refresh", {
            Write-Log -Level Debug -Message "Refreshing dashboard data" -Component "DashboardScreen"
            $this.RefreshData()
        })
        $refreshItem.Description = "Refresh task data"
        $this.NavMenu.AddItem($refreshItem)
        
        # Add filter toggle
        $filterItem = [NavigationItem]::new("F", "Filter", {
            $currentFilter = $this.State["Filter"]
            if ($null -eq $currentFilter -or $currentFilter -eq "All") {
                $this.State["Filter"] = "Active"
            }
            else {
                $this.State["Filter"] = "All"
            }
            $this.RefreshData()
        })
        $filterItem.Description = "Toggle task filter"
        $this.NavMenu.AddItem($filterItem)
    }
    
    hidden [void] SubscribeToEvents() {
        # Subscribe to task data changes
        $this.SubscribeToEvent("Tasks.Changed", {
            Write-Log -Level Debug -Message "Tasks changed event received" -Component "DashboardScreen"
            $this.RefreshData()
        })
        
        # Subscribe to project changes
        $this.SubscribeToEvent("Projects.Changed", {
            Write-Log -Level Debug -Message "Projects changed event received" -Component "DashboardScreen"
            $this.RefreshData()
        })
    }
    
    hidden [void] RefreshData() {
        try {
            # Get current filter
            $filter = $this.State["Filter"]
            if ($null -eq $filter) { $filter = "Active" }
            
            # Get tasks from data manager
            $allTasks = $this.Services.DataManager.GetTasks()
            
            # Apply filter
            $filteredTasks = switch ($filter) {
                "Active" { $allTasks | Where-Object { $_.Status -eq "Active" } }
                "Completed" { $allTasks | Where-Object { $_.Status -eq "Completed" } }
                "All" { $allTasks }
                default { $allTasks }
            }
            
            # Update task table
            $this.TaskTable.SetData($filteredTasks)
            
            # Update summary statistics
            $this.UpdateSummary($allTasks)
            
            # Update status panel title
            $this.StatusPanel.Title = "Navigation - Filter: $filter"
            
        }
        catch {
            Write-Log -Level Error -Message "Failed to refresh dashboard data: $_" -Component $this.Name
        }
    }
    
    hidden [void] UpdateSummary([object[]]$tasks) {
        # Calculate summary statistics
        $this.TaskSummary.Total = $tasks.Count
        $this.TaskSummary.Active = ($tasks | Where-Object { $_.Status -eq "Active" }).Count
        $this.TaskSummary.Completed = ($tasks | Where-Object { $_.Status -eq "Completed" }).Count
        $this.TaskSummary.Overdue = ($tasks | Where-Object { 
            $_.Status -eq "Active" -and 
            $null -ne $_.DueDate -and 
            $_.DueDate -lt [DateTime]::Now 
        }).Count
        
        # Format summary content
        $summaryContent = @(
            "╔════════════════════════════════════╗",
            "║         TASK SUMMARY               ║",
            "╠════════════════════════════════════╣",
            "║                                    ║",
            "║  Total Tasks:      $($this.TaskSummary.Total.ToString().PadLeft(4))            ║",
            "║  Active:           $($this.TaskSummary.Active.ToString().PadLeft(4))            ║",
            "║  Completed:        $($this.TaskSummary.Completed.ToString().PadLeft(4))            ║",
            "║  Overdue:          $($this.TaskSummary.Overdue.ToString().PadLeft(4))            ║",
            "║                                    ║",
            "╚════════════════════════════════════╝"
        )
        
        $this.SummaryPanel.SetContent($summaryContent)
    }
    
    [void] HandleInput([ConsoleKeyInfo]$key) {
        if ($null -eq $key) {
            return
        }
        
        # Let navigation menu handle letter keys first
        if ($key.KeyChar -match '[A-Za-z]') {
            $this.NavMenu.ExecuteAction($key.KeyChar.ToString())
            return
        }
        
        # Handle arrow keys for table navigation
        switch ($key.Key) {
            ([ConsoleKey]::UpArrow) {
                $this.TaskTable.SelectPrevious()
            }
            ([ConsoleKey]::DownArrow) {
                $this.TaskTable.SelectNext()
            }
            ([ConsoleKey]::Home) {
                $this.TaskTable.SelectFirst()
            }
            ([ConsoleKey]::End) {
                $this.TaskTable.SelectLast()
            }
            ([ConsoleKey]::Enter) {
                # Open selected task for editing
                $selectedTask = $this.TaskTable.GetSelectedItem()
                if ($null -ne $selectedTask) {
                    $this.Services.Navigation.PushScreen("EditTaskScreen", @{
                        TaskId = $selectedTask.Id
                    })
                }
            }
            ([ConsoleKey]::Delete) {
                # Delete selected task (with confirmation)
                $selectedTask = $this.TaskTable.GetSelectedItem()
                if ($null -ne $selectedTask) {
                    # AI: In a real implementation, show confirmation dialog
                    Write-Log -Level Info -Message "Delete task requested: $($selectedTask.Title)" -Component $this.Name
                }
            }
        }
    }
    
    [string] Render() {
        return Invoke-WithErrorHandling -Component "DashboardScreen" -Context "Render" -ScriptBlock {
            # Clear screen first
            $output = [System.Text.StringBuilder]::new()
            [void]$output.Append("`e[2J`e[H")  # Clear screen and move to home
            
            # Render main panel (which includes all children)
            [void]$output.Append($this.MainPanel.Render())
            
            # Add last update timestamp
            $timestamp = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
            [void]$output.Append("`e[29;90H")  # Position at bottom right
            [void]$output.Append("`e[90m")     # Dark gray color
            [void]$output.Append("Last Update: $timestamp")
            [void]$output.Append("`e[0m")      # Reset color
            
            return $output.ToString()
        }
    }
    
    [void] Cleanup() {
        Write-Log -Level Info -Message "Cleaning up Dashboard Screen" -Component $this.Name
        
        # Call base cleanup first
        ([Screen]$this).Cleanup()
        
        # Additional cleanup if needed
        $this.TaskTable = $null
        $this.NavMenu = $null
    }
}

# Export all classes
Export-ModuleMember -Function * -Cmdlet * -Variable * -Alias *