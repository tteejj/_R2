# Data Models Module for PMC Terminal v5
# Defines core business entity classes (Task, Project, etc.)
# AI: Implements strict data contracts as per architectural principle #4

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Import utilities
Import-Module -Name "$PSScriptRoot\utilities\error-handling.psm1" -Force

# TaskPriority Enum
enum TaskPriority {
    Low = 1
    Medium = 2
    High = 3
    Critical = 4
}

# TaskStatus Enum
enum TaskStatus {
    Active
    Completed
    Cancelled
    OnHold
    Overdue
}

# Task Class - Represents a single task
class Task {
    [string] $Id
    [string] $Title
    [string] $Description
    [TaskStatus] $Status
    [TaskPriority] $Priority
    [DateTime] $CreatedDate
    [DateTime] $ModifiedDate
    [Nullable[DateTime]] $DueDate
    [Nullable[DateTime]] $CompletedDate
    [string] $ProjectId
    [string[]] $Tags
    [hashtable] $CustomFields
    [string] $AssignedTo
    [int] $EstimatedHours
    [int] $ActualHours
    
    # Default constructor
    Task() {
        $this.Id = [Guid]::NewGuid().ToString()
        $this.CreatedDate = [DateTime]::Now
        $this.ModifiedDate = [DateTime]::Now
        $this.Status = [TaskStatus]::Active
        $this.Priority = [TaskPriority]::Medium
        $this.Tags = @()
        $this.CustomFields = @{}
        $this.EstimatedHours = 0
        $this.ActualHours = 0
    }
    
    # Constructor with title
    Task([string]$title) : base() {
        if ([string]::IsNullOrWhiteSpace($title)) {
            throw [System.ArgumentException]::new("Task title cannot be null or empty")
        }
        $this.Title = $title
    }
    
    # Constructor with title and description
    Task([string]$title, [string]$description) : base() {
        if ([string]::IsNullOrWhiteSpace($title)) {
            throw [System.ArgumentException]::new("Task title cannot be null or empty")
        }
        $this.Title = $title
        $this.Description = $description
    }
    
    # Mark task as completed
    [void] Complete() {
        if ($this.Status -eq [TaskStatus]::Completed) {
            Write-Log -Level Warning -Message "Task '$($this.Title)' is already completed" -Component "Task"
            return
        }
        
        $this.Status = [TaskStatus]::Completed
        $this.CompletedDate = [DateTime]::Now
        $this.ModifiedDate = [DateTime]::Now
        
        Write-Log -Level Info -Message "Task completed: $($this.Title)" -Component "Task"
    }
    
    # Check if task is overdue
    [bool] IsOverdue() {
        if ($null -eq $this.DueDate) {
            return $false
        }
        
        if ($this.Status -in @([TaskStatus]::Completed, [TaskStatus]::Cancelled)) {
            return $false
        }
        
        return $this.DueDate.Value -lt [DateTime]::Now
    }
    
    # Add a tag to the task
    [void] AddTag([string]$tag) {
        if ([string]::IsNullOrWhiteSpace($tag)) {
            throw [System.ArgumentException]::new("Tag cannot be null or empty")
        }
        
        if ($this.Tags -notcontains $tag) {
            $this.Tags += $tag
            $this.ModifiedDate = [DateTime]::Now
        }
    }
    
    # Remove a tag from the task
    [void] RemoveTag([string]$tag) {
        $this.Tags = $this.Tags | Where-Object { $_ -ne $tag }
        $this.ModifiedDate = [DateTime]::Now
    }
    
    # Update task
    [void] Update() {
        $this.ModifiedDate = [DateTime]::Now
    }
    
    # Validate task data
    [bool] Validate() {
        $errors = @()
        
        if ([string]::IsNullOrWhiteSpace($this.Title)) {
            $errors += "Title is required"
        }
        
        if ($this.Title.Length -gt 200) {
            $errors += "Title cannot exceed 200 characters"
        }
        
        if ($null -ne $this.DueDate -and $null -ne $this.CompletedDate) {
            if ($this.CompletedDate.Value -gt $this.DueDate.Value) {
                # This is just a warning, not an error
                Write-Log -Level Warning -Message "Task completed after due date" -Component "Task"
            }
        }
        
        if ($errors.Count -gt 0) {
            Write-Log -Level Error -Message "Task validation failed: $($errors -join ', ')" -Component "Task"
            return $false
        }
        
        return $true
    }
    
