# Data Manager Service Module for PMC Terminal v5
# Manages global data state and provides CRUD operations
# AI: Implements the single source of truth for application data ($global:Data)

using module '..\models.psm1'

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Import dependencies

Import-Module -Name "$PSScriptRoot\..\utilities\error-handling.psm1" -Force
Import-Module -Name "$PSScriptRoot\..\utilities\event-system.psm1" -Force

# DataManager Class - Central data management service
class DataManager {
    hidden [hashtable] $DataStore
    hidden [string] $DataFilePath
    hidden [bool] $AutoSaveEnabled = $true
    hidden [System.Timers.Timer] $AutoSaveTimer
    
    # Constructor
    DataManager() {
        $this.InitializeDataStore()
        $this.DataFilePath = Join-Path -Path $env:APPDATA -ChildPath "PMCTerminal\data.json"
        
        Write-Log -Level Info -Message "DataManager initialized" -Component "DataManager"
    }
    
    # Initialize the global data store
    hidden [void] InitializeDataStore() {
        # AI: Using $global:Data as specified in architectural principles
        if ($null -eq $global:Data) {
            $global:Data = @{
                Tasks = @{}
                Projects = @{}
                Settings = [Settings]::new()
                Metadata = @{
                    Version = "5.0.0"
                    LastSaved = [DateTime]::Now
                    DataFormatVersion = 1
                }
            }
            Write-Log -Level Info -Message "Initialized global data store" -Component "DataManager"
        }
        
        $this.DataStore = $global:Data
    }
    
    # Get all tasks
    [Task[]] GetTasks() {
        return Invoke-WithErrorHandling -Component "DataManager" -Context "GetTasks" -ScriptBlock {
            $tasks = @()
            foreach ($taskId in $this.DataStore.Tasks.Keys) {
                $tasks += $this.DataStore.Tasks[$taskId]
            }
            return $tasks | Sort-Object -Property CreatedDate
        }
    }
    
    # Get tasks by project
    [Task[]] GetTasksByProject([string]$projectId) {
        if ([string]::IsNullOrWhiteSpace($projectId)) {
            throw [System.ArgumentException]::new("Project ID cannot be null or empty")
        }
        
        return $this.GetTasks() | Where-Object { $_.ProjectId -eq $projectId }
    }
    
    # Get task by ID
    [Task] GetTask([string]$taskId) {
        if ([string]::IsNullOrWhiteSpace($taskId)) {
            throw [System.ArgumentException]::new("Task ID cannot be null or empty")
        }
        
        if ($this.DataStore.Tasks.ContainsKey($taskId)) {
            return $this.DataStore.Tasks[$taskId]
        }
        
        return $null
    }
    
    # Add a new task
    [Task] AddTask([Task]$task) {
        return Invoke-WithErrorHandling -Component "DataManager" -Context "AddTask" -ScriptBlock {
            if ($null -eq $task) {
                throw [System.ArgumentNullException]::new("task", "Task cannot be null")
            }
            
            # Validate task
            if (-not $task.Validate()) {
                throw [System.InvalidOperationException]::new("Task validation failed")
            }
            
            # Check for duplicate ID
            if ($this.DataStore.Tasks.ContainsKey($task.Id)) {
                throw [System.InvalidOperationException]::new("Task with ID '$($task.Id)' already exists")
            }
            
            # Add to store
            $this.DataStore.Tasks[$task.Id] = $task
            
            # Update project statistics if task belongs to a project
            if (-not [string]::IsNullOrWhiteSpace($task.ProjectId)) {
                $this.UpdateProjectStatistics($task.ProjectId)
            }
            
            Write-Log -Level Info -Message "Added task: $($task.Title)" -Component "DataManager"
            
            # Publish event
            Publish-Event -EventName "Tasks.Changed" -Data @{
                Action = "Add"
                TaskId = $task.Id
                Task = $task
            }
            
            # Trigger auto-save
            $this.ScheduleAutoSave()
            
            return $task
        }
    }
    
