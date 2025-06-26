# Dashboard Screen - Fixed for Service-Oriented Architecture
# Displays main menu with proper navigation service integration

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Import base classes
using module '..\components\ui-classes.psm1'

# Import utilities
Import-Module -Name "$PSScriptRoot\..\utilities\error-handling.psm1" -Force

# DashboardScreen class - Main menu screen
class DashboardScreen : Screen {
    [Panel] $MainPanel
    [Component] $MenuTable
    [Component] $StatsLabel
    hidden [array] $MenuItems
    hidden [array] $EventSubscriptions = @()
    
    DashboardScreen([hashtable]$services) : base("DashboardScreen", $services) {
        # AI: Initialize menu items in constructor
        $this.MenuItems = @(
            @{ Index = "1"; Action = "View Tasks"; Path = "/tasks" }
            @{ Index = "2"; Action = "View Projects"; Path = "/projects" }
            @{ Index = "3"; Action = "Reports"; Path = "/reports" }
            @{ Index = "4"; Action = "Settings"; Path = "/settings" }
            @{ Index = "0"; Action = "Exit"; Path = "/exit" }
        )
    }
    
    [void] Initialize() {
        Invoke-WithErrorHandling -Component "DashboardScreen" -Context "Initialize" -ScriptBlock {
            Write-Log -Level Info -Message "Initializing Dashboard Screen" -Component "DashboardScreen"
            
            # Create main panel
            $this.MainPanel = [BorderPanel]::new("MainPanel", 2, 2, 80, 25)
            $this.MainPanel.Title = "PMC Terminal v5 - Dashboard"
            $this.MainPanel.ShowBorder = $true
            
            # Create menu table
            $this.MenuTable = [Table]::new("MenuTable")
            $this.MenuTable.ShowHeaders = $true
            $this.MenuTable.SetColumns(@(
                [TableColumn]::new("Index", "#", 5),
                [TableColumn]::new("Action", "Menu Option", 40)
            ))
            $this.MenuTable.SetData($this.MenuItems)
            
            # Add menu to panel
            $this.MainPanel.AddChild($this.MenuTable)
            $this.Panels.Add($this.MainPanel)
            
            # Create stats label
            $this.StatsLabel = [Component]::new("StatsLabel")
            $this.StatsLabel.Render = {
                param($self)
                $openTasks = 0
                if ($global:Data -and $global:Data.Tasks) {
                    $openTasks = @($global:Data.Tasks | Where-Object { -not $_.Completed }).Count
                }
                return "Open Tasks: $openTasks"
            }
            $this.MainPanel.AddChild($this.StatsLabel)
            
            # Subscribe to task changes
            $subId = Subscribe-Event -EventName "Tasks.Changed" -Handler {
                Write-Log -Level Debug -Message "Dashboard received Tasks.Changed event" -Component "DashboardScreen"
                # Just mark for refresh - actual data fetch happens during render
            } -Source "DashboardScreen"
            
            $this.EventSubscriptions += $subId
            
            Write-Log -Level Info -Message "Dashboard Screen initialized successfully" -Component "DashboardScreen"
        }
    }
    
    [void] Cleanup() {
        Invoke-WithErrorHandling -Component "DashboardScreen" -Context "Cleanup" -ScriptBlock {
            Write-Log -Level Info -Message "Cleaning up Dashboard Screen" -Component "DashboardScreen"
            
            # Unsubscribe from events
            foreach ($subId in $this.EventSubscriptions) {
                if ($subId) {
                    try {
                        Unsubscribe-Event -HandlerId $subId
                    }
                    catch {
                        Write-Log -Level Warning -Message "Failed to unsubscribe event: $_" -Component "DashboardScreen"
                    }
                }
            }
            $this.EventSubscriptions = @()
        }
    }
    
    [void] HandleInput([ConsoleKeyInfo]$key) {
        if ($null -eq $key) { return }
        
        Invoke-WithErrorHandling -Component "DashboardScreen" -Context "HandleInput" -ScriptBlock {
            # Handle number key shortcuts
            if ($key.KeyChar -match '[0-4]') {
                $index = [int]$key.KeyChar.ToString()
                
                if ($index -eq 0) {
                    Write-Log -Level Info -Message "Exit requested" -Component "DashboardScreen"
                    # AI: Signal application exit through event
                    Publish-Event -EventName "Application.Exit"
                    return
                }
                
                $selectedItem = $this.MenuItems | Where-Object { $_.Index -eq $index.ToString() }
                if ($selectedItem) {
                    $this.NavigateToPath($selectedItem.Path)
                }
                return
            }
            
            # Handle Enter key on selected item
            if ($key.Key -eq [ConsoleKey]::Enter -and $this.MenuTable.SelectedIndex -ge 0) {
                $selectedItem = $this.MenuTable.Data[$this.MenuTable.SelectedIndex]
                if ($selectedItem) {
                    $this.NavigateToPath($selectedItem.Path)
                }
                return
            }
            
            # Pass other keys to menu table for navigation
            if ($null -ne $this.MenuTable) {
                $this.MenuTable.HandleInput($key)
            }
        }
    }
    
    hidden [void] NavigateToPath([string]$path) {
        Write-Log -Level Info -Message "Navigating to: $path" -Component "DashboardScreen"
        
        if ($path -eq "/exit") {
            Publish-Event -EventName "Application.Exit"
            return
        }
        
        # AI: Use navigation service to change screens
        if ($this.Services.Navigation) {
            try {
                $result = $this.Services.Navigation.GoTo($path)
                if (-not $result) {
                    Write-Log -Level Warning -Message "Navigation failed to path: $path" -Component "DashboardScreen"
                }
            }
            catch {
                Write-Log -Level Error -Message "Navigation error: $_" -Component "DashboardScreen"
            }
        }
        else {
            Write-Log -Level Error -Message "Navigation service not available" -Component "DashboardScreen"
        }
    }
    
    [string] Render() {
        # The panels handle their own rendering
        return ""
    }
}

# Factory function for backward compatibility
function Get-DashboardScreen {
    param([hashtable]$Services)
    
    return [DashboardScreen]::new($Services)
}

Export-ModuleMember -Function Get-DashboardScreen