    # Clone the task
    [Task] Clone() {
        $clone = [Task]::new($this.Title, $this.Description)
        
        # Copy all properties except Id and dates
        $clone.Status = $this.Status
        $clone.Priority = $this.Priority
        $clone.DueDate = $this.DueDate
        $clone.ProjectId = $this.ProjectId
        $clone.Tags = @($this.Tags)  # Create a copy of the array
        $clone.CustomFields = $this.CustomFields.Clone()
        $clone.AssignedTo = $this.AssignedTo
        $clone.EstimatedHours = $this.EstimatedHours
        
        return $clone
    }
    
    # Convert to string representation
    [string] ToString() {
        return "$($this.Title) [$($this.Status)] Priority: $($this.Priority)"
    }
}

# ProjectStatus Enum
enum ProjectStatus {
    Planning
    Active
    OnHold
    Completed
    Cancelled
}

# Project Class - Represents a project containing tasks
class Project {
    [string] $Id
    [string] $Name
    [string] $Description
    [ProjectStatus] $Status
    [DateTime] $CreatedDate
    [DateTime] $ModifiedDate
    [Nullable[DateTime]] $StartDate
    [Nullable[DateTime]] $EndDate
    [string] $Owner
    [string[]] $Members
    [hashtable] $CustomFields
    [string] $Category
    [int] $TaskCount
    [int] $CompletedTaskCount
    
    # Default constructor
    Project() {
        $this.Id = [Guid]::NewGuid().ToString()
        $this.CreatedDate = [DateTime]::Now
        $this.ModifiedDate = [DateTime]::Now
        $this.Status = [ProjectStatus]::Planning
        $this.Members = @()
        $this.CustomFields = @{}
        $this.TaskCount = 0
        $this.CompletedTaskCount = 0
    }
    
    # Constructor with name
    Project([string]$name) : base() {
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw [System.ArgumentException]::new("Project name cannot be null or empty")
        }
        $this.Name = $name
    }
    
    # Constructor with name and description
    Project([string]$name, [string]$description) : base() {
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw [System.ArgumentException]::new("Project name cannot be null or empty")
        }
        $this.Name = $name
        $this.Description = $description
    }
    
    # Add a member to the project
    [void] AddMember([string]$member) {
        if ([string]::IsNullOrWhiteSpace($member)) {
            throw [System.ArgumentException]::new("Member name cannot be null or empty")
        }
        
        if ($this.Members -notcontains $member) {
            $this.Members += $member
            $this.ModifiedDate = [DateTime]::Now
        }
    }
    
    # Remove a member from the project
    [void] RemoveMember([string]$member) {
        $this.Members = $this.Members | Where-Object { $_ -ne $member }
        $this.ModifiedDate = [DateTime]::Now
    }
    
    # Calculate project completion percentage
    [double] GetCompletionPercentage() {
        if ($this.TaskCount -eq 0) {
            return 0.0
        }
        
        return [Math]::Round(($this.CompletedTaskCount / $this.TaskCount) * 100, 2)
    }
    
    # Check if project is overdue
    [bool] IsOverdue() {
        if ($null -eq $this.EndDate) {
            return $false
        }
        
        if ($this.Status -in @([ProjectStatus]::Completed, [ProjectStatus]::Cancelled)) {
            return $false
        }
        
        return $this.EndDate.Value -lt [DateTime]::Now
    }
    
    # Update task statistics
    [void] UpdateTaskStatistics([int]$totalTasks, [int]$completedTasks) {
        if ($totalTasks -lt 0 -or $completedTasks -lt 0) {
            throw [System.ArgumentException]::new("Task counts cannot be negative")
        }
        
        if ($completedTasks -gt $totalTasks) {
            throw [System.ArgumentException]::new("Completed tasks cannot exceed total tasks")
        }
        
        $this.TaskCount = $totalTasks
        $this.CompletedTaskCount = $completedTasks
        $this.ModifiedDate = [DateTime]::Now
    }
    
    # Validate project data
    [bool] Validate() {
        $errors = @()
        
        if ([string]::IsNullOrWhiteSpace($this.Name)) {
            $errors += "Name is required"
        }
        
        if ($this.Name.Length -gt 100) {
            $errors += "Name cannot exceed 100 characters"
        }
        
        if ($null -ne $this.StartDate -and $null -ne $this.EndDate) {
            if ($this.StartDate.Value -gt $this.EndDate.Value) {
                $errors += "Start date cannot be after end date"
            }
        }
        
        if ($errors.Count -gt 0) {
            Write-Log -Level Error -Message "Project validation failed: $($errors -join ', ')" -Component "Project"
            return $false
        }
        
        return $true
    }
    
    # Convert to string representation
    [string] ToString() {
        return "$($this.Name) [$($this.Status)] - $($this.GetCompletionPercentage())% Complete"
    }
}