    # Update an existing task
    [Task] UpdateTask([Task]$task) {
        return Invoke-WithErrorHandling -Component "DataManager" -Context "UpdateTask" -ScriptBlock {
            if ($null -eq $task) {
                throw [System.ArgumentNullException]::new("task", "Task cannot be null")
            }
            
            # Check if task exists
            if (-not $this.DataStore.Tasks.ContainsKey($task.Id)) {
                throw [System.InvalidOperationException]::new("Task with ID '$($task.Id)' not found")
            }
            
            # Validate task
            if (-not $task.Validate()) {
                throw [System.InvalidOperationException]::new("Task validation failed")
            }
            
            # Get old task for comparison
            $oldTask = $this.DataStore.Tasks[$task.Id]
            $oldProjectId = $oldTask.ProjectId
            
            # Update task
            $task.ModifiedDate = [DateTime]::Now
            $this.DataStore.Tasks[$task.Id] = $task
            
            # Update project statistics
            if ($oldProjectId -ne $task.ProjectId) {
                # Task moved between projects
                if (-not [string]::IsNullOrWhiteSpace($oldProjectId)) {
                    $this.UpdateProjectStatistics($oldProjectId)
                }
                if (-not [string]::IsNullOrWhiteSpace($task.ProjectId)) {
                    $this.UpdateProjectStatistics($task.ProjectId)
                }
            }
            elseif (-not [string]::IsNullOrWhiteSpace($task.ProjectId)) {
                # Task status might have changed
                $this.UpdateProjectStatistics($task.ProjectId)
            }
            
            Write-Log -Level Info -Message "Updated task: $($task.Title)" -Component "DataManager"
            
            # Publish event
            Publish-Event -EventName "Tasks.Changed" -Data @{
                Action = "Update"
                TaskId = $task.Id
                Task = $task
                OldTask = $oldTask
            }
            
            # Trigger auto-save
            $this.ScheduleAutoSave()
            
            return $task
        }
    }
    
    # Delete a task
    [void] DeleteTask([string]$taskId) {
        Invoke-WithErrorHandling -Component "DataManager" -Context "DeleteTask" -ScriptBlock {
            if ([string]::IsNullOrWhiteSpace($taskId)) {
                throw [System.ArgumentException]::new("Task ID cannot be null or empty")
            }
            
            # Check if task exists
            if (-not $this.DataStore.Tasks.ContainsKey($taskId)) {
                throw [System.InvalidOperationException]::new("Task with ID '$taskId' not found")
            }
            
            # Get task for event data
            $task = $this.DataStore.Tasks[$taskId]
            $projectId = $task.ProjectId
            
            # Remove task
            $this.DataStore.Tasks.Remove($taskId)
            
            # Update project statistics
            if (-not [string]::IsNullOrWhiteSpace($projectId)) {
                $this.UpdateProjectStatistics($projectId)
            }
            
            Write-Log -Level Info -Message "Deleted task: $($task.Title)" -Component "DataManager"
            
            # Publish event
            Publish-Event -EventName "Tasks.Changed" -Data @{
                Action = "Delete"
                TaskId = $taskId
                Task = $task
            }
            
            # Trigger auto-save
            $this.ScheduleAutoSave()
        }
    }
    
    # Get all projects
    [Project[]] GetProjects() {
        return Invoke-WithErrorHandling -Component "DataManager" -Context "GetProjects" -ScriptBlock {
            $projects = @()
            foreach ($projectId in $this.DataStore.Projects.Keys) {
                $projects += $this.DataStore.Projects[$projectId]
            }
            return $projects | Sort-Object -Property Name
        }
    }
    
    # Get project by ID
    [Project] GetProject([string]$projectId) {
        if ([string]::IsNullOrWhiteSpace($projectId)) {
            throw [System.ArgumentException]::new("Project ID cannot be null or empty")
        }
        
        if ($this.DataStore.Projects.ContainsKey($projectId)) {
            return $this.DataStore.Projects[$projectId]
        }
        
        return $null
    }
    
    # Add a new project
    [Project] AddProject([Project]$project) {
        return Invoke-WithErrorHandling -Component "DataManager" -Context "AddProject" -ScriptBlock {
            if ($null -eq $project) {
                throw [System.ArgumentNullException]::new("project", "Project cannot be null")
            }
            
            # Validate project
            if (-not $project.Validate()) {
                throw [System.InvalidOperationException]::new("Project validation failed")
            }
            
            # Check for duplicate ID
            if ($this.DataStore.Projects.ContainsKey($project.Id)) {
                throw [System.InvalidOperationException]::new("Project with ID '$($project.Id)' already exists")
            }
            
            # Add to store
            $this.DataStore.Projects[$project.Id] = $project
            
            Write-Log -Level Info -Message "Added project: $($project.Name)" -Component "DataManager"
            
            # Publish event
            Publish-Event -EventName "Projects.Changed" -Data @{
                Action = "Add"
                ProjectId = $project.Id
                Project = $project
            }
            
            # Trigger auto-save
            $this.ScheduleAutoSave()
            
            return $project
        }
    }
    
