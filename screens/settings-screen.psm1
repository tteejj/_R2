# Settings Screen - Placeholder
# AI: Minimal implementation to prevent navigation errors

function Get-SettingsScreen {
    param([hashtable]$Services)
    
    $screen = @{
        Name = "SettingsScreen"
        Components = @{}
        Children = @()
        _services = $Services
        Visible = $true
        ZIndex = 0
        
        Init = {
            param($self, $services)
            
            Write-Log -Level Info -Message "Settings Screen initialized"
            
            # Create simple panel
            $rootPanel = New-TuiStackPanel -Props @{
                X = 2
                Y = 2
                Width = 60
                Height = 20
                ShowBorder = $true
                Title = " Settings "
                Orientation = "Vertical"
                Spacing = 1
                Padding = 2
            }
            
            # Add placeholder content
            $label = New-TuiLabel -Props @{
                Text = "Settings Screen - Under Construction"
                Width = "100%"
            }
            
            $backLabel = New-TuiLabel -Props @{
                Text = "Press ESC to return to main menu"
                Width = "100%"
            }
            
            & $rootPanel.AddChild -self $rootPanel -Child $label
            & $rootPanel.AddChild -self $rootPanel -Child $backLabel
            
            $self.Components.rootPanel = $rootPanel
            $self.Children = @($rootPanel)
        }
        
        HandleInput = {
            param($self, $key)
            
            if ($key -and $key.Key -eq "Escape") {
                $self._services.Navigation.PopScreen()
                return $true
            }
            
            return $false
        }
        
        OnEnter = {
            param($self)
            Request-TuiRefresh
        }
        
        OnExit = {
            param($self)
            # Cleanup if needed
        }
        
        Render = {
            param($self)
            # Panel handles rendering
        }
    }
    
    return $screen
}

Export-ModuleMember -Function Get-SettingsScreen