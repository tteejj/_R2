# Simple Test Screen - Basic test screen for development and debugging
# Provides a minimal screen implementation for testing the TUI framework

using module '..\modules\models.psm1'

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-SimpleTestScreen {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Services
    )
    
    Invoke-WithErrorHandling -Component "SimpleTestScreen.Factory" -Context "Creating Simple Test Screen" -ScriptBlock {
        # Validate services parameter
        if (-not $Services) {
            throw "Services parameter is required for simple test screen"
        }
        
        $screen = @{
            Name = "SimpleTestScreen"
            Components = @{}
            Children = @()
            _services = $Services
            Visible = $true
            ZIndex = 0
            
            Init = {
                param($self)
                
                Invoke-WithErrorHandling -Component "SimpleTestScreen.Init" -Context "Initializing Simple Test Screen" -ScriptBlock {
                    Write-Log -Level Info -Message "Simple Test Screen Init: Starting initialization"
                    
                    # Create root panel
                    $rootPanel = New-TuiStackPanel -Props @{
                        Name = "SimpleTestRoot"
                        X = 2
                        Y = 2
                        Width = [Math]::Max(60, ($global:TuiState.BufferWidth - 4))
                        Height = [Math]::Max(20, ($global:TuiState.BufferHeight - 4))
                        ShowBorder = $true
                        Title = " Simple Test Screen "
                        Orientation = "Vertical"
                        Spacing = 1
                        Padding = 2
                    }
                    
                    # Add test content
                    $welcomeLabel = New-TuiTextBlock -Props @{
                        Text = "This is a simple test screen for verifying the TUI framework."
                        Width = "100%"
                    }
                    
                    $instructionLabel = New-TuiTextBlock -Props @{
                        Text = "Press ESC to return to the main menu."
                        Width = "100%"
                        Margin = @{ Top = 2 }
                    }
                    
                    $statusLabel = New-TuiTextBlock -Props @{
                        Text = "Screen loaded successfully!"
                        Width = "100%"
                        Margin = @{ Top = 1 }
                    }
                    
                    & $rootPanel.AddChild -self $rootPanel -Child $welcomeLabel
                    & $rootPanel.AddChild -self $rootPanel -Child $instructionLabel
                    & $rootPanel.AddChild -self $rootPanel -Child $statusLabel
                    
                    # Store references
                    $self.Components.rootPanel = $rootPanel
                    $self.Children = @($rootPanel)
                    
                    Write-Log -Level Info -Message "Simple Test Screen Init: Completed successfully"
                }
            }
            
            HandleInput = {
                param($self, $key)
                
                if (-not $key) { return $false }
                
                Invoke-WithErrorHandling -Component "SimpleTestScreen.HandleInput" -Context "Handling user input" -ScriptBlock {
                    if ($key.Key -eq "Escape") {
                        & $self._services.Navigation.GoTo -self $self._services.Navigation -Path "/dashboard" -Services $self._services
                        return $true
                    }
                    
                    return $false
                }
            }
            
            OnEnter = {
                param($self)
                Write-Log -Level Info -Message "Simple Test Screen OnEnter"
                Request-TuiRefresh
            }
            
            OnExit = {
                param($self)
                Write-Log -Level Info -Message "Simple Test Screen OnExit: Cleaning up"
            }
            
            Render = {
                param($self)
                # The panel handles its own rendering
            }
        }
        
        return $screen
    }
}

Export-ModuleMember -Function Get-SimpleTestScreen