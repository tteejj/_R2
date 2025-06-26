# Task List Screen Class Implementation
# Provides task listing and management functionality
# AI: MVP implementation for task list screen following class-based architecture

using namespace System.Collections.Generic

# Import base classes
using module ..\components\ui-classes.psm1
using module ..\components\panel-classes.psm1
using module ..\components\table-class.psm1

# Import utilities
Import-Module "$PSScriptRoot\..\utilities\error-handling.psm1" -Force
Import-Module "$PSScriptRoot\..\utilities\event-system.psm1" -Force

class TaskListScreen : Screen {
    # UI Components
    [BorderPanel] $MainPanel
    [ContentPanel] $HeaderPanel
    [Table] $TaskTable
    [BorderPanel] $NavigationPanel
    
    # State
    [object[]] $Tasks = @()
    [string] $FilterStatus = "All"  # All, Active, Completed
    
    TaskListScreen([hashtable]$services) : base("TaskListScreen", $services) {
        Write-Log -Level Info -Message "Creating TaskListScreen instance" -Component "TaskListScreen"
    }
    
    [void] Initialize() {
        Invoke-WithErrorHandling -Component "TaskListScreen" -Context "Initialize" -ScriptBlock {
            Write-Log -Level Info -Message "Initializing TaskListScreen" -Component "TaskListScreen"
            
            # Create main container panel
            $this.MainPanel = [BorderPanel]::new("TaskListMain", 0, 0, 120, 30)
            $this.MainPanel.Title = "Task List"
            $this.MainPanel.BorderStyle = "Double"
            $this.AddPanel($this.MainPanel)
            
            # Create header panel
            $this.HeaderPanel = [ContentPanel]::new("TaskListHeader", 2, 2, 116, 3)
            $this.MainPanel.AddChild($this.HeaderPanel)
            
            # Create task table
            $this.TaskTable = [Table]::new("TaskTable")
            $this.TaskTable.SetColumns(@(
                [TableColumn]::new("Title", "Task Title", 50),
                [TableColumn]::new("Status", "Status", 15),
                [TableColumn]::new("Priority", "Priority", 12),
                [TableColumn]::new("DueDate", "Due Date", 15),
                [TableColumn]::new("Project", "Project", 20)
            ))
            
            # Position table panel
            $tablePanel = [ContentPanel]::new("TableContainer", 2, 6, 116, 18)
            $this.MainPanel.AddChild($tablePanel)
            
            # Create navigation panel
            $this.NavigationPanel = [BorderPanel]::new("TaskListNav", 2, 25, 116, 4)
            $this.NavigationPanel.Title = "Actions"
            $this.NavigationPanel.BorderStyle = "Single"
            $this.MainPanel.AddChild($this.NavigationPanel)
            
            # Initialize navigation content
            $this.InitializeNavigation()
            
            # Subscribe to events
            $this.SubscribeToEvents()
            
            # Load initial data
            $this.RefreshData()
            
            Write-Log -Level Info -Message "TaskListScreen initialized successfully" -Component "TaskListScreen"
        }
    }
    
    hidden [void] InitializeNavigation() {
        $navContent = @(
            "[N] New Task    [E] Edit Task    [D] Delete Task    [Space] Toggle Complete",
            "[F] Filter: $($this.FilterStatus)    [S] Sort    [R] Refresh    [Esc] Back to Dashboard"
        )
        
        $navPanel = [ContentPanel]::new("NavContent", 3, 26, 114, 2)
        $navPanel.SetContent($navContent)
        $this.NavigationPanel.AddChild($navPanel)
    }
    
    hidden [void] SubscribeToEvents() {
        # Subscribe to task changes
        $this.SubscribeToEvent("Tasks.Changed", {
            param($eventArgs)
            $this.RefreshData()
        })
        
        Write-Log -Level Debug -Message "TaskListScreen subscribed to events" -Component "TaskListScreen"
    }
    
    hidden [void] RefreshData() {
        Invoke-WithErrorHandling -Component "TaskListScreen" -Context "RefreshData" -ScriptBlock {
            Write-Log -Level Debug -Message "Refreshing task list data" -Component "TaskListScreen"
            
            # Get data from services
            if ($null -ne $this.Services -and $null -ne $this.Services.DataManager) {
                $allTasks = @($this.Services.DataManager.GetTasks())
                
                # Apply filter
                switch ($this.FilterStatus) {
                    "Active" {
                        $this.Tasks = @($allTasks | Where-Object { $_.Status -eq "Active" })
                    }
                    "Completed" {
                        $this.Tasks = @($allTasks | Where-Object { $_.Status -eq "Completed" })
                    }
                    default {
                        $this.Tasks = $allTasks
                    }
                }
                
                # Update header
                $this.UpdateHeader()
                
                # Update table data
                $this.UpdateTaskTable()
                
                # Update navigation
                $this.InitializeNavigation()
            } else {
                Write-Log -Level Warning -Message "DataManager service not available" -Component "TaskListScreen"
            }
        }
    }
    
