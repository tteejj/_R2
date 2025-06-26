# New Task Screen Class Implementation
# Provides interface for creating new tasks
# AI: MVP implementation for new task screen following class-based architecture

using namespace System.Collections.Generic

# Import base classes
using module ..\components\ui-classes.psm1
using module ..\components\panel-classes.psm1
using module ..\models.psm1

# Import utilities
Import-Module "$PSScriptRoot\..\utilities\error-handling.psm1" -Force
Import-Module "$PSScriptRoot\..\utilities\event-system.psm1" -Force

class NewTaskScreen : Screen {
    # UI Components
    [BorderPanel] $MainPanel
    [ContentPanel] $FormPanel
    [BorderPanel] $NavigationPanel
    
    # Form Fields
    [string] $TaskTitle = ""
    [string] $TaskDescription = ""
    [TaskPriority] $TaskPriority = [TaskPriority]::Medium
    [string] $TaskDueDate = ""
    [string] $ProjectId = ""
    [int] $CurrentField = 0
    [int] $TotalFields = 5
    [bool] $EditingField = $false
    
    NewTaskScreen([hashtable]$services) : base("NewTaskScreen", $services) {
        Write-Log -Level Info -Message "Creating NewTaskScreen instance" -Component "NewTaskScreen"
    }
    
    [void] Initialize() {
        Invoke-WithErrorHandling -Component "NewTaskScreen" -Context "Initialize" -ScriptBlock {
            Write-Log -Level Info -Message "Initializing NewTaskScreen" -Component "NewTaskScreen"
            
            # Create main container panel
            $this.MainPanel = [BorderPanel]::new("NewTaskMain", 20, 5, 80, 20)
            $this.MainPanel.Title = "Create New Task"
            $this.MainPanel.BorderStyle = "Double"
            $this.AddPanel($this.MainPanel)
            
            # Create form panel
            $this.FormPanel = [ContentPanel]::new("NewTaskForm", 22, 7, 76, 10)
            $this.MainPanel.AddChild($this.FormPanel)
            
            # Create navigation panel
            $this.NavigationPanel = [BorderPanel]::new("NewTaskNav", 22, 18, 76, 4)
            $this.NavigationPanel.Title = "Actions"
            $this.NavigationPanel.BorderStyle = "Single"
            $this.MainPanel.AddChild($this.NavigationPanel)
            
            # Initialize navigation content
            $this.InitializeNavigation()
            
            # Update form display
            $this.UpdateFormDisplay()
            
            Write-Log -Level Info -Message "NewTaskScreen initialized successfully" -Component "NewTaskScreen"
        }
    }
    
    hidden [void] InitializeNavigation() {
        $navContent = @(
            "[↑↓] Navigate Fields    [Enter] Edit Field    [Tab] Next Field",
            "[S] Save Task          [Esc] Cancel         [C] Clear Form"
        )
        
        $navPanel = [ContentPanel]::new("NavContent", 23, 19, 74, 2)
        $navPanel.SetContent($navContent)
        $this.NavigationPanel.AddChild($navPanel)
    }
    
