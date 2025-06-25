# Screen Factory Service Module for PMC Terminal v5
# Factory pattern implementation for creating screen instances
# AI: Implements Phase 4.1 of the class migration plan - Screen Factory

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Import base classes
using module '..\components\ui-classes.psm1'

# Import screen classes
using module '..\screens\dashboard-screen-class.psm1'

# Import utilities for error handling
Import-Module -Name "$PSScriptRoot\..\utilities\error-handling.psm1" -Force

# ScreenFactory - Creates and manages screen instances
class ScreenFactory {
    [hashtable] $Services
    [hashtable] $ScreenTypes = @{}
    hidden [hashtable] $ScreenCache = @{}
    [bool] $EnableCaching = $false
    
    ScreenFactory([hashtable]$services) {
        if ($null -eq $services) {
            throw [System.ArgumentNullException]::new("services", "Services cannot be null")
        }
        
        $this.Services = $services
        $this.RegisterScreenTypes()
    }
    
    hidden [void] RegisterScreenTypes() {
        Write-Log -Level Debug -Message "Registering screen types" -Component "ScreenFactory"
        
        # Register all available screen types
        $this.ScreenTypes["DashboardScreen"] = [DashboardScreen]
        
        # AI: These screens will be implemented in subsequent phases
        # For now, we'll add placeholders that will be replaced
        
        # $this.ScreenTypes["TaskListScreen"] = [TaskListScreen]
        # $this.ScreenTypes["NewTaskScreen"] = [NewTaskScreen]
        # $this.ScreenTypes["EditTaskScreen"] = [EditTaskScreen]
        # $this.ScreenTypes["ProjectListScreen"] = [ProjectListScreen]
        # $this.ScreenTypes["SettingsScreen"] = [SettingsScreen]
        # $this.ScreenTypes["FilterScreen"] = [FilterScreen]
        
        Write-Log -Level Info -Message "Registered $($this.ScreenTypes.Count) screen types" -Component "ScreenFactory"
    }
    
    [Screen] CreateScreen([string]$screenName) {
        return $this.CreateScreen($screenName, @{})
    }
    
    [Screen] CreateScreen([string]$screenName, [hashtable]$parameters) {
        return Invoke-WithErrorHandling -Component "ScreenFactory" -Context "CreateScreen:$screenName" -ScriptBlock {
            if ([string]::IsNullOrWhiteSpace($screenName)) {
                throw [System.ArgumentException]::new("Screen name cannot be null or empty")
            }
            
            # Check cache first if enabled
            if ($this.EnableCaching -and $this.ScreenCache.ContainsKey($screenName)) {
                Write-Log -Level Debug -Message "Returning cached screen: $screenName" -Component "ScreenFactory"
                $cachedScreen = $this.ScreenCache[$screenName]
                
                # Update parameters in cached screen
                foreach ($key in $parameters.Keys) {
                    $cachedScreen.State[$key] = $parameters[$key]
                }
                
                return $cachedScreen
            }
            
            # Validate screen type exists
            if (-not $this.ScreenTypes.ContainsKey($screenName)) {
                $availableScreens = $this.ScreenTypes.Keys -join ", "
                throw [System.InvalidOperationException]::new(
                    "Unknown screen type: $screenName. Available screens: $availableScreens"
                )
            }
            
            Write-Log -Level Debug -Message "Creating new screen instance: $screenName" -Component "ScreenFactory"
            
            # Create new screen instance
            $screenType = $this.ScreenTypes[$screenName]
            $screen = $screenType::new($this.Services)
            
            # Apply initial parameters
            if ($null -ne $parameters -and $parameters.Count -gt 0) {
                foreach ($key in $parameters.Keys) {
                    $screen.State[$key] = $parameters[$key]
                }
                Write-Log -Level Debug -Message "Applied $($parameters.Count) parameters to screen" -Component "ScreenFactory"
            }
            
            # Cache if enabled
            if ($this.EnableCaching) {
                $this.ScreenCache[$screenName] = $screen
                Write-Log -Level Debug -Message "Cached screen: $screenName" -Component "ScreenFactory"
            }
            
            return $screen
        }
    }
    
    [void] RegisterScreen([string]$screenName, [type]$screenType) {
        if ([string]::IsNullOrWhiteSpace($screenName)) {
            throw [System.ArgumentException]::new("Screen name cannot be null or empty")
        }
        
        if ($null -eq $screenType) {
            throw [System.ArgumentNullException]::new("screenType", "Screen type cannot be null")
        }
        
        # Validate the type inherits from Screen
        if (-not $screenType.IsSubclassOf([Screen])) {
            throw [System.ArgumentException]::new(
                "Screen type must inherit from Screen class"
            )
        }
        
        $this.ScreenTypes[$screenName] = $screenType
        Write-Log -Level Info -Message "Registered screen type: $screenName" -Component "ScreenFactory"
        
        # Clear cache for this screen if caching is enabled
        if ($this.EnableCaching -and $this.ScreenCache.ContainsKey($screenName)) {
            $this.ScreenCache.Remove($screenName)
        }
    }
    
    [void] UnregisterScreen([string]$screenName) {
        if ($this.ScreenTypes.ContainsKey($screenName)) {
            $this.ScreenTypes.Remove($screenName)
            Write-Log -Level Info -Message "Unregistered screen type: $screenName" -Component "ScreenFactory"
            
            # Clear cache
            if ($this.ScreenCache.ContainsKey($screenName)) {
                $this.ScreenCache.Remove($screenName)
            }
        }
    }
    
    [string[]] GetRegisteredScreens() {
        return $this.ScreenTypes.Keys | Sort-Object
    }
    
    [bool] IsScreenRegistered([string]$screenName) {
        return $this.ScreenTypes.ContainsKey($screenName)
    }
    
    [void] ClearCache() {
        if ($this.EnableCaching) {
            $count = $this.ScreenCache.Count
            $this.ScreenCache.Clear()
            Write-Log -Level Info -Message "Cleared $count cached screens" -Component "ScreenFactory"
        }
    }
    
    [void] ClearCacheForScreen([string]$screenName) {
        if ($this.EnableCaching -and $this.ScreenCache.ContainsKey($screenName)) {
            $this.ScreenCache.Remove($screenName)
            Write-Log -Level Debug -Message "Cleared cache for screen: $screenName" -Component "ScreenFactory"
        }
    }
}

# Export all classes
Export-ModuleMember -Function * -Cmdlet * -Variable * -Alias *