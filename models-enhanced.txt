# Enhanced Models Module with Validation
# Shows how to add validation to PowerShell classes for better error prevention

# Base validation class
class ValidationBase {
    # Validation helper methods
    static [void] ValidateNotNull([object]$value, [string]$parameterName) {
        if ($null -eq $value) {
            throw [System.ArgumentNullException]::new($parameterName)
        }
    }
    
    static [void] ValidateNotEmpty([string]$value, [string]$parameterName) {
        if ([string]::IsNullOrWhiteSpace($value)) {
            throw [System.ArgumentException]::new("$parameterName cannot be null or empty")
        }
    }
    
    static [void] ValidateRange([int]$value, [int]$min, [int]$max, [string]$parameterName) {
        if ($value -lt $min -or $value -gt $max) {
            throw [System.ArgumentOutOfRangeException]::new($parameterName, "Value must be between $min and $max")
        }
    }
    
    static [void] ValidateEnum([object]$value, [Type]$enumType, [string]$parameterName) {
        if (-not [Enum]::IsDefined($enumType, $value)) {
            throw [System.ArgumentException]::new("Invalid $parameterName value: $value")
        }
    }
}

# Task Priority Enum
enum TaskPriority {
    Low = 0
    Medium = 1
    High = 2
    Critical = 3
}

# Task Status Enum  
enum TaskStatus {
    NotStarted = 0
    InProgress = 1
    Blocked = 2
    Completed = 3
    Cancelled = 4
}

# Enhanced Task class with validation
class Task : ValidationBase {
    [string] $Id
    [string] $Title
    [string] $Description
    [TaskPriority] $Priority = [TaskPriority]::Medium
    [TaskStatus] $Status = [TaskStatus]::NotStarted
    [DateTime] $CreatedDate
    [DateTime] $ModifiedDate
    [Nullable[DateTime]] $DueDate
    [Nullable[DateTime]] $CompletedDate
    [bool] $Completed = $false
    [string[]] $Tags = @()
    [string] $ProjectId
    [hashtable] $CustomFields = @{}
    [string] $Notes = ""
    hidden [bool] $_isValidated = $false
    
    # Constructor with validation
    Task([string]$title, [string]$description) {
        # Validate inputs
        [ValidationBase]::ValidateNotEmpty($title, "title")
        
        # Initialize properties
        $this.Id = "task-" + [Guid]::NewGuid().ToString()
        $this.Title = $title.Trim()
        $this.Description = if ($description) { $description.Trim() } else { "" }
        $this.CreatedDate = [DateTime]::Now
        $this.ModifiedDate = [DateTime]::Now
        $this._isValidated = $true
    }
    
    # Property setters with validation
    [void] SetTitle([string]$value) {
        [ValidationBase]::ValidateNotEmpty($value, "Title")
        $this.Title = $value.Trim()
        $this.ModifiedDate = [DateTime]::Now
    }
    
    [void] SetPriority([TaskPriority]$value) {
        [ValidationBase]::ValidateEnum($value, [TaskPriority], "Priority")
        $this.Priority = $value
        $this.ModifiedDate = [DateTime]::Now
    }
    
    [void] SetStatus([TaskStatus]$value) {
        [ValidationBase]::ValidateEnum($value, [TaskStatus], "Status")
        
        # Business logic validation
        if ($this.Status -eq [TaskStatus]::Completed -and $value -ne [TaskStatus]::Completed) {
            throw [System.InvalidOperationException]::new("Cannot change status of completed task")
        }
        
        $this.Status = $value
        $this.ModifiedDate = [DateTime]::Now
        
        # Auto-complete logic
        if ($value -eq [TaskStatus]::Completed) {
            $this.Completed = $true
            $this.CompletedDate = [DateTime]::Now
        }
    }
    
    [void] SetDueDate([Nullable[DateTime]]$value) {
        if ($value -ne $null -and $value -lt [DateTime]::Now.Date) {
            throw [System.ArgumentException]::new("Due date cannot be in the past")
        }
        $this.DueDate = $value
        $this.ModifiedDate = [DateTime]::Now
    }
    
    # Validation method
    [bool] Validate() {
        try {
            [ValidationBase]::ValidateNotEmpty($this.Id, "Id")
            [ValidationBase]::ValidateNotEmpty($this.Title, "Title")
            [ValidationBase]::ValidateEnum($this.Priority, [TaskPriority], "Priority")
            [ValidationBase]::ValidateEnum($this.Status, [TaskStatus], "Status")
            
            # Business rule validations
            if ($this.Completed -and $null -eq $this.CompletedDate) {
                throw [System.InvalidOperationException]::new("Completed task must have completion date")
            }
            
            if ($this.Status -eq [TaskStatus]::Completed -and -not $this.Completed) {
                throw [System.InvalidOperationException]::new("Status and Completed flag mismatch")
            }
            
            return $true
        }
        catch {
            Write-Warning "Task validation failed: $_"
            return $false
        }
    }
    
    # Safe property getters
    [string] GetSafeTitle() {
        return if ($this.Title) { $this.Title } else { "Untitled" }
    }
    