    hidden [void] UpdateFormDisplay() {
        $formContent = @()
        
        # Title field
        $titleIndicator = if ($this.CurrentField -eq 0) { "→" } else { " " }
        $titleValue = if ($this.EditingField -and $this.CurrentField -eq 0) { 
            $this.TaskTitle + "_" 
        } else { 
            if ([string]::IsNullOrWhiteSpace($this.TaskTitle)) { "<Enter task title>" } else { $this.TaskTitle }
        }
        $formContent += "$titleIndicator Title:       $titleValue"
        
        # Description field
        $descIndicator = if ($this.CurrentField -eq 1) { "→" } else { " " }
        $descValue = if ($this.EditingField -and $this.CurrentField -eq 1) { 
            $this.TaskDescription + "_" 
        } else { 
            if ([string]::IsNullOrWhiteSpace($this.TaskDescription)) { "<Enter description>" } else { $this.TaskDescription }
        }
        $formContent += "$descIndicator Description: $descValue"
        
        # Priority field
        $priorityIndicator = if ($this.CurrentField -eq 2) { "→" } else { " " }
        $formContent += "$priorityIndicator Priority:    $($this.TaskPriority)"
        
        # Due date field
        $dueDateIndicator = if ($this.CurrentField -eq 3) { "→" } else { " " }
        $dueDateValue = if ($this.EditingField -and $this.CurrentField -eq 3) { 
            $this.TaskDueDate + "_" 
        } else { 
            if ([string]::IsNullOrWhiteSpace($this.TaskDueDate)) { "<YYYY-MM-DD>" } else { $this.TaskDueDate }
        }
        $formContent += "$dueDateIndicator Due Date:    $dueDateValue"
        
        # Project field
        $projectIndicator = if ($this.CurrentField -eq 4) { "→" } else { " " }
        $projects = @($this.Services.DataManager.GetProjects())
        $projectDisplay = if ($this.ProjectId) {
            $proj = $projects | Where-Object { $_.Id -eq $this.ProjectId } | Select-Object -First 1
            if ($proj) { $proj.Name } else { "<None>" }
        } else { "<None>" }
        $formContent += "$projectIndicator Project:     $projectDisplay"
        
        # Add some spacing
        $formContent += ""
        $formContent += "═══════════════════════════════════════════════════════════════════════"
        
        # Validation messages
        if (-not [string]::IsNullOrWhiteSpace($this.TaskTitle)) {
            $formContent += "✓ Title is valid"
        } else {
            $formContent += "! Title is required"
        }
        
        $this.FormPanel.SetContent($formContent)
    }
    
    [void] HandleInput([ConsoleKeyInfo]$key) {
        Invoke-WithErrorHandling -Component "NewTaskScreen" -Context "HandleInput" -ScriptBlock {
            if ($this.EditingField) {
                # Handle text input for current field
                $this.HandleFieldInput($key)
            } else {
                # Handle navigation
                switch ($key.Key) {
                    ([ConsoleKey]::UpArrow) {
                        if ($this.CurrentField -gt 0) {
                            $this.CurrentField--
                            $this.UpdateFormDisplay()
                        }
                    }
                    ([ConsoleKey]::DownArrow) {
                        if ($this.CurrentField -lt ($this.TotalFields - 1)) {
                            $this.CurrentField++
                            $this.UpdateFormDisplay()
                        }
                    }
                    ([ConsoleKey]::Tab) {
                        $this.CurrentField = ($this.CurrentField + 1) % $this.TotalFields
                        $this.UpdateFormDisplay()
                    }
                    ([ConsoleKey]::Enter) {
                        if ($this.CurrentField -eq 2) {
                            # Cycle priority
                            $this.CyclePriority()
                        } elseif ($this.CurrentField -eq 4) {
                            # Cycle project
                            $this.CycleProject()
                        } else {
                            # Start editing text field
                            $this.EditingField = $true
                        }
                        $this.UpdateFormDisplay()
                    }
                    ([ConsoleKey]::Escape) {
                        # Cancel and go back
                        $this.Services.Navigation.PopScreen()
                    }
                    default {
                        # Handle character keys
                        $char = [char]$key.KeyChar
                        switch ($char.ToString().ToUpper()) {
                            'S' { 
                                # Save task
                                $this.SaveTask()
                            }
                            'C' {
                                # Clear form
                                $this.ClearForm()
                                $this.UpdateFormDisplay()
                            }
                        }
                    }
                }
            }
        }
    }
    
