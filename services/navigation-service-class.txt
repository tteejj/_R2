# Navigation Service Class Implementation
# Service-oriented navigation with proper error handling

using namespace System.Collections.Generic

# Import utilities
Import-Module "$PSScriptRoot\..\utilities\exceptions.psm1" -Force
Import-Module "$PSScriptRoot\..\utilities\logging.psm1" -Force
Import-Module "$PSScriptRoot\..\utilities\events.psm1" -Force

# Screen Factory Class
class ScreenFactory {
    [hashtable] $Services
    [Dictionary[string, type]] $ScreenTypes
    
    ScreenFactory([hashtable]$services) {
        if ($null -eq $services) {
            throw [System.ArgumentNullException]::new("services", "Services cannot be null")
        }
        $this.Services = $services
        $this.ScreenTypes = [Dictionary[string, type]]::new()
        $this.RegisterDefaultScreens()
    }
    
    hidden [void] RegisterDefaultScreens() {
        # Register known screen types
        # These will be updated as screens are migrated to classes
        $this.ScreenTypes["DashboardScreen"] = [DashboardScreen]
        # Add more as they're converted to classes
    }
    
    [void] RegisterScreen([string]$name, [type]$screenType) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw [System.ArgumentException]::new("Screen name cannot be null or empty")
        }
        if ($null -eq $screenType) {
            throw [System.ArgumentNullException]::new("screenType", "Screen type cannot be null")
        }
        $this.ScreenTypes[$name] = $screenType
    }
    
    [object] CreateScreen([string]$screenName) {
        if (-not $this.ScreenTypes.ContainsKey($screenName)) {
            # Fall back to legacy screen creation if available
            if (Get-Command -Name "Get-$screenName" -ErrorAction SilentlyContinue) {
                Write-Log -Level Info -Message "Creating legacy screen: $screenName"
                return & "Get-$screenName" -Services $this.Services
            }
            throw [System.InvalidOperationException]::new("Unknown screen type: $screenName")
        }
        
        $screenType = $this.ScreenTypes[$screenName]
        
        # Create instance based on whether it's a class or hashtable-based screen
        if ($screenType -is [type]) {
            Write-Log -Level Debug -Message "Creating class-based screen: $screenName"
            return $screenType::new($this.Services)
        } else {
            Write-Log -Level Debug -Message "Creating hashtable-based screen: $screenName"
            return & $screenType -Services $this.Services
        }
    }
}

# Navigation Service Class
class NavigationService {
    [Stack[object]] $ScreenStack
    [object] $CurrentScreen
    [ScreenFactory] $ScreenFactory
    [hashtable] $Services
    [bool] $ExitRequested = $false
    
    NavigationService([hashtable]$services) {
        if ($null -eq $services) {
            throw [System.ArgumentNullException]::new("services", "Services cannot be null")
        }
        $this.Services = $services
        $this.ScreenStack = [Stack[object]]::new()
        $this.ScreenFactory = [ScreenFactory]::new($services)
    }
    
    [void] PushScreen([string]$screenName) {
        $this.PushScreen($screenName, @{})
    }
    
    [void] PushScreen([string]$screenName, [hashtable]$parameters) {
        Invoke-ClassMethod -ClassName "NavigationService" -MethodName "PushScreen" -ScriptBlock {
            Write-Log -Level Info -Message "Pushing screen: $screenName"
            
            # Create the new screen
            $newScreen = $this.ScreenFactory.CreateScreen($screenName)
            
            # Handle current screen exit
            if ($null -ne $this.CurrentScreen) {
                $this.CallScreenMethod($this.CurrentScreen, "OnExit")
                $this.ScreenStack.Push($this.CurrentScreen)
            }
            
            # Set new screen as current
            $this.CurrentScreen = $newScreen
            
            # Pass parameters to screen
            if ($parameters.Count -gt 0) {
                if ($newScreen -is [Screen]) {
                    # Class-based screen
                    foreach ($key in $parameters.Keys) {
                        $newScreen.State[$key] = $parameters[$key]
                    }
                } else {
                    # Hashtable-based screen
                    foreach ($key in $parameters.Keys) {
                        $newScreen.State[$key] = $parameters[$key]
                    }
                }
            }
            
            # Initialize the new screen
            $this.CallScreenMethod($newScreen, "Init", @{services = $this.Services})
            
            # Call OnEnter if available
            $this.CallScreenMethod($newScreen, "OnEnter")
            
            # Update TUI state
            if ($global:TuiState) {
                $global:TuiState.CurrentScreen = $newScreen
                Request-TuiRefresh
            }
            
            # Publish event
            Publish-Event -EventName "Navigation.ScreenPushed" -Data @{
                ScreenName = $screenName
                Parameters = $parameters
            }
        } -Data @{ ScreenName = $screenName }
    }
    
