# Dashboard Screen - Fixed for Class-Based Service-Oriented Architecture
# Displays main menu with proper navigation service integration
# AI: Removed 'using module' statements for PowerShell 5.1 compatibility

function Get-DashboardScreen {
    param([hashtable]$Services)
    
    # AI: Validate services upfront with clear error messaging
    if (-not $Services) {
        if ($global:Services) {
            $Services = $global:Services
        }
        else {
            throw "Services parameter is required for dashboard initialization"
        }
    }
    
    if (-not $Services.Navigation) {
        $availableServices = ($Services.Keys | Sort-Object) -join ", "
        throw "Navigation service is missing. Available services: $availableServices"
    }
    
    $screen = @{
        Name = "DashboardScreen"
        Components = @{}
        Children = @()
        _subscriptions = @()
        _focusIndex = 0
        _services = $Services
        Visible = $true
        ZIndex = 0
        
        Init = {
            param($self, $services)
            
            Invoke-WithErrorHandling -ScriptBlock {
                # AI: Use pre-validated services from screen creation
                if (-not $services) {
                    $services = $self._services
                }
                
                Write-Log -Level Info -Message "Dashboard initialization started"
                
                # Create main container panel
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
                
                $self.Components.rootPanel = $rootPanel
                $self.Children = @($rootPanel)
                
                # Add instruction text
                $instructionLabel = New-TuiLabel -Props @{
                    Text = "Select an option using number keys (1-4) or use arrow keys and Enter"
                    Height = 1
                    Width = "100%"
                    Name = "InstructionLabel"
                }
                & $rootPanel.AddChild -self $rootPanel -Child $instructionLabel
                
                # AI: Create menu items with clear structure
                $menuItems = @(
                    @{ Index = "1"; Action = "Task Management"; Path = "/tasks" }
                    @{ Index = "2"; Action = "Project Management"; Path = "/projects" }
                    @{ Index = "3"; Action = "Settings"; Path = "/settings" }
                    @{ Index = "4"; Action = "Reports"; Path = "/reports" }
                    @{ Index = "0"; Action = "Exit Application"; Path = "/exit" }
                )
                
                Write-Log -Level Debug -Message "Created menu with $($menuItems.Count) items"
                
                # AI: Simplified navigation callback for class-based service
                $navigationMenu = New-TuiDataTable -Props @{
                    Name = "NavigationMenu"
                    IsFocusable = $true
                    ShowBorder = $true
                    BorderStyle = "Single"
                    Title = " Main Menu "
                    Height = 12  # AI: Fixed height to ensure all items are visible
                    Width = 60
                    Columns = @(
                        @{ Name = "Index"; Width = 8; Align = "Center" }
                        @{ Name = "Action"; Width = 45; Align = "Left" }
                    )
                    Data = $menuItems
                    OnRowSelect = {
                        param($SelectedData, $SelectedIndex)
                        
                        # AI: Clean, simple navigation callback for class-based navigation service
                        Invoke-WithErrorHandling -Component "Dashboard.OnRowSelect" -Context "Navigation" -ScriptBlock {
                            if (-not $SelectedData -or -not $SelectedData.Path) {
                                Write-Log -Level Warning -Message "Invalid selection data"
                                return
                            }
                            
                            $targetPath = $SelectedData.Path
                            Write-Log -Level Info -Message "User selected: $($SelectedData.Action) -> $targetPath"
                            
                            # Handle exit
                            if ($targetPath -eq "/exit") {
                                Write-Log -Level Info -Message "Exit requested via menu"
                                $services.Navigation.RequestExit()
                                return
                            }
                            
                            # AI: Direct class method call - simple and clean
                            try {
                                $navigationResult = $services.Navigation.GoTo($targetPath)
                                if ($navigationResult) {
                                    Write-Log -Level Info -Message "Successfully navigated to $targetPath"
                                }
                                else {
                                    Write-Log -Level Warning -Message "Navigation returned false for $targetPath"
                                    if (Get-Command "Show-AlertDialog" -ErrorAction SilentlyContinue) {
                                        Show-AlertDialog -Title "Navigation Error" -Message "Failed to navigate to $($SelectedData.Action)"
                                    }
                                }
                            }
                            catch {
                                $errorMsg = "Navigation failed: $_"
                                Write-Log -Level Error -Message $errorMsg
                                if (Get-Command "Show-AlertDialog" -ErrorAction SilentlyContinue) {
                                    Show-AlertDialog -Title "Navigation Error" -Message "An error occurred while navigating: $_"
                                }
                            }
                        }
                    }
                }
                
                # Add menu to root panel
                & $rootPanel.AddChild -self $rootPanel -Child $navigationMenu
                $self._navigationMenu = $navigationMenu
                
                # AI: Force initial data processing to ensure menu displays correctly
                if ($navigationMenu.ProcessData) {
                    & $navigationMenu.ProcessData -self $navigationMenu
                }
                
                # AI: Debug log the menu state
                Write-Log -Level Debug -Message "NavigationMenu Data count: $(@($navigationMenu.Data).Count)"
                Write-Log -Level Debug -Message "NavigationMenu ProcessedData count: $(@($navigationMenu.ProcessedData).Count)"
                Write-Log -Level Debug -Message "NavigationMenu PageSize: $($navigationMenu.PageSize)"
                
                # Create status display
                $statusLabel = New-TuiLabel -Props @{
                    Text = "Loading data..."
                    Height = 1
                    Width = "100%"
                    Name = "StatusLabel"
                    ForegroundColor = "Gray"
                }
                & $rootPanel.AddChild -self $rootPanel -Child $statusLabel
                $self.Components.statusLabel = $statusLabel
                
                # AI: Create data refresh function
                $self.RefreshData = {
                    param($self)
                    
                    try {
                        $openTasks = 0
                        if ($global:Data -and $global:Data.Tasks) {
                        # AI: Handle both array and hashtable structures for Tasks
                        if ($global:Data.Tasks -is [hashtable]) {
                            $tasks = $global:Data.Tasks.Values
                            } else {
                            $tasks = $global:Data.Tasks
                        }
                        $openTasks = @($tasks | Where-Object { $_.Completed -eq $false }).Count
                    }
                        
                        if ($self.Components.statusLabel) {
                            $self.Components.statusLabel.Text = "Open Tasks: $openTasks"
                        }
                        
                        Request-TuiRefresh
                        Write-Log -Level Debug -Message "Dashboard data refreshed"
                    }
                    catch {
                        Write-Log -Level Error -Message "Dashboard data refresh failed: $_"
                    }
                }
                
                # Subscribe to data changes
                $subscriptionId = Subscribe-Event -EventName "Tasks.Changed" -Handler {
                    Write-Log -Level Debug -Message "Dashboard received Tasks.Changed event"
                    & $self.RefreshData -self $self
                }
                $self._subscriptions += $subscriptionId
                
                # Initial data load
                & $self.RefreshData -self $self
                
                # Set initial focus
                Request-Focus -Component $navigationMenu
                
                Write-Log -Level Info -Message "Dashboard initialization completed successfully"
            } -Component "Dashboard" -Context "Init"
        }
        
        HandleInput = {
            param($self, $key)
            
            if (-not $key) { return $false }
            
            return Invoke-WithErrorHandling -Component "Dashboard" -Context "HandleInput" -ScriptBlock {
                if (-not $self._navigationMenu) {
                    Write-Log -Level Warning -Message "Navigation menu not available"
                    return $false
                }
                
                # Handle number key shortcuts for quick navigation
                if ($key.KeyChar -match '[0-4]') {
                    $index = [int]$key.KeyChar
                    
                    # Get menu data for selection
                    $menuData = @($self._navigationMenu.Data)
                    
                    if ($index -eq 0) {
                        Write-Log -Level Info -Message "Exit via hotkey"
                        $self._services.Navigation.RequestExit()
                        return $true
                    }
                    
                    # Find and select the item with matching index
                    $selectedItem = $menuData | Where-Object { $_.Index -eq $index.ToString() }
                    if ($selectedItem -and $self._services -and $self._services.Navigation) {
                        # AI: Simple class method call for hotkey navigation
                        try {
                            $navigationResult = $self._services.Navigation.GoTo($selectedItem.Path)
                            if ($navigationResult) {
                                Write-Log -Level Info -Message "Hotkey navigation successful: $($selectedItem.Path)"
                                return $true
                            }
                        }
                        catch {
                            Write-Log -Level Error -Message "Hotkey navigation failed: $_"
                        }
                    }
                }
                
                # Pass other keys to the menu
                if ($self._navigationMenu.HandleInput) {
                    return & $self._navigationMenu.HandleInput -self $self._navigationMenu -key $key
                }
                
                return $false
            }
        }
        
        OnEnter = {
            param($self)
            Write-Log -Level Info -Message "Dashboard entered"
            
            # Ensure focus on menu and refresh stats in case data changed while away
            if ($self._navigationMenu) {
                Request-Focus -Component $self._navigationMenu
            }
            if ($self.RefreshData) {
                & $self.RefreshData -self $self
            }
            Request-TuiRefresh
        }
        
        OnExit = {
            param($self)
            Write-Log -Level Info -Message "Dashboard exiting - cleaning up"
            
            Invoke-WithErrorHandling -ScriptBlock {
                # AI: Clean event subscriptions
                if ($self._subscriptions -and @($self._subscriptions).Count -gt 0) {
                    foreach ($subId in $self._subscriptions) {
                        if ($subId) {
                            try {
                                Unsubscribe-Event -EventName "Tasks.Changed" -HandlerId $subId
                                Write-Log -Level Debug -Message "Unsubscribed from event: $subId"
                            }
                            catch {
                                Write-Log -Level Warning -Message "Failed to unsubscribe from event $subId : $_"
                            }
                        }
                    }
                    $self._subscriptions = @()
                }
            } -Component "Dashboard.OnExit" -Context "Cleanup"
        }
        
        Render = {
            param($self)
            # The panel and components handle their own rendering
        }
    }
    
    # AI: Ensure services are attached to screen for later use
    $screen._services = $Services
    
    return $screen
}

Export-ModuleMember -Function Get-DashboardScreen