    hidden [void] UpdateHeader() {
        $totalCount = $this.Tasks.Count
        $activeCount = @($this.Tasks | Where-Object { $_.Status -eq "Active" }).Count
        
        $headerContent = @(
            "═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════",
            "  Showing: $($this.FilterStatus) Tasks  |  Total: $totalCount  |  Active: $activeCount  |  Completed: $($totalCount - $activeCount)",
            "═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        )
        
        $this.HeaderPanel.SetContent($headerContent)
    }
    
    hidden [void] UpdateTaskTable() {
        # Prepare data for table
        $tableData = @()
        
        foreach ($task in $this.Tasks) {
            $project = if ($task.ProjectId) {
                $proj = $this.Services.DataManager.GetProject($task.ProjectId)
                if ($proj) { $proj.Name } else { "" }
            } else { "" }
            
            $tableData += @{
                Title = $task.Title
                Status = $task.Status
                Priority = $task.Priority
                DueDate = if ($task.DueDate) { $task.DueDate.ToString("yyyy-MM-dd") } else { "" }
                Project = $project
                _Task = $task  # Store reference to original task
            }
        }
        
        $this.TaskTable.SetData($tableData)
    }
    
    [void] HandleInput([ConsoleKeyInfo]$key) {
        Invoke-WithErrorHandling -Component "TaskListScreen" -Context "HandleInput" -ScriptBlock {
            switch ($key.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($this.TaskTable.SelectedIndex -gt 0) {
                        $this.TaskTable.SelectedIndex--
                        $this.UpdateTaskTable()
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this.TaskTable.SelectedIndex -lt ($this.TaskTable.Data.Count - 1)) {
                        $this.TaskTable.SelectedIndex++
                        $this.UpdateTaskTable()
                    }
                }
                ([ConsoleKey]::Spacebar) {
                    # Toggle task complete
                    if ($this.TaskTable.Data.Count -gt 0 -and $this.TaskTable.SelectedIndex -ge 0) {
                        $selectedData = $this.TaskTable.Data[$this.TaskTable.SelectedIndex]
                        $task = $selectedData._Task
                        
                        if ($task.Status -eq "Completed") {
                            $task.Status = "Active"
                            $task.CompletedDate = $null
                        } else {
                            $task.Complete()
                        }
                        
                        $this.Services.DataManager.UpdateTask($task)
                    }
                }
                ([ConsoleKey]::Escape) {
                    # Go back to dashboard
                    $this.Services.Navigation.PopScreen()
                }
                default {
                    # Handle character keys
                    $char = [char]$key.KeyChar
                    switch ($char.ToString().ToUpper()) {
                        'N' { 
                            # Navigate to new task screen
                            $this.Services.Navigation.PushScreen("NewTaskScreen") 
                        }
                        'E' { 
                            # Edit selected task
                            if ($this.TaskTable.Data.Count -gt 0 -and $this.TaskTable.SelectedIndex -ge 0) {
                                $selectedData = $this.TaskTable.Data[$this.TaskTable.SelectedIndex]
                                $task = $selectedData._Task
                                $this.Services.Navigation.PushScreen("EditTaskScreen", @{TaskId = $task.Id})
                            }
                        }
                        'D' { 
                            # Delete selected task
                            if ($this.TaskTable.Data.Count -gt 0 -and $this.TaskTable.SelectedIndex -ge 0) {
                                $selectedData = $this.TaskTable.Data[$this.TaskTable.SelectedIndex]
                                $task = $selectedData._Task
                                $this.Services.DataManager.DeleteTask($task.Id)
                            }
                        }
                        'F' {
                            # Cycle through filters
                            switch ($this.FilterStatus) {
                                "All" { $this.FilterStatus = "Active" }
                                "Active" { $this.FilterStatus = "Completed" }
                                "Completed" { $this.FilterStatus = "All" }
                            }
                            $this.RefreshData()
                        }
                        'R' { 
                            # Refresh
                            $this.RefreshData() 
                        }
                    }
                }
            }
        }
    }
    
    [void] Cleanup() {
        Write-Log -Level Info -Message "Cleaning up TaskListScreen" -Component "TaskListScreen"
        
        # Call base cleanup
        ([Screen]$this).Cleanup()
    }
}

# Export the class
Export-ModuleMember -Function * -Cmdlet * -Variable * -Alias *