    # Update an existing project
    [Project] UpdateProject([Project]$project) {
        return Invoke-WithErrorHandling -Component "DataManager" -Context "UpdateProject" -ScriptBlock {
            if ($null -eq $project) {
                throw [System.ArgumentNullException]::new("project", "Project cannot be null")
            }
            
            # Check if project exists
            if (-not $this.DataStore.Projects.ContainsKey($project.Id)) {
                throw [System.InvalidOperationException]::new("Project with ID '$($project.Id)' not found")
            }
            
            # Validate project
            if (-not $project.Validate()) {
                throw [System.InvalidOperationException]::new("Project validation failed")
            }
            
            # Get old project for comparison
            $oldProject = $this.DataStore.Projects[$project.Id]
            
            # Update project
            $project.ModifiedDate = [DateTime]::Now
            $this.DataStore.Projects[$project.Id] = $project
            
            Write-Log -Level Info -Message "Updated project: $($project.Name)" -Component "DataManager"
            
            # Publish event
            Publish-Event -EventName "Projects.Changed" -Data @{
                Action = "Update"
                ProjectId = $project.Id
                Project = $project
                OldProject = $oldProject
            }
            
            # Trigger auto-save
            $this.ScheduleAutoSave()
            
            return $project
        }
    }
    
    # Delete a project
    [void] DeleteProject([string]$projectId) {
        Invoke-WithErrorHandling -Component "DataManager" -Context "DeleteProject" -ScriptBlock {
            if ([string]::IsNullOrWhiteSpace($projectId)) {
                throw [System.ArgumentException]::new("Project ID cannot be null or empty")
            }
            
            # Check if project exists
            if (-not $this.DataStore.Projects.ContainsKey($projectId)) {
                throw [System.InvalidOperationException]::new("Project with ID '$projectId' not found")
            }
            
            # Check for tasks in project
            $projectTasks = $this.GetTasksByProject($projectId)
            if ($projectTasks.Count -gt 0) {
                throw [System.InvalidOperationException]::new(
                    "Cannot delete project with $($projectTasks.Count) tasks. Delete or reassign tasks first."
                )
            }
            
            # Get project for event data
            $project = $this.DataStore.Projects[$projectId]
            
            # Remove project
            $this.DataStore.Projects.Remove($projectId)
            
            Write-Log -Level Info -Message "Deleted project: $($project.Name)" -Component "DataManager"
            
            # Publish event
            Publish-Event -EventName "Projects.Changed" -Data @{
                Action = "Delete"
                ProjectId = $projectId
                Project = $project
            }
            
            # Trigger auto-save
            $this.ScheduleAutoSave()
        }
    }
    
    # Get application settings
    [Settings] GetSettings() {
        return $this.DataStore.Settings
    }
    
    # Update application settings
    [void] UpdateSettings([Settings]$settings) {
        if ($null -eq $settings) {
            throw [System.ArgumentNullException]::new("settings", "Settings cannot be null")
        }
        
        # Validate settings
        if (-not $settings.Validate()) {
            throw [System.InvalidOperationException]::new("Settings validation failed")
        }
        
        $this.DataStore.Settings = $settings
        
        Write-Log -Level Info -Message "Updated application settings" -Component "DataManager"
        
        # Publish event
        Publish-Event -EventName "Settings.Changed" -Data @{
            Settings = $settings
        }
        
        # Trigger auto-save
        $this.ScheduleAutoSave()
    }
    
    # Update project statistics
    hidden [void] UpdateProjectStatistics([string]$projectId) {
        if ([string]::IsNullOrWhiteSpace($projectId)) {
            return
        }
        
        $project = $this.GetProject($projectId)
        if ($null -eq $project) {
            return
        }
        
        $tasks = $this.GetTasksByProject($projectId)
        $completedTasks = $tasks | Where-Object { $_.Status -eq [TaskStatus]::Completed }
        
        $project.UpdateTaskStatistics($tasks.Count, $completedTasks.Count)
    }
    
    # Save data to file
    [void] SaveData() {
        Invoke-WithErrorHandling -Component "DataManager" -Context "SaveData" -ScriptBlock {
            # Ensure directory exists
            $directory = Split-Path -Path $this.DataFilePath -Parent
            if (-not (Test-Path $directory)) {
                New-Item -ItemType Directory -Path $directory -Force | Out-Null
            }
            
            # Update metadata
            $this.DataStore.Metadata.LastSaved = [DateTime]::Now
            
            # Convert to JSON
            $json = $this.DataStore | ConvertTo-Json -Depth 10 -Compress
            
            # Save to file
            Set-Content -Path $this.DataFilePath -Value $json -Encoding UTF8
            
            Write-Log -Level Info -Message "Data saved to: $($this.DataFilePath)" -Component "DataManager"
            
            # Publish event
            Publish-Event -EventName "Data.Saved"
        }
    }
    
