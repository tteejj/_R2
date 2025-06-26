# Navigation Service Module for PMC Terminal v5
# Manages screen navigation stack and transitions
# AI: Implements Phase 4.2 of the class migration plan - Navigation Service

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Import base classes
using module '..\components\ui-classes.psm1'
using module '.\screen-factory.psm1'

# Import utilities for error handling
Import-Module -Name "$PSScriptRoot\..\utilities\error-handling.psm1" -Force

# NavigationService - Manages screen stack and navigation
class NavigationService {
    [System.Collections.Generic.Stack[Screen]] $ScreenStack
    [ScreenFactory] $ScreenFactory
    [Screen] $CurrentScreen
    [int] $MaxStackDepth = 10
    hidden [hashtable] $NavigationHistory = @{}
    
    NavigationService([hashtable]$services) {
        if ($null -eq $services) {
            throw [System.ArgumentNullException]::new("services", "Services cannot be null")
        }
        
        $this.ScreenStack = [System.Collections.Generic.Stack[Screen]]::new()
        $this.ScreenFactory = [ScreenFactory]::new($services)
        
        Write-Log -Level Info -Message "NavigationService initialized" -Component "NavigationService"
    }
    
    [void] PushScreen([string]$screenName) {
        $this.PushScreen($screenName, @{})
    }
    
    [void] PushScreen([string]$screenName, [hashtable]$parameters) {
        Invoke-WithErrorHandling -Component "NavigationService" -Context "PushScreen:$screenName" -ScriptBlock {
            if ([string]::IsNullOrWhiteSpace($screenName)) {
                throw [System.ArgumentException]::new("Screen name cannot be null or empty")
            }
            
            # Check stack depth limit
            if ($this.ScreenStack.Count -ge $this.MaxStackDepth) {
                throw [System.InvalidOperationException]::new(
                    "Navigation stack depth limit reached ($($this.MaxStackDepth))"
                )
            }
            
            Write-Log -Level Info -Message "Pushing screen: $screenName" -Component "NavigationService"
            
            # Clean up current screen if exists
            if ($null -ne $this.CurrentScreen) {
                try {
                    $this.CurrentScreen.Cleanup()
                }
                catch {
                    Write-Log -Level Warning -Message "Error during screen cleanup: $_" -Component "NavigationService"
                }
            }
            
            # Create new screen
            $newScreen = $this.ScreenFactory.CreateScreen($screenName, $parameters)
            
            # Initialize the new screen
            try {
                $newScreen.Initialize()
            }
            catch {
                Write-Log -Level Error -Message "Failed to initialize screen '$screenName': $_" -Component "NavigationService"
                throw
            }
            
            # Push to stack
            $this.ScreenStack.Push($newScreen)
            $this.CurrentScreen = $newScreen
            
            # Track navigation history
            $this.TrackNavigation($screenName, "Push")
            
            # Publish navigation event
            Publish-Event -EventName "Navigation.ScreenChanged" -Data @{
                Screen = $screenName
                Action = "Push"
                StackDepth = $this.ScreenStack.Count
                Parameters = $parameters
            }
            
            Write-Log -Level Debug -Message "Screen pushed successfully. Stack depth: $($this.ScreenStack.Count)" -Component "NavigationService"
        }
    }
    
