# FILE: services/keybindings.psm1
# PURPOSE: Centralizes keybinding logic to make them configurable and declarative.

function Initialize-KeybindingService {
    param(
        [hashtable]$CustomBindings = @{},
        [bool]$EnableChords = $false  # For future multi-key sequences
    )
    Invoke-WithErrorHandling -Component "KeybindingService.Initialize" -Context "Keybinding service initialization" -ScriptBlock {
        # Default keybindings - can be overridden
        $defaultKeyMap = @{
            # Application-level
            "App.Quit" = @{ Key = 'Q'; Modifiers = @() }
            "App.ForceQuit" = @{ Key = 'Q'; Modifiers = @('Ctrl') }
            "App.Back" = @{ Key = [ConsoleKey]::Escape; Modifiers = @() }
            "App.Refresh" = @{ Key = 'R'; Modifiers = @() }
            "App.DebugLog" = @{ Key = [ConsoleKey]::F12; Modifiers = @() }
            "App.Help" = @{ Key = [ConsoleKey]::F1; Modifiers = @() }
            
            # List operations
            "List.New" = @{ Key = 'N'; Modifiers = @() }
            "List.Edit" = @{ Key = 'E'; Modifiers = @() }
            "List.Delete" = @{ Key = 'D'; Modifiers = @() }
            "List.Toggle" = @{ Key = [ConsoleKey]::Spacebar; Modifiers = @() }
            "List.SelectAll" = @{ Key = 'A'; Modifiers = @('Ctrl') }
            
            # Navigation
            "Nav.Up" = @{ Key = [ConsoleKey]::UpArrow; Modifiers = @() }
            "Nav.Down" = @{ Key = [ConsoleKey]::DownArrow; Modifiers = @() }
            "Nav.Left" = @{ Key = [ConsoleKey]::LeftArrow; Modifiers = @() }
            "Nav.Right" = @{ Key = [ConsoleKey]::RightArrow; Modifiers = @() }
            "Nav.PageUp" = @{ Key = [ConsoleKey]::PageUp; Modifiers = @() }
            "Nav.PageDown" = @{ Key = [ConsoleKey]::PageDown; Modifiers = @() }
            "Nav.Home" = @{ Key = [ConsoleKey]::Home; Modifiers = @() }
            "Nav.End" = @{ Key = [ConsoleKey]::End; Modifiers = @() }
            
            # Quick navigation (number keys)
            "QuickNav.1" = @{ Key = '1'; Modifiers = @() }
            "QuickNav.2" = @{ Key = '2'; Modifiers = @() }
            "QuickNav.3" = @{ Key = '3'; Modifiers = @() }
            "QuickNav.4" = @{ Key = '4'; Modifiers = @() }
            "QuickNav.5" = @{ Key = '5'; Modifiers = @() }
            "QuickNav.6" = @{ Key = '6'; Modifiers = @() }
            "QuickNav.7" = @{ Key = '7'; Modifiers = @() }
            "QuickNav.8" = @{ Key = '8'; Modifiers = @() }
            "QuickNav.9" = @{ Key = '9'; Modifiers = @() }
            
            # Form operations
            "Form.Submit" = @{ Key = [ConsoleKey]::Enter; Modifiers = @('Ctrl') }
            "Form.Cancel" = @{ Key = [ConsoleKey]::Escape; Modifiers = @() }
            "Form.Clear" = @{ Key = 'C'; Modifiers = @('Ctrl', 'Shift') }
            
            # Text editing
            "Edit.Cut" = @{ Key = 'X'; Modifiers = @('Ctrl') }
            "Edit.Copy" = @{ Key = 'C'; Modifiers = @('Ctrl') }
            "Edit.Paste" = @{ Key = 'V'; Modifiers = @('Ctrl') }
            "Edit.Undo" = @{ Key = 'Z'; Modifiers = @('Ctrl') }
            "Edit.Redo" = @{ Key = 'Y'; Modifiers = @('Ctrl') }
        }
        
        # Merge custom bindings
        $keyMap = $defaultKeyMap
        foreach ($action in $CustomBindings.Keys) {
            $keyMap[$action] = $CustomBindings[$action]
        }
        
        $service = @{
            _keyMap = $keyMap
            _enableChords = $EnableChords
            _chordBuffer = @()
            _chordTimeout = 1000  # milliseconds
            _lastKeyTime = [DateTime]::MinValue
            _contextStack = @()  # For context-specific bindings
            _globalHandlers = @{}  # Action name -> handler scriptblock
            
            IsAction = {
                param(
                    $self,
                    [string]$ActionName, 
                    [System.ConsoleKeyInfo]$KeyInfo,
                    [string]$Context = $null
                )
                Invoke-WithErrorHandling -Component "KeybindingService.IsAction" -Context "Check if key matches action" -ScriptBlock {
                    if ([string]::IsNullOrWhiteSpace($ActionName)) { return $false }
                    
                    # Check context-specific binding first
                    $contextKey = if ($Context) { "$Context.$ActionName" } else { $null }
                    if ($contextKey -and $self._keyMap.ContainsKey($contextKey)) {
                        return (& $self._matchesBinding -self $self -binding $self._keyMap[$contextKey] -keyInfo $KeyInfo)
                    }
                    
                    # Check global binding
                    if (-not $self._keyMap.ContainsKey($ActionName)) { return $false }
                    
                    return (& $self._matchesBinding -self $self -binding $self._keyMap[$ActionName] -keyInfo $KeyInfo)
                }
            }
            
            _matchesBinding = {
                param($self, $binding, $keyInfo)
                Invoke-WithErrorHandling -Component "KeybindingService._matchesBinding" -Context "Check if key matches binding" -ScriptBlock {
                    # Match key
                    $keyMatches = $false
                    if ($binding.Key -is [System.ConsoleKey]) {
                        $keyMatches = $keyInfo.Key -eq $binding.Key
                    }
                    elseif ($binding.Key -is [string] -and $binding.Key.Length -eq 1) {
                        $keyMatches = $keyInfo.KeyChar.ToString().Equals($binding.Key, [System.StringComparison]::InvariantCultureIgnoreCase)
                    }
                    
                    if (-not $keyMatches) { return $false }
                    
                    # Match modifiers
                    $requiredModifiers = $binding.Modifiers ?? @()
                    $hasCtrl = ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Control) -ne 0
                    $hasAlt = ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Alt) -ne 0
                    $hasShift = ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift) -ne 0
                    
                    $ctrlRequired = 'Ctrl' -in $requiredModifiers
                    $altRequired = 'Alt' -in $requiredModifiers
                    $shiftRequired = 'Shift' -in $requiredModifiers
                    
                    return ($hasCtrl -eq $ctrlRequired) -and 
                           ($hasAlt -eq $altRequired) -and 
                           ($hasShift -eq $shiftRequired)
                }
            }
            
            GetBinding = {
                param($self, [string]$ActionName)
                Invoke-WithErrorHandling -Component "KeybindingService.GetBinding" -Context "Get keybinding for action" -ScriptBlock {
                    return $self._keyMap[$ActionName]
                }
            }
            
            SetBinding = {
                param($self, [string]$ActionName, $Key, [string[]]$Modifiers = @())
                Invoke-WithErrorHandling -Component "KeybindingService.SetBinding" -Context "Set keybinding for action" -ScriptBlock {
                    $self._keyMap[$ActionName] = @{ Key = $Key; Modifiers = $Modifiers }
                    Write-Log -Level Debug -Message "Set keybinding for '$ActionName': $Key + $($Modifiers -join '+')"
                }
            }
            
            RemoveBinding = {
                param($self, [string]$ActionName)
                Invoke-WithErrorHandling -Component "KeybindingService.RemoveBinding" -Context "Remove keybinding for action" -ScriptBlock {
                    $self._keyMap.Remove($ActionName)
                    Write-Log -Level Debug -Message "Removed keybinding for '$ActionName'"
                }
            }
            
            GetBindingDescription = {
                param($self, [string]$ActionName)
                Invoke-WithErrorHandling -Component "KeybindingService.GetBindingDescription" -Context "Get binding description for action" -ScriptBlock {
                    if (-not $self._keyMap.ContainsKey($ActionName)) { return $null }
                    $binding = $self._keyMap[$ActionName]
                    $keyStr = if ($binding.Key -is [System.ConsoleKey]) { $binding.Key.ToString() } else { $binding.Key.ToString().ToUpper() }
                    if ($binding.Modifiers.Count -gt 0) { return "$($binding.Modifiers -join '+') + $keyStr" }
                    return $keyStr
                }
            }
            
            RegisterGlobalHandler = {
                param($self, [string]$ActionName, [scriptblock]$Handler)
                Invoke-WithErrorHandling -Component "KeybindingService.RegisterGlobalHandler" -Context "Register global key handler" -ScriptBlock {
                    $self._globalHandlers[$ActionName] = $Handler
                    Write-Log -Level Debug -Message "Registered global handler for '$ActionName'"
                }
            }
            
            HandleKey = {
                param($self, [System.ConsoleKeyInfo]$KeyInfo, [string]$Context = $null)
                Invoke-WithErrorHandling -Component "KeybindingService.HandleKey" -Context "Handle key input" -ScriptBlock {
                    foreach ($action in $self._keyMap.Keys) {
                        if ((& $self.IsAction -self $self -ActionName $action -KeyInfo $KeyInfo -Context $Context)) {
                            if ($self._globalHandlers.ContainsKey($action)) {
                                Write-Log -Level Debug -Message "Executing global handler for '$action'"
                                return (& $self._globalHandlers[$action] -KeyInfo $KeyInfo -Context $Context)
                            }
                            return $action
                        }
                    }
                    return $null
                }
            }
            
            PushContext = {
                param($self, [string]$Context)
                Invoke-WithErrorHandling -Component "KeybindingService.PushContext" -Context "Push keybinding context" -ScriptBlock {
                    $self._contextStack += $Context
                    Write-Log -Level Debug -Message "Pushed keybinding context: $Context"
                }
            }
            
            PopContext = {
                param($self)
                Invoke-WithErrorHandling -Component "KeybindingService.PopContext" -Context "Pop keybinding context" -ScriptBlock {
                    if ($self._contextStack.Count -gt 0) {
                        $context = $self._contextStack[-1]
                        $self._contextStack = $self._contextStack[0..($self._contextStack.Count - 2)]
                        Write-Log -Level Debug -Message "Popped keybinding context: $context"
                        return $context
                    }
                    return $null
                }
            }
            
            GetCurrentContext = {
                param($self)
                Invoke-WithErrorHandling -Component "KeybindingService.GetCurrentContext" -Context "Get current keybinding context" -ScriptBlock {
                    if ($self._contextStack.Count -gt 0) { return $self._contextStack[-1] }
                    return $null
                }
            }
            
            GetAllBindings = {
                param($self, [bool]$GroupByCategory = $false)
                Invoke-WithErrorHandling -Component "KeybindingService.GetAllBindings" -Context "Get all keybindings" -ScriptBlock {
                    if (-not $GroupByCategory) { return $self._keyMap }
                    $grouped = @{}
                    foreach ($action in $self._keyMap.Keys) {
                        $parts = $action.Split('.')
                        $category = if ($parts.Count -gt 1) { $parts[0] } else { "General" }
                        if (-not $grouped.ContainsKey($category)) { $grouped[$category] = @{} }
                        $grouped[$category][$action] = $self._keyMap[$action]
                    }
                    return $grouped
                }
            }
            
            ExportBindings = {
                param($self, [string]$Path)
                Invoke-WithErrorHandling -Component "KeybindingService.ExportBindings" -Context "Export keybindings to file" -ScriptBlock {
                    $self._keyMap | ConvertTo-Json -Depth 3 | Out-File -FilePath $Path
                    Write-Log -Level Info -Message "Exported keybindings to: $Path"
                }
            }
            
            ImportBindings = {
                param($self, [string]$Path)
                Invoke-WithErrorHandling -Component "KeybindingService.ImportBindings" -Context "Import keybindings from file" -ScriptBlock {
                    if (Test-Path $Path) {
                        $imported = Get-Content $Path | ConvertFrom-Json
                        foreach ($prop in $imported.PSObject.Properties) {
                            $self._keyMap[$prop.Name] = @{
                                Key = $prop.Value.Key
                                Modifiers = $prop.Value.Modifiers
                            }
                        }
                        Write-Log -Level Info -Message "Imported keybindings from: $Path"
                    }
                }
            }
        }
        
        return $service
    }
}

Export-ModuleMember -Function "Initialize-KeybindingService"