    [bool] PopScreen() {
        return Invoke-ClassMethod -ClassName "NavigationService" -MethodName "PopScreen" -ScriptBlock {
            if ($this.ScreenStack.Count -eq 0) {
                Write-Log -Level Warning -Message "Cannot pop screen: stack is empty"
                return $false
            }
            
            Write-Log -Level Info -Message "Popping screen"
            
            # Exit current screen
            if ($null -ne $this.CurrentScreen) {
                $this.CallScreenMethod($this.CurrentScreen, "OnExit")
            }
            
            # Pop previous screen
            $this.CurrentScreen = $this.ScreenStack.Pop()
            
            # Resume previous screen
            if ($null -ne $this.CurrentScreen) {
                $this.CallScreenMethod($this.CurrentScreen, "OnResume")
                
                # Update TUI state
                if ($global:TuiState) {
                    $global:TuiState.CurrentScreen = $this.CurrentScreen
                    Request-TuiRefresh
                }
            }
            
            # Publish event
            Publish-Event -EventName "Navigation.ScreenPopped" -Data @{
                CurrentScreen = if ($this.CurrentScreen) { $this.CurrentScreen.Name } else { $null }
            }
            
            return $true
        }
    }
    
    [void] GoTo([string]$path) {
        Invoke-ClassMethod -ClassName "NavigationService" -MethodName "GoTo" -ScriptBlock {
            Write-Log -Level Info -Message "Navigating to: $path"
            
            switch ($path) {
                "/tasks" { $this.PushScreen("TaskListScreen") }
                "/projects" { $this.PushScreen("ProjectListScreen") }
                "/reports" { $this.PushScreen("ReportsScreen") }
                "/settings" { $this.PushScreen("SettingsScreen") }
                "/exit" { $this.RequestExit() }
                default { 
                    Write-Log -Level Warning -Message "Unknown navigation path: $path"
                    throw [System.InvalidOperationException]::new("Unknown navigation path: $path")
                }
            }
        } -Data @{ Path = $path }
    }
    
    [void] RequestExit() {
        Write-Log -Level Info -Message "Exit requested"
        $this.ExitRequested = $true
        
        # Stop TUI if available
        if (Get-Command -Name "Stop-TuiEngine" -ErrorAction SilentlyContinue) {
            Stop-TuiEngine
        } elseif ($global:TuiState) {
            $global:TuiState.Running = $false
        }
        
        Publish-Event -EventName "Navigation.ExitRequested"
    }
    
    [object] GetCurrentScreen() {
        return $this.CurrentScreen
    }
    
    [bool] CanGoBack() {
        return $this.ScreenStack.Count -gt 0
    }
    
    hidden [void] CallScreenMethod([object]$screen, [string]$methodName) {
        $this.CallScreenMethod($screen, $methodName, @{})
    }
    
    hidden [void] CallScreenMethod([object]$screen, [string]$methodName, [hashtable]$parameters) {
        if ($null -eq $screen) { return }
        
        try {
            if ($screen -is [Screen]) {
                # Class-based screen
                $method = $screen.GetType().GetMethod($methodName)
                if ($null -ne $method) {
                    if ($parameters.Count -gt 0) {
                        $method.Invoke($screen, @($parameters))
                    } else {
                        $method.Invoke($screen, $null)
                    }
                }
            } else {
                # Hashtable-based screen
                if ($screen.$methodName) {
                    if ($parameters.Count -gt 0) {
                        & $screen.$methodName -self $screen @parameters
                    } else {
                        & $screen.$methodName -self $screen
                    }
                }
            }
        }
        catch {
            Write-Log -Level Warning -Message "Error calling $methodName on screen: $_"
        }
    }
}

# Export classes and any helper functions
Export-ModuleMember -Function * -Cmdlet * -Variable * -Alias *