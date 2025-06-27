# Dashboard Screen - Fixed Parameter Binding Issues
# Displays dynamic data and uses direct service calls and eventing.

using module '..\modules\models.psm1'
using module '..\modules\exceptions.psm1'
using module '..\modules\logger.psm1'
using module '..\modules\event-system.psm1'
using module '..\modules\theme-manager.psm1'
using module '..\utilities\focus-manager.psm1'
using module '..\components\advanced-data-components.psm1'
using module '..\components\tui-components.psm1'
using module '..\layout\panels.psm1'

function Get-DashboardScreen {
    param([hashtable]$Services)
    
    $screen = @{
        Name = "DashboardScreen"
        Components = @{}
        Children = @()
        _subscriptions = @()
        _focusIndex = 0
        _services = $null
        Visible = $true
        ZIndex = 0
        
        Init = {
            param($self, $services)
            
            Invoke-WithErrorHandling -ScriptBlock {
                # AI: Simplified and robust services validation
                if (-not $services) {
                    throw "Services parameter is required for dashboard initialization"
                }
                
                # Store services on screen instance
                $self._services = $services
                
                # Validate critical services exist with detailed error reporting
                if (-not $services.Navigation) {
                    $availableServices = ($services.Keys | Sort-Object) -join ", "
                    throw "Navigation service is missing. Available services: $availableServices"
                }
                
                # AI: Fixed Write-Log call - use -Data instead of -Component
                Write-Log -Level Info -Message "Dashboard Init: Services validated successfully" -Data @{ Component = "Dashboard"; Context = "Init" }
                
                # Create simple root panel
                $rootPanel = New-TuiStackPanel -Props @{
                    X = 2
                    Y = 2
                    Width = [Math]::Max(60, ($global:TuiState.BufferWidth - 4))
                    Height = [Math]::Max(20, ($global:TuiState.BufferHeight - 4))
                    ShowBorder = $true
                    Title = " PMC Terminal v5 - Main Menu "
                    Orientation = "Vertical"
                    Spacing = 1
                    Padding = 2
                }
                
                # Store reference and add to children
                $self.Components.rootPanel = $rootPanel
                $self.Children = @($rootPanel)
                
                # Add instruction label
                $instructionLabel = New-TuiLabel -Props @{
                    Text = "Select an option using number keys (1-4) or use arrow keys and Enter"
                    X = 1
                    Y = 1
                    Width = 50
                    Height = 1
                    Name = "InstructionLabel"
                }
                $rootPanel.AddChild($instructionLabel)
                
                # Create main navigation menu items
                $menuItems = @(
                    @{ Index = "1"; Action = "Task Management"; Path = "/tasks" }
                    @{ Index = "2"; Action = "Project Management"; Path = "/projects" }
                    @{ Index = "3"; Action = "Settings"; Path = "/settings" }
                    @{ Index = "4"; Action = "Reports"; Path = "/reports" }
                    @{ Index = "0"; Action = "Exit Application"; Path = "/exit" }
                )
                
                # AI: Capture services for closure scope
                $capturedServices = $services
                
                # Create navigation menu component
                $navigationMenu = New-TuiDataTable -Props @{
                    Name = "NavigationMenu"
                    IsFocusable = $true
                    ShowBorder = $true
                    BorderStyle = "Double"
                    Title = " Main Menu "
                    Height = [Math]::Min(15, $menuItems.Count + 4)
                    Width = 50
                    Columns = @(
                        @{ Name = "Index"; Width = 5; Align = "Center" }
                        @{ Name = "Action"; Width = 40; Align = "Left" }
                    )
                    Data = $menuItems
                    OnRowSelect = {
                        param($SelectedData, $SelectedIndex)
                        
                        Invoke-WithErrorHandling -ScriptBlock {
                            # AI: Robust parameter validation
                            if (-not $SelectedData) {
                                Write-Log -Level Warning -Message "Dashboard: OnRowSelect called with null data" -Data @{ Component = "Dashboard.OnRowSelect" }
                                return
                            }
                            
                            $path = $SelectedData.Path
                            if ([string]::IsNullOrWhiteSpace($path)) {
                                Write-Log -Level Warning -Message "Dashboard: No path in selected data" -Data @{ Component = "Dashboard.OnRowSelect" }
                                return
                            }
                            
                            Write-Log -Level Info -Message "Dashboard: Navigating to $path" -Data @{ Component = "Dashboard.OnRowSelect"; Path = $path }
                            
                            if ($path -eq "/exit") {
                                Stop-TuiEngine
                                return
                            }
                            
                            # AI: Simplified services validation
                            if (-not $capturedServices -or -not $capturedServices.Navigation -or -not $capturedServices.Navigation.GoTo) {
                                $errorMsg = "Navigation service not properly initialized"
                                Write-Log -Level Error -Message $errorMsg -Data @{ Component = "Dashboard.OnRowSelect" }
                                throw $errorMsg
                            }
                            
                            # Navigate to selected screen
                            & $capturedServices.Navigation.GoTo -self $capturedServices.Navigation -Path $path -Services $capturedServices
                        } -Component "Dashboard.OnRowSelect" -Context "Navigation"
                    }
                }
                
                # Add navigation menu to root panel
                $rootPanel.AddChild($navigationMenu)
                $self._navigationMenu = $navigationMenu
                
                # Add stats display
                $statsLabel = New-TuiLabel -Props @{
                    Text = "Loading statistics..."
                    X = 1
                    Y = 20
                    Width = 50
                    Height = 1
                    Name = "StatsLabel"
                    ForegroundColor = "Gray"
                }
                
                $rootPanel.AddChild($statsLabel)
                $self.Components.statsLabel = $statsLabel
                
                # Create refresh function
                $self.RefreshDashboardStats = {
                    param($self)
                    
                    Invoke-WithErrorHandling -ScriptBlock {
                        # AI: Robust data access with null checks
                        $openTasks = 0
                        if ($global:Data -and $global:Data.Tasks) {
                            $openTasks = ($global:Data.Tasks.Where({ -not $_.Completed })).Count
                        }
                        
                        if ($self.Components -and $self.Components.statsLabel) {
                            $self.Components.statsLabel.Text = "Open Tasks: $openTasks"
                        }
                        else {
                            Write-Log -Level Warning -Message "Dashboard RefreshStats: statsLabel component not available" -Data @{ Component = "Dashboard.RefreshStats" }
                        }
                        
                        Request-TuiRefresh
                    } -Component "Dashboard.RefreshStats" -Context "RefreshStats"
                }
                
                # Subscribe to data changes to keep the dashboard live
                $subscriptionId = Subscribe-Event -EventName "Tasks.Changed" -Handler {
                    Write-Log -Level Debug -Message "Dashboard received Tasks.Changed event" -Data @{ Component = "Dashboard" }
                    & $self.RefreshDashboardStats -self $self
                } -Source "DashboardScreen"
                $self._subscriptions += $subscriptionId
                
                # Initial data load
                & $self.RefreshDashboardStats -self $self
                
                # Set initial focus
                Request-Focus -Component $navigationMenu
                
                Write-Log -Level Info -Message "Dashboard Init: Completed successfully" -Data @{ Component = "Dashboard.Init" }
            } -Component "Dashboard" -Context "Init"
        }
        
        HandleInput = {
            param($self, $key)
            
            if (-not $key) { return $false }
            
            Invoke-WithErrorHandling -ScriptBlock {
                if (-not $self._navigationMenu) {
                    # AI: Fixed Write-Log call - use -Data instead of -Component
                    Write-Log -Level Warning -Message "Dashboard HandleInput: Navigation menu not available" -Data @{ Component = "Dashboard"; Context = "HandleInput" }
                    return $false
                }
                
                # Handle number key shortcuts for quick navigation
                if ($key.KeyChar -match '[0-4]') {
                    $index = [int]$key.KeyChar
                    
                    # Get menu data for selection
                    $menuData = @($self._navigationMenu.Data)
                    
                    if ($index -eq 0) {
                        Write-Log -Level Info -Message "Dashboard: Exit via hotkey" -Data @{ Component = "Dashboard.HandleInput" }
                        Stop-TuiEngine
                        return $true
                    }
                    
                    # Find and select the item with matching index
                    $selectedItem = $menuData | Where-Object { $_.Index -eq $index.ToString() }
                    if ($selectedItem -and $self._services -and $self._services.Navigation) {
                        & $self._services.Navigation.GoTo -self $self._services -Path $selectedItem.Path -Services $self._services
                        return $true
                    }
                }
                
                # Pass other keys to the menu
                if ($self._navigationMenu.HandleInput) {
                    return & $self._navigationMenu.HandleInput -self $self._navigationMenu -key $key
                }
                
                return $false
            } -Component "Dashboard" -Context "HandleInput"
        }
        
        OnEnter = {
            param($self)
            Write-Log -Level Info -Message "Dashboard OnEnter" -Data @{ Component = "Dashboard.OnEnter" }
            
            # Ensure focus on menu and refresh stats in case data changed while away
            if ($self._navigationMenu) {
                Request-Focus -Component $self._navigationMenu
            }
            if ($self.RefreshDashboardStats) {
                & $self.RefreshDashboardStats -self $self
            }
            Request-TuiRefresh
        }
        
        OnExit = {
            param($self)
            Write-Log -Level Info -Message "Dashboard OnExit: Cleaning up" -Data @{ Component = "Dashboard.OnExit" }
            
            Invoke-WithErrorHandling -ScriptBlock {
                # AI: Safe event cleanup with proper error handling
                if ($self._subscriptions -and @($self._subscriptions).Count -gt 0) {
                    foreach ($subId in $self._subscriptions) {
                        if ($subId) {
                            try {
                                Unsubscribe-Event -HandlerId $subId
                                Write-Log -Level Debug -Message "Dashboard unsubscribed from event: $subId" -Data @{ Component = "Dashboard.OnExit"; SubscriptionId = $subId }
                            }
                            catch {
                                Write-Log -Level Warning -Message "Dashboard failed to unsubscribe from event $subId : $_" -Data @{ Component = "Dashboard.OnExit"; SubscriptionId = $subId; Error = $_ }
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
    
    return $screen
}

Export-ModuleMember -Function Get-DashboardScreen