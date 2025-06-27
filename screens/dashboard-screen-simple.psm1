# Dashboard Screen - Simplified and Fixed Version
# Main menu screen with direct navigation integration

function Get-DashboardScreen {
    param([hashtable]$Services)
    
    # Validate services
    if (-not $Services) {
        if ($global:Services) {
            $Services = $global:Services
        }
        else {
            throw "Services parameter is required for dashboard initialization"
        }
    }
    
    $screen = @{
        Name = "DashboardScreen"
        Components = @{}
        Children = @()
        _services = $Services
        _subscriptions = @()
        Visible = $true
        ZIndex = 0
        
        Init = {
            param($self, $services)
            
            try {
                if (-not $services) {
                    $services = $self._services
                }
                
                Write-Log -Level Info -Message "Dashboard initialization started"
                
                # Create main container
                $mainWidth = [Math]::Max(80, ($global:TuiState.BufferWidth - 4))
                $mainHeight = [Math]::Max(25, ($global:TuiState.BufferHeight - 4))
                
                $rootPanel = New-TuiStackPanel -Props @{
                    X = 2
                    Y = 2
                    Width = $mainWidth
                    Height = $mainHeight
                    ShowBorder = $true
                    Title = " PMC Terminal v5 - Main Menu "
                    Orientation = "Vertical"
                    Spacing = 1
                    Padding = 2
                }
                
                # Add title and instructions
                $titleLabel = New-TuiLabel -Props @{
                    Text = "Welcome to PMC Terminal v5"
                    Height = 1
                    Width = "100%"
                    Alignment = "Center"
                    ForegroundColor = "Cyan"
                }
                & $rootPanel.AddChild -self $rootPanel -Child $titleLabel
                
                $instructionLabel = New-TuiLabel -Props @{
                    Text = "Select an option using number keys (1-4) or use arrow keys and Enter"
                    Height = 1
                    Width = "100%"
                    Alignment = "Center"
                    ForegroundColor = "Gray"
                }
                & $rootPanel.AddChild -self $rootPanel -Child $instructionLabel
                
                # Add spacing
                $spacer = New-TuiLabel -Props @{
                    Text = ""
                    Height = 1
                    Width = "100%"
                }
                & $rootPanel.AddChild -self $rootPanel -Child $spacer
                
                # Create menu using simple labels instead of DataTable for reliability
                $menuPanel = New-TuiStackPanel -Props @{
                    Orientation = "Vertical"
                    Width = 60
                    Height = 10
                    ShowBorder = $true
                    Title = " Main Menu "
                    Padding = 1
                    Spacing = 0
                }
                
                # Menu items
                $menuItems = @(
                    @{ Key = "1"; Text = "[1] Task Management"; Path = "/tasks" }
                    @{ Key = "2"; Text = "[2] Project Management"; Path = "/projects" }
                    @{ Key = "3"; Text = "[3] Settings"; Path = "/settings" }
                    @{ Key = "4"; Text = "[4] Reports"; Path = "/reports" }
                    @{ Key = "0"; Text = "[0] Exit Application"; Path = "/exit" }
                )
                
                $self._menuItems = $menuItems
                $self._selectedIndex = 0
                $self._menuLabels = @()
                
                # Create menu item labels
                for ($i = 0; $i -lt $menuItems.Count; $i++) {
                    $item = $menuItems[$i]
                    $label = New-TuiLabel -Props @{
                        Text = $item.Text
                        Width = "100%"
                        Height = 1
                        Name = "MenuItem_$i"
                    }
                    & $menuPanel.AddChild -self $menuPanel -Child $label
                    $self._menuLabels += $label
                }
                
                & $rootPanel.AddChild -self $rootPanel -Child $menuPanel
                $self.Components.menuPanel = $menuPanel
                
                # Status display
                $statusLabel = New-TuiLabel -Props @{
                    Text = "Loading..."
                    Height = 1
                    Width = "100%"
                    ForegroundColor = "Gray"
                    Alignment = "Center"
                }
                & $rootPanel.AddChild -self $rootPanel -Child $statusLabel
                $self.Components.statusLabel = $statusLabel
                
                # Store components
                $self.Components.rootPanel = $rootPanel
                $self.Children = @($rootPanel)
                
                # Update selection display
                $self.UpdateMenuDisplay = {
                    param($self)
                    for ($i = 0; $i -lt $self._menuLabels.Count; $i++) {
                        $label = $self._menuLabels[$i]
                        if ($i -eq $self._selectedIndex) {
                            $label.ForegroundColor = "Black"
                            $label.BackgroundColor = "Cyan"
                        } else {
                            $label.ForegroundColor = "White"
                            $label.BackgroundColor = "Black"
                        }
                    }
                    Request-TuiRefresh
                }
                
                # Refresh data function
                $self.RefreshData = {
                    param($self)
                    
                    try {
                        $openTasks = 0
                        if ($global:Data -and $global:Data.Tasks) {
                            if ($global:Data.Tasks -is [hashtable]) {
                                $tasks = $global:Data.Tasks.Values
                            } else {
                                $tasks = $global:Data.Tasks
                            }
                            $openTasks = @($tasks | Where-Object { $_.Completed -eq $false }).Count
                        }
                        
                        if ($self.Components.statusLabel) {
                            $self.Components.statusLabel.Text = "Open Tasks: $openTasks | Press number key or use arrows"
                        }
                        
                        Request-TuiRefresh
                    }
                    catch {
                        Write-Log -Level Error -Message "Dashboard data refresh failed: $_"
                    }
                }
                
                # Subscribe to events
                $subscriptionId = Subscribe-Event -EventName "Tasks.Changed" -Handler {
                    & $self.RefreshData -self $self
                }
                $self._subscriptions += $subscriptionId
                
                # Initial setup
                & $self.UpdateMenuDisplay -self $self
                & $self.RefreshData -self $self
                
                Write-Log -Level Info -Message "Dashboard initialization completed"
            }
            catch {
                Write-Log -Level Error -Message "Dashboard initialization failed: $_"
                throw
            }
        }
        
        HandleInput = {
            param($self, $key)
            
            if (-not $key) { return $false }
            
            try {
                # Number key shortcuts
                if ($key.KeyChar -match '[0-4]') {
                    $index = [int]$key.KeyChar.ToString()
                    
                    if ($index -eq 0) {
                        Write-Log -Level Info -Message "Exit requested"
                        $self._services.Navigation.RequestExit()
                        return $true
                    }
                    
                    $selectedItem = $self._menuItems | Where-Object { $_.Key -eq $index.ToString() } | Select-Object -First 1
                    if ($selectedItem) {
                        Write-Log -Level Info -Message "Navigating to $($selectedItem.Path)"
                        $result = $self._services.Navigation.GoTo($selectedItem.Path)
                        if (-not $result) {
                            Write-Log -Level Warning -Message "Navigation failed to $($selectedItem.Path)"
                        }
                        return $true
                    }
                }
                
                # Arrow navigation
                switch ($key.Key) {
                    "UpArrow" {
                        if ($self._selectedIndex -gt 0) {
                            $self._selectedIndex--
                            & $self.UpdateMenuDisplay -self $self
                        }
                        return $true
                    }
                    "DownArrow" {
                        if ($self._selectedIndex -lt ($self._menuItems.Count - 1)) {
                            $self._selectedIndex++
                            & $self.UpdateMenuDisplay -self $self
                        }
                        return $true
                    }
                    "Enter" {
                        $selectedItem = $self._menuItems[$self._selectedIndex]
                        Write-Log -Level Info -Message "Enter pressed for $($selectedItem.Path)"
                        
                        if ($selectedItem.Path -eq "/exit") {
                            $self._services.Navigation.RequestExit()
                        } else {
                            $result = $self._services.Navigation.GoTo($selectedItem.Path)
                            if (-not $result) {
                                Write-Log -Level Warning -Message "Navigation failed to $($selectedItem.Path)"
                            }
                        }
                        return $true
                    }
                }
                
                return $false
            }
            catch {
                Write-Log -Level Error -Message "Dashboard input handling error: $_"
                return $false
            }
        }
        
        OnEnter = {
            param($self)
            Write-Log -Level Info -Message "Dashboard entered"
            
            if ($self.UpdateMenuDisplay) {
                & $self.UpdateMenuDisplay -self $self
            }
            if ($self.RefreshData) {
                & $self.RefreshData -self $self
            }
            Request-TuiRefresh
        }
        
        OnExit = {
            param($self)
            Write-Log -Level Info -Message "Dashboard exiting"
            
            # Unsubscribe from events
            if ($self._subscriptions -and @($self._subscriptions).Count -gt 0) {
                foreach ($subId in $self._subscriptions) {
                    if ($subId) {
                        try {
                            Unsubscribe-Event -EventName "Tasks.Changed" -SubscriberId $subId
                        }
                        catch {
                            Write-Log -Level Warning -Message "Failed to unsubscribe: $_"
                        }
                    }
                }
                $self._subscriptions = @()
            }
        }
        
        Render = {
            param($self)
            # Components handle their own rendering
        }
    }
    
    $screen._services = $Services
    return $screen
}

Export-ModuleMember -Function Get-DashboardScreen