    [bool] IsOverdue() {
        return $null -ne $this.DueDate -and 
               $this.DueDate -lt [DateTime]::Now -and 
               -not $this.Completed
    }
    
    # Clone method for safe copying
    [Task] Clone() {
        $newTask = [Task]::new($this.Title, $this.Description)
        $newTask.Priority = $this.Priority
        $newTask.Status = $this.Status
        $newTask.DueDate = $this.DueDate
        $newTask.Tags = $this.Tags.Clone()
        $newTask.ProjectId = $this.ProjectId
        $newTask.Notes = $this.Notes
        return $newTask
    }
}

# Enhanced Project class with validation
class Project : ValidationBase {
    [string] $Id
    [string] $Name
    [string] $Description
    [DateTime] $CreatedDate
    [DateTime] $ModifiedDate
    [hashtable] $Settings = @{}
    [string[]] $TaskIds = @()
    hidden [int] $_maxTasks = 1000
    
    Project([string]$name) {
        [ValidationBase]::ValidateNotEmpty($name, "name")
        
        $this.Id = "proj-" + [Guid]::NewGuid().ToString()
        $this.Name = $name.Trim()
        $this.CreatedDate = [DateTime]::Now
        $this.ModifiedDate = [DateTime]::Now
    }
    
    [void] AddTaskId([string]$taskId) {
        [ValidationBase]::ValidateNotEmpty($taskId, "taskId")
        
        if ($this.TaskIds.Count -ge $this._maxTasks) {
            throw [System.InvalidOperationException]::new("Project has reached maximum task limit")
        }
        
        if ($taskId -in $this.TaskIds) {
            throw [System.InvalidOperationException]::new("Task already exists in project")
        }
        
        $this.TaskIds += $taskId
        $this.ModifiedDate = [DateTime]::Now
    }
    
    [void] RemoveTaskId([string]$taskId) {
        [ValidationBase]::ValidateNotEmpty($taskId, "taskId")
        
        $this.TaskIds = $this.TaskIds | Where-Object { $_ -ne $taskId }
        $this.ModifiedDate = [DateTime]::Now
    }
    
    [bool] Validate() {
        try {
            [ValidationBase]::ValidateNotEmpty($this.Id, "Id")
            [ValidationBase]::ValidateNotEmpty($this.Name, "Name")
            return $true
        }
        catch {
            return $false
        }
    }
}

# Enhanced Settings class with validation and type safety
class Settings : ValidationBase {
    [ValidateSet("Light", "Dark", "Auto")]
    [string] $Theme = "Dark"
    
    [ValidateRange(1, 100)]
    [int] $MaxRecentItems = 10
    
    [bool] $ShowCompletedTasks = $true
    [bool] $EnableNotifications = $true
    [string] $DefaultView = "Dashboard"
    [hashtable] $UserPreferences = @{}
    hidden [string[]] $_allowedViews = @("Dashboard", "Tasks", "Projects", "Calendar")
    
    Settings() {
        # Initialize with defaults
    }
    
    [void] SetTheme([string]$value) {
        if ($value -notin @("Light", "Dark", "Auto")) {
            throw [System.ArgumentException]::new("Invalid theme. Must be Light, Dark, or Auto")
        }
        $this.Theme = $value
    }
    
    [void] SetMaxRecentItems([int]$value) {
        [ValidationBase]::ValidateRange($value, 1, 100, "MaxRecentItems")
        $this.MaxRecentItems = $value
    }
    
    [void] SetDefaultView([string]$value) {
        if ($value -notin $this._allowedViews) {
            throw [System.ArgumentException]::new("Invalid view. Allowed views: $($this._allowedViews -join ', ')")
        }
        $this.DefaultView = $value
    }
    
    [hashtable] ToHashtable() {
        return @{
            Theme = $this.Theme
            MaxRecentItems = $this.MaxRecentItems
            ShowCompletedTasks = $this.ShowCompletedTasks
            EnableNotifications = $this.EnableNotifications
            DefaultView = $this.DefaultView
            UserPreferences = $this.UserPreferences.Clone()
        }
    }
    
    [void] FromHashtable([hashtable]$data) {
        [ValidationBase]::ValidateNotNull($data, "data")
        
        if ($data.ContainsKey("Theme")) { $this.SetTheme($data.Theme) }
        if ($data.ContainsKey("MaxRecentItems")) { $this.SetMaxRecentItems($data.MaxRecentItems) }
        if ($data.ContainsKey("ShowCompletedTasks")) { $this.ShowCompletedTasks = [bool]$data.ShowCompletedTasks }
        if ($data.ContainsKey("EnableNotifications")) { $this.EnableNotifications = [bool]$data.EnableNotifications }
        if ($data.ContainsKey("DefaultView")) { $this.SetDefaultView($data.DefaultView) }
        if ($data.ContainsKey("UserPreferences")) { $this.UserPreferences = $data.UserPreferences.Clone() }
    }
}

# Export all classes
Export-ModuleMember -Function * -Cmdlet * -Variable * -Alias *