    hidden [void] HandleFieldInput([ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([ConsoleKey]::Enter) {
                # Stop editing
                $this.EditingField = $false
            }
            ([ConsoleKey]::Escape) {
                # Cancel editing
                $this.EditingField = $false
            }
            ([ConsoleKey]::Backspace) {
                # Remove last character
                switch ($this.CurrentField) {
                    0 { # Title
                        if ($this.TaskTitle.Length -gt 0) {
                            $this.TaskTitle = $this.TaskTitle.Substring(0, $this.TaskTitle.Length - 1)
                        }
                    }
                    1 { # Description
                        if ($this.TaskDescription.Length -gt 0) {
                            $this.TaskDescription = $this.TaskDescription.Substring(0, $this.TaskDescription.Length - 1)
                        }
                    }
                    3 { # Due date
                        if ($this.TaskDueDate.Length -gt 0) {
                            $this.TaskDueDate = $this.TaskDueDate.Substring(0, $this.TaskDueDate.Length - 1)
                        }
                    }
                }
            }
            default {
                # Add character
                if ($key.KeyChar -ge 32 -and $key.KeyChar -le 126) {
                    switch ($this.CurrentField) {
                        0 { # Title
                            if ($this.TaskTitle.Length -lt 100) {
                                $this.TaskTitle += $key.KeyChar
                            }
                        }
                        1 { # Description
                            if ($this.TaskDescription.Length -lt 500) {
                                $this.TaskDescription += $key.KeyChar
                            }
                        }
                        3 { # Due date
                            if ($this.TaskDueDate.Length -lt 10) {
                                $this.TaskDueDate += $key.KeyChar
                            }
                        }
                    }
                }
            }
        }
        
        $this.UpdateFormDisplay()
    }
    
    hidden [void] CyclePriority() {
        switch ($this.TaskPriority) {
            ([TaskPriority]::Low) { $this.TaskPriority = [TaskPriority]::Medium }
            ([TaskPriority]::Medium) { $this.TaskPriority = [TaskPriority]::High }
            ([TaskPriority]::High) { $this.TaskPriority = [TaskPriority]::Critical }
            ([TaskPriority]::Critical) { $this.TaskPriority = [TaskPriority]::Low }
        }
    }
    
    hidden [void] CycleProject() {
        $projects = @($this.Services.DataManager.GetProjects())
        if ($projects.Count -eq 0) {
            $this.ProjectId = ""
            return
        }
        
        if ([string]::IsNullOrWhiteSpace($this.ProjectId)) {
            $this.ProjectId = $projects[0].Id
        } else {
            $currentIndex = -1
            for ($i = 0; $i -lt $projects.Count; $i++) {
                if ($projects[$i].Id -eq $this.ProjectId) {
                    $currentIndex = $i
                    break
                }
            }
            
            if ($currentIndex -eq -1 -or $currentIndex -eq ($projects.Count - 1)) {
                $this.ProjectId = ""
            } else {
                $this.ProjectId = $projects[$currentIndex + 1].Id
            }
        }
    }
    
    hidden [void] SaveTask() {
        # Validate required fields
        if ([string]::IsNullOrWhiteSpace($this.TaskTitle)) {
            Write-Log -Level Warning -Message "Cannot save task without title" -Component "NewTaskScreen"
            return
        }
        
        try {
            # Create new task
            $task = [Task]::new($this.TaskTitle, $this.TaskDescription)
            $task.Priority = $this.TaskPriority
            
            # Parse and set due date
            if (-not [string]::IsNullOrWhiteSpace($this.TaskDueDate)) {
                try {
                    $task.DueDate = [DateTime]::ParseExact($this.TaskDueDate, "yyyy-MM-dd", $null)
                } catch {
                    Write-Log -Level Warning -Message "Invalid date format: $($this.TaskDueDate)" -Component "NewTaskScreen"
                }
            }
            
            # Set project
            if (-not [string]::IsNullOrWhiteSpace($this.ProjectId)) {
                $task.ProjectId = $this.ProjectId
            }
            
            # Save task
            $this.Services.DataManager.AddTask($task)
            
            Write-Log -Level Info -Message "Task created successfully: $($task.Title)" -Component "NewTaskScreen"
            
            # Navigate back
            $this.Services.Navigation.PopScreen()
        }
        catch {
            Write-Log -Level Error -Message "Failed to create task: $_" -Component "NewTaskScreen"
        }
    }
    
    hidden [void] ClearForm() {
        $this.TaskTitle = ""
        $this.TaskDescription = ""
        $this.TaskPriority = [TaskPriority]::Medium
        $this.TaskDueDate = ""
        $this.ProjectId = ""
        $this.CurrentField = 0
        $this.EditingField = $false
    }
    
    [void] Cleanup() {
        Write-Log -Level Info -Message "Cleaning up NewTaskScreen" -Component "NewTaskScreen"
        
        # Call base cleanup
        ([Screen]$this).Cleanup()
    }
}

# Export the class
Export-ModuleMember -Function * -Cmdlet * -Variable * -Alias *
