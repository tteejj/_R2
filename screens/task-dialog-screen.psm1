# Task Dialog Screen - Dialog for adding/editing tasks
# AI: Simple dialog implementation for task management

function Show-TaskDialog {
    param(
        [hashtable]$Services,
        [object]$ExistingTask = $null
    )
    
    $dialogResult = @{
        Confirmed = $false
        TaskData = @{}
    }
    
    # Create dialog
    $dialog = @{
        Name = "TaskDialog"
        Title = if ($ExistingTask) { " Edit Task " } else { " Add New Task " }
        Width = 60
        Height = 20
        X = ([Math]::Max(0, ($global:TuiState.BufferWidth - 60) / 2))
        Y = ([Math]::Max(0, ($global:TuiState.BufferHeight - 20) / 2))
        Components = @{}
        _services = $Services
        _result = $dialogResult
        _existingTask = $ExistingTask
        
        Init = {
            param($self)
            
            # Create main panel
            $panel = New-TuiStackPanel -Props @{
                X = $self.X
                Y = $self.Y
                Width = $self.Width
                Height = $self.Height
                ShowBorder = $true
                Title = $self.Title
                Orientation = "Vertical"
                Spacing = 1
                Padding = 2
            }
            
            # Title input
            $titleLabel = New-TuiLabel -Props @{
                Text = "Title:"
                Width = "100%"
            }
            & $panel.AddChild -self $panel -Child $titleLabel
            
            $titleInput = New-TuiTextBox -Props @{
                Name = "TitleInput"
                Width = "100%"
                IsFocusable = $true
                Placeholder = "Enter task title..."
                Text = if ($self._existingTask) { $self._existingTask.Title } else { "" }
            }
            & $panel.AddChild -self $panel -Child $titleInput
            $self.Components.titleInput = $titleInput
            
            # Priority selection
            $priorityLabel = New-TuiLabel -Props @{
                Text = "Priority: [L]ow / [M]edium / [H]igh"
                Width = "100%"
                Margin = @{ Top = 1 }
            }
            & $panel.AddChild -self $panel -Child $priorityLabel
            
            $priorityDisplay = New-TuiLabel -Props @{
                Text = if ($self._existingTask) { $self._existingTask.Priority } else { "Medium" }
                Width = "100%"
                ForegroundColor = "Yellow"
            }
            & $panel.AddChild -self $panel -Child $priorityDisplay
            $self.Components.priorityDisplay = $priorityDisplay
            $self._selectedPriority = if ($self._existingTask) { $self._existingTask.Priority } else { "Medium" }
            
            # Instructions
            $instructionLabel = New-TuiLabel -Props @{
                Text = "[Enter] Save | [ESC] Cancel"
                Width = "100%"
                ForegroundColor = "Gray"
                Margin = @{ Top = 2 }
            }
            & $panel.AddChild -self $panel -Child $instructionLabel
            
            $self.Components.panel = $panel
            $self.Children = @($panel)
            
            # Set initial focus
            Request-Focus -Component $titleInput
        }
        
        HandleInput = {
            param($self, $key)
            
            if (-not $key) { return $false }
            
            switch ($key.Key) {
                "Escape" {
                    # Cancel dialog
                    $self._result.Confirmed = $false
                    if (Get-Command "Close-Dialog" -ErrorAction SilentlyContinue) {
                        Close-Dialog
                    }
                    return $true
                }
                "Enter" {
                    # Save task
                    $title = $self.Components.titleInput.Text
                    if ([string]::IsNullOrWhiteSpace($title)) {
                        # Show error - in real app would show validation message
                        return $true
                    }
                    
                    $self._result.Confirmed = $true
                    $self._result.TaskData = @{
                        Title = $title.Trim()
                        Priority = $self._selectedPriority
                    }
                    
                    if (Get-Command "Close-Dialog" -ErrorAction SilentlyContinue) {
                        Close-Dialog
                    }
                    return $true
                }
                "L" {
                    $self._selectedPriority = "Low"
                    $self.Components.priorityDisplay.Text = "Low"
                    $self.Components.priorityDisplay.ForegroundColor = "Green"
                    Request-TuiRefresh
                    return $true
                }
                "M" {
                    $self._selectedPriority = "Medium"
                    $self.Components.priorityDisplay.Text = "Medium"
                    $self.Components.priorityDisplay.ForegroundColor = "Yellow"
                    Request-TuiRefresh
                    return $true
                }
                "H" {
                    $self._selectedPriority = "High"
                    $self.Components.priorityDisplay.Text = "High"
                    $self.Components.priorityDisplay.ForegroundColor = "Red"
                    Request-TuiRefresh
                    return $true
                }
            }
            
            # Pass to text input
            if ($self.Components.titleInput -and $self.Components.titleInput.HandleInput) {
                return & $self.Components.titleInput.HandleInput -self $self.Components.titleInput -key $key
            }
            
            return $false
        }
        
        Render = {
            param($self)
            # Panel handles rendering
        }
    }
    
    # Show dialog and wait for result
    if (Get-Command "Show-Dialog" -ErrorAction SilentlyContinue) {
        Show-Dialog -Dialog $dialog
    }
    
    return $dialogResult
}

Export-ModuleMember -Function Show-TaskDialog