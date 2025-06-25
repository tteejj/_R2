# UI Base Classes Module for PMC Terminal v5
# Provides the foundational class hierarchy for all UI components
# AI: Implements Phase 1.1 of the class migration plan - base UI element hierarchy

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Base UI Element - foundation for all visual components
class UIElement {
    [string] $Name
    [hashtable] $Style = @{}
    [bool] $Visible = $true
    [bool] $Enabled = $true
    
    UIElement([string]$name) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw [System.ArgumentException]::new("UIElement name cannot be null or empty")
        }
        $this.Name = $name
    }
    
    [string] Render() {
        throw [System.NotImplementedException]::new("Render() must be implemented by derived class")
    }
    
    # AI: Added for debugging and logging purposes
    [string] ToString() {
        return "$($this.GetType().Name): $($this.Name)"
    }
}

# Base Component - container that can hold child elements
class Component : UIElement {
    [object] $Parent
    [System.Collections.Generic.List[UIElement]] $Children
    
    Component([string]$name) : base($name) {
        $this.Children = [System.Collections.Generic.List[UIElement]]::new()
    }
    
    [void] AddChild([UIElement]$child) {
        if ($null -eq $child) {
            throw [System.ArgumentNullException]::new("child", "Cannot add null child to component")
        }
        
        # AI: Prevent circular references
        if ($child -eq $this) {
            throw [System.InvalidOperationException]::new("Component cannot be its own child")
        }
        
        $child.Parent = $this
        $this.Children.Add($child)
    }
    
    [void] RemoveChild([UIElement]$child) {
        if ($null -ne $child) {
            $child.Parent = $null
            [void]$this.Children.Remove($child)
        }
    }
    
    [void] RemoveAllChildren() {
        foreach ($child in $this.Children) {
            $child.Parent = $null
        }
        $this.Children.Clear()
    }
    
    # AI: Helper method to find child by name
    [UIElement] FindChildByName([string]$childName) {
        foreach ($child in $this.Children) {
            if ($child.Name -eq $childName) {
                return $child
            }
            # Recursive search if child is also a component
            if ($child -is [Component]) {
                $found = $child.FindChildByName($childName)
                if ($null -ne $found) {
                    return $found
                }
            }
        }
        return $null
    }
}

# Base Panel - rectangular area with position and dimensions
class Panel : Component {
    [int] $X
    [int] $Y
    [int] $Width
    [int] $Height
    [string] $Title = ""
    [bool] $ShowBorder = $true
    
    Panel([string]$name, [int]$x, [int]$y, [int]$width, [int]$height) : base($name) {
        # AI: Validate dimensions
        if ($width -le 0 -or $height -le 0) {
            throw [System.ArgumentException]::new("Panel width and height must be positive values")
        }
        if ($x -lt 0 -or $y -lt 0) {
            throw [System.ArgumentException]::new("Panel position cannot be negative")
        }
        
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = $height
    }
    
    # AI: Helper to check if a point is within the panel bounds
    [bool] ContainsPoint([int]$pointX, [int]$pointY) {
        return ($pointX -ge $this.X -and 
                $pointX -lt ($this.X + $this.Width) -and
                $pointY -ge $this.Y -and 
                $pointY -lt ($this.Y + $this.Height))
    }
    
    # AI: Get the inner content area (accounting for borders)
    [hashtable] GetContentArea() {
        $contentX = $this.X
        $contentY = $this.Y
        $contentWidth = $this.Width
        $contentHeight = $this.Height
        
        if ($this.ShowBorder) {
            $contentX += 1
            $contentY += 1
            $contentWidth -= 2
            $contentHeight -= 2
        }
        
        return @{
            X = $contentX
            Y = $contentY
            Width = $contentWidth
            Height = $contentHeight
        }
    }
}

# Base Screen - top-level container for a complete UI view
class Screen : UIElement {
    [hashtable] $Services
    [System.Collections.Generic.Dictionary[string, object]] $State
    [System.Collections.Generic.List[Panel]] $Panels
    hidden [System.Collections.Generic.List[string]] $EventSubscriptions
    
    Screen([string]$name, [hashtable]$services) : base($name) {
        if ($null -eq $services) {
            throw [System.ArgumentNullException]::new("services", "Services cannot be null")
        }
        
        # AI: Validate required services
        $requiredServices = @('Navigation', 'DataManager')
        foreach ($service in $requiredServices) {
            if (-not $services.ContainsKey($service)) {
                throw [System.ArgumentException]::new("services", "Required service '$service' not found")
            }
        }
        
        $this.Services = $services
        $this.State = [System.Collections.Generic.Dictionary[string, object]]::new()
        $this.Panels = [System.Collections.Generic.List[Panel]]::new()
        $this.EventSubscriptions = [System.Collections.Generic.List[string]]::new()
    }
    
    # Virtual method - override in derived classes
    [void] Initialize() {
        # AI: Base implementation logs initialization
        Write-Log -Level Debug -Message "Initializing screen: $($this.Name)" -Component $this.Name
    }
    
    # Virtual method - override in derived classes
    [void] Cleanup() {
        # AI: Unsubscribe from all events to prevent memory leaks
        foreach ($eventName in $this.EventSubscriptions) {
            try {
                Unregister-Event -SourceIdentifier $eventName -ErrorAction SilentlyContinue
            }
            catch {
                Write-Log -Level Warning -Message "Failed to unregister event: $eventName" -Component $this.Name
            }
        }
        $this.EventSubscriptions.Clear()
        
        # Clear panels
        $this.Panels.Clear()
        
        Write-Log -Level Debug -Message "Cleaned up screen: $($this.Name)" -Component $this.Name
    }
    
    # Virtual method - override in derived classes
    [void] HandleInput([ConsoleKeyInfo]$key) {
        # AI: Base implementation does nothing
    }
    
    # AI: Helper method for safe event subscription
    [void] SubscribeToEvent([string]$eventName, [scriptblock]$action) {
        if ([string]::IsNullOrWhiteSpace($eventName)) {
            throw [System.ArgumentException]::new("Event name cannot be null or empty")
        }
        if ($null -eq $action) {
            throw [System.ArgumentNullException]::new("action", "Event action cannot be null")
        }
        
        Register-EngineEvent -SourceIdentifier $eventName -Action $action
        $this.EventSubscriptions.Add($eventName)
    }
    
    # AI: Helper to add panel with validation
    [void] AddPanel([Panel]$panel) {
        if ($null -eq $panel) {
            throw [System.ArgumentNullException]::new("panel", "Cannot add null panel to screen")
        }
        $this.Panels.Add($panel)
    }
}

# Export all classes
Export-ModuleMember -Function * -Cmdlet * -Variable * -Alias *