    # Load data from file
    [void] LoadData() {
        Invoke-WithErrorHandling -Component "DataManager" -Context "LoadData" -ScriptBlock {
            if (-not (Test-Path $this.DataFilePath)) {
                Write-Log -Level Info -Message "No data file found. Starting with empty data." -Component "DataManager"
                return
            }
            
            # Read and parse JSON
            $json = Get-Content -Path $this.DataFilePath -Raw -Encoding UTF8
            $loadedData = $json | ConvertFrom-Json -AsHashtable
            
            # Validate data format version
            if ($loadedData.Metadata.DataFormatVersion -ne $this.DataStore.Metadata.DataFormatVersion) {
                Write-Log -Level Warning -Message "Data format version mismatch. Migration may be needed." -Component "DataManager"
            }
            
            # Restore data
            $global:Data = $loadedData
            $this.DataStore = $global:Data
            
            # Convert PSCustomObjects back to proper classes
            $this.ConvertLoadedData()
            
            Write-Log -Level Info -Message "Data loaded from: $($this.DataFilePath)" -Component "DataManager"
            
            # Publish event
            Publish-Event -EventName "Data.Loaded"
        }
    }
    
    # Convert loaded JSON data back to proper classes
    hidden [void] ConvertLoadedData() {
        # Convert tasks
        $convertedTasks = @{}
        foreach ($taskId in $this.DataStore.Tasks.Keys) {
            $taskData = $this.DataStore.Tasks[$taskId]
            $task = [Task]::new()
            
            # Copy properties
            foreach ($prop in $taskData.PSObject.Properties) {
                if ($null -ne $task.PSObject.Properties[$prop.Name]) {
                    $task.($prop.Name) = $prop.Value
                }
            }
            
            $convertedTasks[$taskId] = $task
        }
        $this.DataStore.Tasks = $convertedTasks
        
        # Convert projects
        $convertedProjects = @{}
        foreach ($projectId in $this.DataStore.Projects.Keys) {
            $projectData = $this.DataStore.Projects[$projectId]
            $project = [Project]::new()
            
            # Copy properties
            foreach ($prop in $projectData.PSObject.Properties) {
                if ($null -ne $project.PSObject.Properties[$prop.Name]) {
                    $project.($prop.Name) = $prop.Value
                }
            }
            
            $convertedProjects[$projectId] = $project
        }
        $this.DataStore.Projects = $convertedProjects
        
        # Convert settings
        $settingsData = $this.DataStore.Settings
        $settings = [Settings]::new()
        
        foreach ($prop in $settingsData.PSObject.Properties) {
            if ($null -ne $settings.PSObject.Properties[$prop.Name]) {
                $settings.($prop.Name) = $prop.Value
            }
        }
        
        $this.DataStore.Settings = $settings
    }
    
    # Schedule auto-save
    hidden [void] ScheduleAutoSave() {
        if (-not $this.AutoSaveEnabled) {
            return
        }
        
        # Cancel existing timer if any
        if ($null -ne $this.AutoSaveTimer) {
            $this.AutoSaveTimer.Stop()
            $this.AutoSaveTimer.Dispose()
        }
        
        # Create new timer for 5 seconds
        $this.AutoSaveTimer = [System.Timers.Timer]::new(5000)
        $this.AutoSaveTimer.AutoReset = $false
        
        Register-ObjectEvent -InputObject $this.AutoSaveTimer -EventName Elapsed -Action {
            $dataManager = $Event.MessageData
            $dataManager.SaveData()
        } -MessageData $this | Out-Null
        
        $this.AutoSaveTimer.Start()
    }
    
    # Enable auto-save
    [void] EnableAutoSave() {
        $this.AutoSaveEnabled = $true
        Write-Log -Level Info -Message "Auto-save enabled" -Component "DataManager"
    }
    
    # Disable auto-save
    [void] DisableAutoSave() {
        $this.AutoSaveEnabled = $false
        
        if ($null -ne $this.AutoSaveTimer) {
            $this.AutoSaveTimer.Stop()
            $this.AutoSaveTimer.Dispose()
            $this.AutoSaveTimer = $null
        }
        
        Write-Log -Level Info -Message "Auto-save disabled" -Component "DataManager"
    }
    
    # Get data statistics
    [hashtable] GetStatistics() {
        $stats = @{
            TotalTasks = $this.DataStore.Tasks.Count
            ActiveTasks = ($this.GetTasks() | Where-Object { $_.Status -eq [TaskStatus]::Active }).Count
            CompletedTasks = ($this.GetTasks() | Where-Object { $_.Status -eq [TaskStatus]::Completed }).Count
            OverdueTasks = ($this.GetTasks() | Where-Object { $_.IsOverdue() }).Count
            TotalProjects = $this.DataStore.Projects.Count
            ActiveProjects = ($this.GetProjects() | Where-Object { $_.Status -eq [ProjectStatus]::Active }).Count
            LastSaved = $this.DataStore.Metadata.LastSaved
        }
        
        return $stats
    }
}

# Export all classes
Export-ModuleMember -Function * -Cmdlet * -Variable * -Alias *