# Dashboard Screen - Refactored for Service-Oriented Architecture
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
            
            Invoke-WithErrorHandling -Component "Dashboard.Init" -Context "Initialize" -ScriptBlock {
                # Defensive service validation
                if (-not $services) {
                    if ($self._services) {
                        $services = $self._services
                        Write-Log -Level Warning -Message "Dashboard Init: Using stored services"
                    }
                    else {
                        throw "No services available for dashboard initialization"
                    }
                }
                
                # Store services on screen instance
                $self._services = $services
                
                # Validate critical services exist
                if (-not $services.Navigation) {
                    throw "Navigation service is missing for dashboard"
                }
                
                Write-Log -Level Info -Message "Dashboard Init: Services validated successfully"
                
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
                    Text = "Use Arrow Keys or Number Keys to Navigate"
                    Height = 1
                    Width = "100%"
                }
                & $rootPanel.AddChild -self $rootPanel -Child $instructionLabel | Out-Null
                
                # Create menu data
                $menuItems = @(
                    @{ Index = "1"; Action = "View Tasks"; Path = "/tasks" }
                    @{ Index = "2"; Action = "View Projects"; Path = "/projects" }
                    @{ Index = "3"; Action = "Reports"; Path = "/reports" }
                    @{ Index = "4"; Action = "Settings"; Path = "/settings" }
                    @{ Index = "0"; Action = "Exit"; Path = "/exit" }
                )
                
                # Capture services for component callbacks
                $capturedServices = $services
                
                $navigationMenu = New-TuiDataTable -Props @{
                    Name = "navigationMenu"
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
                        
                        if (-not $SelectedData) {
                            Write-Log -Level Warning -Message "Dashboard: OnRowSelect called with null data"
                            return
                        }
                        
                        $path = $SelectedData.Path
                        if ([string]::IsNullOrWhiteSpace($path)) {
                            Write-Log -Level Warning -Message "Dashboard: No path in selected data"
                            return
                        }
                        
                        Write-Log -Level Info -Message "Dashboard: Navigating to $path"
                        
                        if ($path -eq "/exit") {
                            Stop-TuiEngine
                            return
                        }
                        
                        $capturedServices.Navigation.GoTo($path, $capturedServices)
                    }
                }
                
                & $navigationMenu.ProcessData -self $navigationMenu
                & $rootPanel.AddChild -self $rootPanel -Child $navigationMenu | Out-Null
                $self.Components.navigationMenu = $navigationMenu
                $self._navigationMenu = $navigationMenu
                
                # Add dynamic stats label
                $statsLabel = New-TuiLabel -Props @{
                    Name = "statsLabel"
                    Text = "Loading stats..."
                    Margin = @{ Top = 1 }
                    Width = "100%"
                    HorizontalAlignment = "Center"
                }
                & $rootPanel.AddChild -self $rootPanel -Child $statsLabel | Out-Null
                $self.Components.statsLabel = $statsLabel
                
                # Add status label at bottom
                $footerLabel = New-TuiLabel -Props @{
                    Text = "Press ESC to return to this menu from any screen"
                    Height = 1
                    Width = "100%"
                    Margin = @{ Top = 1 }
                }
                & $rootPanel.AddChild -self $rootPanel -Child $footerLabel | Out-Null
                
                # Helper function to refresh dynamic data on the dashboard
                $self.RefreshDashboardStats = {
                    param($self)
                    Invoke-WithErrorHandling -Component "Dashboard.RefreshStats" -Context "RefreshStats" -ScriptBlock {
                        $openTasks = 0
                        if ($global:Data -and $global:Data.Tasks) {
                            # Access the .Completed property of each [PmcTask] object
                            $openTasks = ($global:Data.Tasks.Where({ -not $_.Completed })).Count
                        }
                        $self.Components.statsLabel.Text = "Open Tasks: $openTasks"
                        Request-TuiRefresh
                    }
                }
                
                # Subscribe to data changes to keep the dashboard live
                $subscriptionId = Subscribe-Event -EventName "Tasks.Changed" -Handler {
                    Write-Log -Level Debug -Message "Dashboard received Tasks.Changed event"
                    & $self.RefreshDashboardStats -self $self
                } -Source "DashboardScreen"
                $self._subscriptions += $subscriptionId
                
                # Initial data load
                & $self.RefreshDashboardStats -self $self
                
                # Set initial focus
                Request-Focus -Component $navigationMenu
                
                Write-Log -Level Info -Message "Dashboard Init: Completed successfully"
            }
        }
        
        HandleInput = {
            param($self, $key)
            
            if (-not $key) { return $false }
            
            Invoke-WithErrorHandling -Component "Dashboard.HandleInput" -Context "HandleInput" -ScriptBlock {
                if (-not $self._navigationMenu) {
                    Write-Log -Level Warning -Message "Dashboard HandleInput: Navigation menu not available"
                    return $false
                }
                
                # Handle number key shortcuts
                if ($key.KeyChar -match '[0-4]') {
                    $index = [int]$key.KeyChar
                    
                    $menuData = @($self._navigationMenu.Data)
                    
                    if ($index -eq 0) {
                        Write-Log -Level Info -Message "Dashboard: Exit via hotkey"
                        Stop-TuiEngine
                        return $true
                    }
                    
                    $selectedItem = $menuData | Where-Object { $_.Index -eq $index.ToString() }
                    if ($selectedItem -and $self._services -and $self._services.Navigation) {
                        & $self._services.Navigation.GoTo -self $self._services.Navigation -Path $selectedItem.Path -Services $self._services
                        return $true
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
            Write-Log -Level Info -Message "Dashboard OnEnter"
            
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
            Write-Log -Level Info -Message "Dashboard OnExit: Cleaning up"
            
            Invoke-WithErrorHandling -Component "Dashboard.OnExit" -Context "Cleanup" -ScriptBlock {
                # Unsubscribe from all events to prevent memory leaks
                if ($self._subscriptions -and @($self._subscriptions).Count -gt 0) {
                    foreach ($subId in $self._subscriptions) {
                        if ($subId) {
                            try {
                                Unsubscribe-Event -HandlerId $subId
                                Write-Log -Level Debug -Message "Dashboard unsubscribed from event: $subId"
                            }
                            catch {
                                Write-Log -Level Warning -Message "Dashboard failed to unsubscribe from event $subId : $_"
                            }
                        }
                    }
                    $self._subscriptions = @()
                }
            }
        }
        
        Render = {
            param($self)
            # The panel and components handle their own rendering
        }
    }
    
    return $screen
}

Export-ModuleMember -Function Get-DashboardScreen