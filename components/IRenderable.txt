# IRenderable Base Class - Stable Component Pattern
# Provides robust error handling and consistent rendering for all UI components

using namespace System.Text

class IRenderable {
    [string]$_componentName
    [string]$_lastRenderOutput
    [DateTime]$_lastRenderTime
    [bool]$_renderCacheValid = $false
    [int]$_renderCount = 0
    [hashtable]$_renderMetrics = @{}
    
    # AI: Constructor requires component name for error tracking
    IRenderable([string]$componentName) {
        if ([string]::IsNullOrWhiteSpace($componentName)) {
            throw "Component name cannot be null or empty"
        }
        $this._componentName = $componentName
        $this._lastRenderTime = [DateTime]::MinValue
        $this._renderMetrics = @{
            TotalRenders = 0
            LastRenderDuration = 0
            AverageRenderDuration = 0
            ErrorCount = 0
            LastError = $null
        }
    }
    
    # Public render method - handles all error cases and metrics
    [string] Render() {
        $startTime = Get-Date
        $this._renderCount++
        $this._renderMetrics.TotalRenders++
        
        try {
            # Validate component state before rendering
            $validationResult = $this.ValidateRender()
            if (-not $validationResult) {
                $errorMsg = "Component validation failed"
                $this._renderMetrics.ErrorCount++
                $this._renderMetrics.LastError = $errorMsg
                return "[$($this._componentName)] Validation Error: Component not ready for rendering"
            }
            
            # Call the derived class implementation
            $output = $this._RenderContent()
            
            # Validate output
            if ($null -eq $output) {
                $output = ""
            }
            
            # Cache successful render
            $this._lastRenderOutput = $output
            $this._lastRenderTime = $startTime
            $this._renderCacheValid = $true
            
            # Update metrics
            $duration = ([DateTime]::Now - $startTime).TotalMilliseconds
            $this._renderMetrics.LastRenderDuration = $duration
            
            # Calculate average duration
            if ($this._renderMetrics.TotalRenders -gt 0) {
                $oldAvg = $this._renderMetrics.AverageRenderDuration
                $this._renderMetrics.AverageRenderDuration = 
                    (($oldAvg * ($this._renderMetrics.TotalRenders - 1)) + $duration) / $this._renderMetrics.TotalRenders
            }
            
            return $output
        }
        catch {
            $this._renderMetrics.ErrorCount++
            $this._renderMetrics.LastError = $_.Exception.Message
            $this._renderCacheValid = $false
            
            # Log error with full context
            if (Get-Command -Name "Write-Log" -ErrorAction SilentlyContinue) {
                Write-Log -Level Error -Message "Render error in component '$($this._componentName)': $($_.Exception.Message)" -Data @{
                    Component = $this._componentName
                    Context = "Render"
                    Exception = $_.Exception
                    StackTrace = $_.ScriptStackTrace
                    RenderCount = $this._renderCount
                    LastSuccessfulRender = $this._lastRenderTime
                }
            }
            
            # Return safe error display instead of throwing
            return "[$($this._componentName)] Render Error: $($_.Exception.Message)"
        }
    }
    
    # Abstract method - must be implemented by derived classes
    hidden [string] _RenderContent() {
        throw "Component '$($this._componentName)' must implement the _RenderContent() method"
    }
    
    # Virtual method - can be overridden for custom validation
    [bool] ValidateRender() {
        # Default validation - component name exists
        return -not [string]::IsNullOrWhiteSpace($this._componentName)
    }
    
    # Utility method to clear render cache
    [void] ClearRenderCache() {
        $this._renderCacheValid = $false
        $this._lastRenderOutput = ""
    }
    
    # Get component performance metrics
    [hashtable] GetRenderMetrics() {
        return $this._renderMetrics.Clone()
    }
    
    # Get component name
    [string] GetComponentName() {
        return $this._componentName
    }
    
    # Check if component has cached valid render output
    [bool] HasValidRenderCache() {
        return $this._renderCacheValid
    }
    
    # Get last successful render output (useful for fallback displays)
    [string] GetLastRenderOutput() {
        return if ($this._renderCacheValid) { $this._lastRenderOutput } else { "" }
    }
    
    # Force a fresh render (clears cache first)
    [string] ForceRender() {
        $this.ClearRenderCache()
        return $this.Render()
    }
    
    # AI: Safe method to check if rendering should be attempted
    [bool] ShouldRender() {
        # Override in derived classes for custom logic
        # Default: always attempt render unless validation fails
        return $this.ValidateRender()
    }
    
    # AI: Method to get component status for debugging
    [hashtable] GetComponentStatus() {
        return @{
            ComponentName = $this._componentName
            RenderCount = $this._renderCount
            LastRenderTime = $this._lastRenderTime
            HasValidCache = $this._renderCacheValid
            Metrics = $this.GetRenderMetrics()
            IsReady = $this.ValidateRender()
        }
    }
}

# AI: Error handling wrapper specifically for use with IRenderable components
function global:Invoke-WithErrorHandling {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Component,
        
        [Parameter(Mandatory = $true)]
        [string]$Context,
        
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter()]
        [hashtable]$AdditionalData = @{}
    )
    
    # Validate parameters
    if ([string]::IsNullOrWhiteSpace($Component)) {
        $Component = "Unknown"
    }
    if ([string]::IsNullOrWhiteSpace($Context)) {
        $Context = "Unknown"
    }
    
    try {
        # Execute the script block
        & $ScriptBlock
    }
    catch {
        # Create enriched error data
        $errorData = @{
            Component = $Component
            Context = $Context
            Error = $_
            Exception = $_.Exception
            ScriptStackTrace = $_.ScriptStackTrace
            Timestamp = Get-Date
        }
        
        # Merge additional data
        foreach ($key in $AdditionalData.Keys) {
            $errorData[$key] = $AdditionalData[$key]
        }
        
        # Log the error if logging is available
        if (Get-Command -Name "Write-Log" -ErrorAction SilentlyContinue) {
            Write-Log -Level Error -Message "Error in '$Component' during '$Context': $($_.Exception.Message)" -Data $errorData
        }
        
        # Re-throw the original exception
        throw
    }
}

# Export the base class and utility function
Export-ModuleMember -Function @('Invoke-WithErrorHandling')