# Settings Class - Application settings
class Settings {
    [string] $Theme
    [bool] $ShowCompletedTasks
    [bool] $ShowProjectPanel
    [int] $AutoSaveIntervalMinutes
    [string] $DefaultView
    [hashtable] $KeyBindings
    [string[]] $RecentProjects
    [int] $MaxRecentProjects
    [bool] $EnableNotifications
    [string] $DateFormat
    [string] $TimeFormat
    
    # Default constructor
    Settings() {
        $this.Theme = "Default"
        $this.ShowCompletedTasks = $false
        $this.ShowProjectPanel = $true
        $this.AutoSaveIntervalMinutes = 5
        $this.DefaultView = "Dashboard"
        $this.KeyBindings = @{}
        $this.RecentProjects = @()
        $this.MaxRecentProjects = 10
        $this.EnableNotifications = $true
        $this.DateFormat = "yyyy-MM-dd"
        $this.TimeFormat = "HH:mm:ss"
        
        # Default key bindings
        $this.InitializeDefaultKeyBindings()
    }
    
    # Initialize default key bindings
    hidden [void] InitializeDefaultKeyBindings() {
        $this.KeyBindings = @{
            "NewTask" = "N"
            "EditTask" = "E"
            "DeleteTask" = "D"
            "CompleteTask" = "C"
            "FilterTasks" = "F"
            "Search" = "S"
            "Quit" = "Q"
            "Help" = "H"
            "Refresh" = "R"
        }
    }
    
    # Add recent project
    [void] AddRecentProject([string]$projectId) {
        if ([string]::IsNullOrWhiteSpace($projectId)) {
            return
        }
        
        # Remove if already exists
        $this.RecentProjects = $this.RecentProjects | Where-Object { $_ -ne $projectId }
        
        # Add to beginning
        $this.RecentProjects = @($projectId) + $this.RecentProjects
        
        # Trim to max size
        if ($this.RecentProjects.Count -gt $this.MaxRecentProjects) {
            $this.RecentProjects = $this.RecentProjects[0..($this.MaxRecentProjects - 1)]
        }
    }
    
    # Validate settings
    [bool] Validate() {
        $errors = @()
        
        if ($this.AutoSaveIntervalMinutes -lt 1 -or $this.AutoSaveIntervalMinutes -gt 60) {
            $errors += "AutoSave interval must be between 1 and 60 minutes"
        }
        
        if ($this.MaxRecentProjects -lt 1 -or $this.MaxRecentProjects -gt 50) {
            $errors += "Max recent projects must be between 1 and 50"
        }
        
        if ($errors.Count -gt 0) {
            Write-Log -Level Error -Message "Settings validation failed: $($errors -join ', ')" -Component "Settings"
            return $false
        }
        
        return $true
    }
}

# Export all classes and enums
Export-ModuleMember -Function * -Cmdlet * -Variable * -Alias *