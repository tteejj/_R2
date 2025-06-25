#
# FILE: screens/task-screen.psm1
# PURPOSE: Task Screen Module - Refactored for Service-Oriented Architecture
# AI: This file has been corrected to use the proper DataTable component and its corresponding methods.
#

using module '..\modules\models.psm1'
using module '..\components\advanced-data-components.psm1' # AI: Added required module for New-TuiDataTable

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-TaskManagementScreen {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Services
    )
    
    Invoke-WithErrorHandling -Component "TaskScreen.Factory" -Context "Creating Task Management Screen" -ScriptBlock {
        # Validate services parameter
        if (-not $Services) {
            throw "Services parameter is required for task management screen"
        }
        
        if (-not $Services.DataManager) {
            throw "DataManager service is required but not found in services"
        }
        
        $screen = @{
            Name = "TaskManagementScreen"
            Components = @{}
            Children = @()
            _subscriptions = @()
            _services = $Services
            _formMode = $null  # null = list view, "create" = new task, "edit" = edit task
            _selectedTask = $null
            _focusIndex = 0
            _formFocusableComponents = @()
            Visible = $true
            ZIndex = 0
            
            Init = {
                param($self)
                
                Invoke-WithErrorHandling -Component "TaskScreen.Init" -Context "Initializing Task Screen" -ScriptBlock {
                    $services = $self._services
                    Write-Log -Level Info -Message "Task Screen Init: Starting initialization"
                    
                    # Create root panel
                    $rootPanel = New-TuiStackPanel -Props @{
                        Name = "TaskScreenRoot"
                        Orientation = "Vertical"
                        Width = $global:TuiState.BufferWidth
                        Height = $global:TuiState.BufferHeight
                    }
                    
                    # Create list view panel
                    $listPanel = New-TuiStackPanel -Props @{
                        Name = "TaskListView"
                        Orientation = "Vertical"
                        Width = "100%"
                        Height = "100%"
                        Visible = $true
                    }
                    
                    # Create header for list view
                    $headerPanel = New-TuiStackPanel -Props @{
                        Orientation = "Horizontal"
                        Width = "100%"
                        Height = 3
                        Padding = 1
                    }
                    
                    $titleLabel = New-TuiLabel -Props @{
                        Text = " Task Management "
                    }
                    
                    $actionsLabel = New-TuiLabel -Props @{
                        Text = "[N]ew  [E]dit  [D]elete  [Space]Toggle  [Esc]Back"
                    }
                    
                    & $headerPanel.AddChild -self $headerPanel -Child $titleLabel
                    & $headerPanel.AddChild -self $headerPanel -Child $actionsLabel
                    & $listPanel.AddChild -self $listPanel -Child $headerPanel
                    
                    # AI: Corrected to use New-TuiDataTable and fixed column definitions
                    $taskTable = New-TuiDataTable -Props @{
                        Name = "TaskTable"
                        Width = "100%"
                        Height = $global:TuiState.BufferHeight - 5
                        Columns = @(
                            @{ Header = "✓"; Name = "Status"; Width = 3; Align = "Center"; Format = { param($value, $row) if ($row.Completed) { "✓" } else { "○" } } }
                            @{ Header = "Title"; Name = "Title"; Width = 40 }
                            @{ Header = "Priority"; Name = "Priority"; Width = 10 }
                            @{ Header = "Category"; Name = "Category"; Width = 20 }
                            @{ Header = "Due Date"; Name = "DueDate"; Width = 12; Format = { param($value) if ($value) { $value.ToString("yyyy-MM-dd") } else { "N/A" } } }
                        )
                        Data = @()
                        ShowHeader = $true
                        IsFocusable = $true
                    }
                    
                    & $listPanel.AddChild -self $listPanel -Child $taskTable
                    & $rootPanel.AddChild -self $rootPanel -Child $listPanel
                    
                    # Create form view panel (initially hidden)
                    $formPanel = New-TuiStackPanel -Props @{
                        Name = "TaskFormView"
                        Orientation = "Vertical"
                        Width = "100%"
                        Height = "100%"
                        Visible = $false
                        Padding = 2
                        ShowBorder = $true
                    }
                    
                    # Form title is set dynamically
                    
                    # Create form fields
                    $titleInput = New-TuiTextBox -Props @{ Name = "TitleInput"; Width = 50; IsFocusable = $true }
                    $descInput = New-TuiTextArea -Props @{ Name = "DescInput"; Width = 50; Height = 5; IsFocusable = $true }
                    $priorityDropdown = New-TuiDropdown -Props @{ Name = "PriorityDropdown"; Width = 20; Options = @(@{Display="Low";Value="low"},@{Display="Medium";Value="medium"},@{Display="High";Value="high"}); Value = "medium"; IsFocusable = $true }
                    $categoryInput = New-TuiTextBox -Props @{ Name = "CategoryInput"; Width = 50; Text = "General"; IsFocusable = $true }
                    $dueDateInput = New-TuiTextBox -Props @{ Name = "DueDateInput"; Width = 20; Placeholder = "yyyy-MM-dd"; IsFocusable = $true }
                    
                    # Form buttons
                    $buttonPanel = New-TuiStackPanel -Props @{ Orientation = "Horizontal"; Width = "100%"; Height = 3; Spacing = 2; Margin = 1 }
                    
                    $capturedSelf = $self
                    
                    $saveButton = New-TuiButton -Props @{ Text = "[S]ave"; IsFocusable = $true; OnClick = { & $capturedSelf.SaveTask -self $capturedSelf } }
                    $cancelButton = New-TuiButton -Props @{ Text = "[C]ancel"; IsFocusable = $true; OnClick = { & $capturedSelf.ShowListView -self $capturedSelf } }
                    
                    & $buttonPanel.AddChild -self $buttonPanel -Child $saveButton
                    & $buttonPanel.AddChild -self $buttonPanel -Child $cancelButton
                    
                    # Add all form fields to form panel
                    & $formPanel.AddChild -self $formPanel -Child (New-TuiLabel -Props @{ Text = "Title:" })
                    & $formPanel.AddChild -self $formPanel -Child $titleInput
                    & $formPanel.AddChild -self $formPanel -Child (New-TuiLabel -Props @{ Text = "Description:" })
                    & $formPanel.AddChild -self $formPanel -Child $descInput
                    & $formPanel.AddChild -self $formPanel -Child (New-TuiLabel -Props @{ Text = "Priority:" })
                    & $formPanel.AddChild -self $formPanel -Child $priorityDropdown
                    & $formPanel.AddChild -self $formPanel -Child (New-TuiLabel -Props @{ Text = "Category:" })
                    & $formPanel.AddChild -self $formPanel -Child $categoryInput
                    & $formPanel.AddChild -self $formPanel -Child (New-TuiLabel -Props @{ Text = "Due Date:" })
                    & $formPanel.AddChild -self $formPanel -Child $dueDateInput
                    & $formPanel.AddChild -self $formPanel -Child $buttonPanel
                    
                    & $rootPanel.AddChild -self $rootPanel -Child $formPanel
                    
                    # Store component references
                    $self.Components.rootPanel = $rootPanel
                    $self.Components.listPanel = $listPanel
                    $self.Components.formPanel = $formPanel
                    $self.Components.taskTable = $taskTable
                    $self.Components.titleInput = $titleInput
                    $self.Components.descInput = $descInput
                    $self.Components.priorityDropdown = $priorityDropdown
                    $self.Components.categoryInput = $categoryInput
                    $self.Components.dueDateInput = $dueDateInput
                    $self.Components.saveButton = $saveButton
                    $self.Components.cancelButton = $cancelButton
                    
                    $self._formFocusableComponents = @($titleInput, $descInput, $priorityDropdown, $categoryInput, $dueDateInput, $saveButton, $cancelButton)
                    
                    # Helper functions
                    $self.ShowListView = {
                        param($self)
                        $self._formMode = $null
                        $self._selectedTask = $null
                        $self._focusIndex = 0
                        $self.Components.listPanel.Visible = $true
                        $self.Components.formPanel.Visible = $false
                        Request-Focus -Component $self.Components.taskTable
                        Request-TuiRefresh
                    }
                    
                    $self.ShowFormView = {
                        param($self, $mode, $task)
                        $self._formMode = $mode
                        $self._selectedTask = $task
                        $self._focusIndex = 0
                        
                        $self.Components.formPanel.Title = if ($mode -eq "create") { " New Task " } else { " Edit Task " }
                        
                        if ($mode -eq "create") {
                            $self.Components.titleInput.Text = ""
                            $self.Components.descInput.Text = ""
                            $self.Components.priorityDropdown.Value = "medium"
                            $self.Components.categoryInput.Text = "General"
                            $self.Components.dueDateInput.Text = ""
                        } elseif ($task) {
                            $self.Components.titleInput.Text = $task.Title
                            $self.Components.descInput.Text = $task.Description
                            $self.Components.priorityDropdown.Value = $task.Priority.ToString().ToLower()
                            $self.Components.categoryInput.Text = $task.Category
                            $self.Components.dueDateInput.Text = if ($task.DueDate) { $task.DueDate.ToString('yyyy-MM-dd') } else { '' }
                        }
                        
                        $self.Components.listPanel.Visible = $false
                        $self.Components.formPanel.Visible = $true
                        Request-Focus -Component $self.Components.titleInput
                        Request-TuiRefresh
                    }
                    
                    $self.SaveTask = {
                        param($self)
                        Invoke-WithErrorHandling -Component "TaskScreen.SaveTask" -Context "Saving task data" -ScriptBlock {
                            $title = $self.Components.titleInput.Text
                            if ([string]::IsNullOrWhiteSpace($title)) {
                                Show-AlertDialog -Title "Validation Error" -Message "Title is required"
                                return
                            }
                            
                            $taskData = @{
                                Title = $title.Trim()
                                Description = $self.Components.descInput.Text
                                Priority = $self.Components.priorityDropdown.Value
                                Category = $self.Components.categoryInput.Text
                                DueDate = $self.Components.dueDateInput.Text
                            }
                            
                            if ($self._formMode -eq "create") {
                                & $self._services.DataManager.AddTask @taskData
                            } elseif ($self._formMode -eq "edit" -and $self._selectedTask) {
                                & $self._services.DataManager.UpdateTask -Task $self._selectedTask @taskData
                            }
                            
                            & $self.ShowListView -self $self
                        }
                    }
                    
                    $self.RefreshTaskList = {
                        param($self)
                        Invoke-WithErrorHandling -Component "TaskScreen.RefreshTaskList" -Context "Refreshing task list from global data" -ScriptBlock {
                            $tasks = if ($global:Data -and $global:Data.Tasks) { $global:Data.Tasks } else { @() }
                            $self.Components.taskTable.Data = $tasks
                            & $self.Components.taskTable.ProcessData -self $self.Components.taskTable
                            Request-TuiRefresh
                        }
                    }
                    
                    $subscriptionId = Subscribe-Event -EventName "Tasks.Changed" -Handler { & $self.RefreshTaskList -self $self } -Source "TaskManagementScreen"
                    $self._subscriptions += $subscriptionId
                    
                    & $self.RefreshTaskList -self $self
                    $self.Children = @($rootPanel)
                    Request-Focus -Component $taskTable
                }
            }
            
            HandleInput = {
                param($self, $key)
                
                if (-not $key) { return $false }
                
                Invoke-WithErrorHandling -Component "TaskScreen.HandleInput" -Context "Handling user input" -ScriptBlock {
                    if ($self._formMode) {
                        # AI: Form input handling
                        if ($key.Key -eq "Tab") {
                            $direction = if ($key.Modifiers -band [ConsoleModifiers]::Shift) { -1 } else { 1 }
                            $self._focusIndex = ($self._focusIndex + $direction + $self._formFocusableComponents.Count) % $self._formFocusableComponents.Count
                            Request-Focus -Component $self._formFocusableComponents[$self._focusIndex]
                            return $true
                        }
                        
                        $focusedComponent = $self._formFocusableComponents[$self._focusIndex]
                        if ($focusedComponent.HandleInput) {
                            return & $focusedComponent.HandleInput -self $focusedComponent -key $key
                        }
                    }
                    else {
                        # AI: List view input handling, simplified with a switch
                        switch -CaseSensitive ($key.KeyChar) {
                            'n' { & $self.ShowFormView -self $self -mode "create"; return $true }
                            'e' {
                                # AI: Corrected way to get selected data
                                $table = $self.Components.taskTable
                                $selectedTask = if ($table.ProcessedData.Count -gt 0) { $table.ProcessedData[$table.SelectedRow] } else { $null }
                                if ($selectedTask) { & $self.ShowFormView -self $self -mode "edit" -task $selectedTask }
                                return $true
                            }
                            'd' {
                                $table = $self.Components.taskTable
                                $selectedTask = if ($table.ProcessedData.Count -gt 0) { $table.ProcessedData[$table.SelectedRow] } else { $null }
                                if ($selectedTask) { & $self._services.DataManager.RemoveTask -Task $selectedTask }
                                return $true
                            }
                        }

                        if ($key.Key -eq "Spacebar") {
                            $table = $self.Components.taskTable
                            $selectedTask = if ($table.ProcessedData.Count -gt 0) { $table.ProcessedData[$table.SelectedRow] } else { $null }
                            if ($selectedTask) {
                                & $self._services.DataManager.UpdateTask -Task $selectedTask -Completed (-not $selectedTask.Completed)
                            }
                            return $true
                        }
                        
                        if ($key.Key -eq "Escape") {
                            & $self._services.Navigation.GoTo -self $self._services.Navigation -Path "/dashboard" -Services $self._services
                            return $true
                        }
                        
                        # Pass other keys to the task table
                        if ($self.Components.taskTable.HandleInput) {
                            return & $self.Components.taskTable.HandleInput -self $self.Components.taskTable -key $key
                        }
                    }
                    
                    return $false
                }
            }
            
            OnExit = {
                param($self)
                Invoke-WithErrorHandling -Component "TaskScreen.OnExit" -Context "Cleaning up Task Screen" -ScriptBlock {
                    foreach ($subId in $self._subscriptions) {
                        if ($subId) { Unsubscribe-Event -HandlerId $subId }
                    }
                    $self._subscriptions = @()
                    $self.Components = @{}
                    $self._formFocusableComponents = @()
                    Write-Log -Level Info -Message "Task Screen cleanup completed"
                }
            }
        }
        
        return $screen
    }
}

# Alias for backward compatibility if needed
function Get-TaskScreen {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Services
    )
    return Get-TaskManagementScreen -Services $Services
}

Export-ModuleMember -Function @('Get-TaskManagementScreen', 'Get-TaskScreen')