    [Screen] PopScreen() {
        return Invoke-WithErrorHandling -Component "NavigationService" -Context "PopScreen" -ScriptBlock {
            if ($this.ScreenStack.Count -le 1) {
                Write-Log -Level Warning -Message "Cannot pop last screen from stack" -Component "NavigationService"
                return $null
            }
            
            # Remove current screen
            $poppedScreen = $this.ScreenStack.Pop()
            $screenName = $poppedScreen.Name
            
            Write-Log -Level Info -Message "Popping screen: $screenName" -Component "NavigationService"
            
            # Clean up popped screen
            try {
                $poppedScreen.Cleanup()
            }
            catch {
                Write-Log -Level Warning -Message "Error during screen cleanup: $_" -Component "NavigationService"
            }
            
            # Set new current screen
            if ($this.ScreenStack.Count -gt 0) {
                $this.CurrentScreen = $this.ScreenStack.Peek()
                
                # Re-initialize the revealed screen
                try {
                    $this.CurrentScreen.Initialize()
                }
                catch {
                    Write-Log -Level Warning -Message "Error re-initializing screen: $_" -Component "NavigationService"
                }
            }
            else {
                $this.CurrentScreen = $null
            }
            
            # Track navigation history
            $this.TrackNavigation($screenName, "Pop")
            
            # Publish navigation event
            Publish-Event -EventName "Navigation.ScreenChanged" -Data @{
                Screen = if ($null -ne $this.CurrentScreen) { $this.CurrentScreen.Name } else { "None" }
                Action = "Pop"
                StackDepth = $this.ScreenStack.Count
                PoppedScreen = $screenName
            }
            
            Write-Log -Level Debug -Message "Screen popped successfully. Stack depth: $($this.ScreenStack.Count)" -Component "NavigationService"
            
            return $poppedScreen
        }
    }
    
    [void] ReplaceScreen([string]$screenName) {
        $this.ReplaceScreen($screenName, @{})
    }
    
    [void] ReplaceScreen([string]$screenName, [hashtable]$parameters) {
        Invoke-WithErrorHandling -Component "NavigationService" -Context "ReplaceScreen:$screenName" -ScriptBlock {
            if ($this.ScreenStack.Count -eq 0) {
                # If stack is empty, just push
                $this.PushScreen($screenName, $parameters)
                return
            }
            
            Write-Log -Level Info -Message "Replacing current screen with: $screenName" -Component "NavigationService"
            
            # Remove current screen without re-initializing previous
            $oldScreen = $this.ScreenStack.Pop()
            
            try {
                $oldScreen.Cleanup()
            }
            catch {
                Write-Log -Level Warning -Message "Error during screen cleanup: $_" -Component "NavigationService"
            }
            
            # Push new screen
            $newScreen = $this.ScreenFactory.CreateScreen($screenName, $parameters)
            $newScreen.Initialize()
            
            $this.ScreenStack.Push($newScreen)
            $this.CurrentScreen = $newScreen
            
            # Track navigation history
            $this.TrackNavigation($screenName, "Replace")
            
            # Publish navigation event
            Publish-Event -EventName "Navigation.ScreenChanged" -Data @{
                Screen = $screenName
                Action = "Replace"
                StackDepth = $this.ScreenStack.Count
                ReplacedScreen = $oldScreen.Name
                Parameters = $parameters
            }
        }
    }
    
    [void] NavigateToRoot() {
        Invoke-WithErrorHandling -Component "NavigationService" -Context "NavigateToRoot" -ScriptBlock {
            Write-Log -Level Info -Message "Navigating to root screen" -Component "NavigationService"
            
            # Clean up all screens except the first
            while ($this.ScreenStack.Count -gt 1) {
                $screen = $this.ScreenStack.Pop()
                try {
                    $screen.Cleanup()
                }
                catch {
                    Write-Log -Level Warning -Message "Error during screen cleanup: $_" -Component "NavigationService"
                }
            }
            
            # Re-initialize root screen
            if ($this.ScreenStack.Count -gt 0) {
                $this.CurrentScreen = $this.ScreenStack.Peek()
                $this.CurrentScreen.Initialize()
            }
            
            # Publish navigation event
            Publish-Event -EventName "Navigation.ScreenChanged" -Data @{
                Screen = if ($null -ne $this.CurrentScreen) { $this.CurrentScreen.Name } else { "None" }
                Action = "NavigateToRoot"
                StackDepth = $this.ScreenStack.Count
            }
        }
    }
    
    [void] ClearStack() {
        Write-Log -Level Info -Message "Clearing navigation stack" -Component "NavigationService"
        
        # Clean up all screens
        while ($this.ScreenStack.Count -gt 0) {
            $screen = $this.ScreenStack.Pop()
            try {
                $screen.Cleanup()
            }
            catch {
                Write-Log -Level Warning -Message "Error during screen cleanup: $_" -Component "NavigationService"
            }
        }
        
        $this.CurrentScreen = $null
        $this.NavigationHistory.Clear()
        
        # Publish navigation event
        Publish-Event -EventName "Navigation.StackCleared"
    }
    
    [Screen] GetCurrentScreen() {
        return $this.CurrentScreen
    }
    
    [string] GetCurrentScreenName() {
        if ($null -ne $this.CurrentScreen) {
            return $this.CurrentScreen.Name
        }
        return ""
    }
    
    [int] GetStackDepth() {
        return $this.ScreenStack.Count
    }
    
    [string[]] GetNavigationStack() {
        $stack = @()
        foreach ($screen in $this.ScreenStack) {
            $stack += $screen.Name
        }
        return $stack
    }
    
    [bool] CanGoBack() {
        return $this.ScreenStack.Count -gt 1
    }
    
    # AI: Track navigation history for analytics
    hidden [void] TrackNavigation([string]$screenName, [string]$action) {
        $timestamp = [DateTime]::Now
        
        if (-not $this.NavigationHistory.ContainsKey($screenName)) {
            $this.NavigationHistory[$screenName] = @{
                FirstVisit = $timestamp
                LastVisit = $timestamp
                VisitCount = 0
                Actions = @()
            }
        }
        
        $history = $this.NavigationHistory[$screenName]
        $history.LastVisit = $timestamp
        $history.VisitCount++
        $history.Actions += @{
            Action = $action
            Timestamp = $timestamp
        }
        
        # Limit action history to last 100 entries
        if ($history.Actions.Count -gt 100) {
            $history.Actions = $history.Actions[-100..-1]
        }
    }
    
    [hashtable] GetNavigationStatistics() {
        $stats = @{
            TotalScreens = $this.NavigationHistory.Count
            TotalNavigations = 0
            MostVisited = @()
        }
        
        foreach ($screen in $this.NavigationHistory.Keys) {
            $stats.TotalNavigations += $this.NavigationHistory[$screen].VisitCount
        }
        
        # Find most visited screens
        $stats.MostVisited = $this.NavigationHistory.GetEnumerator() | 
            Sort-Object -Property { $_.Value.VisitCount } -Descending |
            Select-Object -First 5 |
            ForEach-Object {
                @{
                    Screen = $_.Key
                    VisitCount = $_.Value.VisitCount
                    LastVisit = $_.Value.LastVisit
                }
            }
        
        return $stats
    }
    
    # AI: Added GoTo method for compatibility with dashboard navigation expectations
    [bool] GoTo([string]$path) {
        return $this.GoTo($path, @{})
    }
    
    [bool] GoTo([string]$path, [hashtable]$parameters) {
        return Invoke-WithErrorHandling -Component "NavigationService" -Context "GoTo:$path" -ScriptBlock {
            Write-Log -Level Info -Message "Navigating to path: $path" -Component "NavigationService"
            
            # Map paths to screen names
            $screenMap = @{
                "/tasks" = "TaskListScreen"
                "/projects" = "ProjectListScreen"
                "/reports" = "ReportsScreen"
                "/settings" = "SettingsScreen"
                "/dashboard" = "DashboardScreen"
                "/" = "DashboardScreen"
            }
            
            if (-not $screenMap.ContainsKey($path)) {
                Write-Log -Level Warning -Message "Unknown navigation path: $path" -Component "NavigationService"
                return $false
            }
            
            $screenName = $screenMap[$path]
            
            try {
                # Use PushScreen to navigate
                $this.PushScreen($screenName, $parameters)
                return $true
            }
            catch {
                Write-Log -Level Error -Message "Failed to navigate to $screenName : $_" -Component "NavigationService"
                return $false
            }
        }
    }
}

# Export all classes
Export-ModuleMember -Function * -Cmdlet * -Variable * -Alias *