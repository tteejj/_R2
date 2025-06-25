# Error Handling Utilities Module for PMC Terminal v5
# Provides centralized error handling and logging functionality
# AI: Core utility module for robust error handling across all components

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Initialize log file path
$script:LogFilePath = Join-Path -Path $env:TEMP -ChildPath "PMCTerminal_$(Get-Date -Format 'yyyy-MM-dd').log"
$script:MaxLogSizeMB = 10
$script:LogLevel = "Info"

# Log levels enumeration
enum LogLevel {
    Debug = 0
    Info = 1
    Warning = 2
    Error = 3
    Critical = 4
}

# Invoke-WithErrorHandling - Wraps code blocks with consistent error handling
function Invoke-WithErrorHandling {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Component,
        
        [Parameter(Mandatory = $true)]
        [string]$Context,
        
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory = $false)]
        [scriptblock]$ErrorHandler = $null,
        
        [Parameter(Mandatory = $false)]
        [scriptblock]$FinallyBlock = $null,
        
        [Parameter(Mandatory = $false)]
        [bool]$ContinueOnError = $false
    )
    
    $startTime = [DateTime]::Now
    $success = $false
    
    try {
        Write-Log -Level Debug -Message "Starting operation" -Component $Component -Context $Context
        
        # Execute the main script block
        $result = & $ScriptBlock
        
        $success = $true
        Write-Log -Level Debug -Message "Operation completed successfully" -Component $Component -Context $Context
        
        return $result
    }
    catch {
        $errorDetails = @{
            Component = $Component
            Context = $Context
            Error = $_.Exception.Message
            ScriptStackTrace = $_.ScriptStackTrace
            InvocationInfo = $_.InvocationInfo.PositionMessage
            Duration = ([DateTime]::Now - $startTime).TotalMilliseconds
        }
        
        Write-Log -Level Error -Message "Operation failed: $($_.Exception.Message)" -Component $Component -Context $Context -ErrorDetails $errorDetails
        
        # Execute custom error handler if provided
        if ($null -ne $ErrorHandler) {
            try {
                & $ErrorHandler $_
            }
            catch {
                Write-Log -Level Error -Message "Error handler failed: $_" -Component $Component -Context "$Context.ErrorHandler"
            }
        }
        
        # Publish error event for global handling
        Publish-Event -EventName "Application.Error" -Data $errorDetails
        
        if (-not $ContinueOnError) {
            throw
        }
    }
    finally {
        if ($null -ne $FinallyBlock) {
            try {
                & $FinallyBlock
            }
            catch {
                Write-Log -Level Error -Message "Finally block failed: $_" -Component $Component -Context "$Context.Finally"
            }
        }
        
        $duration = ([DateTime]::Now - $startTime).TotalMilliseconds
        Write-Log -Level Debug -Message "Operation duration: $duration ms" -Component $Component -Context $Context
    }
}

# Write-Log - Centralized logging function
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Debug", "Info", "Warning", "Error", "Critical")]
        [string]$Level,
        
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$Component = "Unknown",
        
        [Parameter(Mandatory = $false)]
        [string]$Context = "",
        
        [Parameter(Mandatory = $false)]
        [hashtable]$ErrorDetails = @{}
    )
    
    # Check if we should log based on current log level
    $currentLevel = [LogLevel]::$script:LogLevel
    $messageLevel = [LogLevel]::$Level
    
    if ($messageLevel -lt $currentLevel) {
        return
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $threadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
    
    # Format log entry
    $logEntry = "$timestamp [$Level] [$Component"
    if (-not [string]::IsNullOrWhiteSpace($Context)) {
        $logEntry += "::$Context"
    }
    $logEntry += "] [Thread:$threadId] $Message"
    
    # Add error details if provided
    if ($ErrorDetails.Count -gt 0) {
        $logEntry += " | Details: " + ($ErrorDetails | ConvertTo-Json -Compress)
    }
    
    # Write to console with color coding
    $consoleColor = switch ($Level) {
        "Debug" { "DarkGray" }
        "Info" { "White" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Critical" { "Magenta" }
    }
    
    if ($Level -in @("Error", "Critical")) {
        Write-Host $logEntry -ForegroundColor $consoleColor -ErrorAction SilentlyContinue
    }
    elseif ($Level -eq "Warning") {
        Write-Warning $logEntry -ErrorAction SilentlyContinue
    }
    else {
        Write-Verbose $logEntry -ErrorAction SilentlyContinue
    }
    
    # Write to log file
    try {
        # Check log file size and rotate if needed
        if (Test-Path $script:LogFilePath) {
            $logFile = Get-Item $script:LogFilePath
            if ($logFile.Length -gt ($script:MaxLogSizeMB * 1MB)) {
                $archivePath = $script:LogFilePath -replace '\.log$', "_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
                Move-Item -Path $script:LogFilePath -Destination $archivePath -Force
            }
        }
        
        # Append to log file
        Add-Content -Path $script:LogFilePath -Value $logEntry -ErrorAction SilentlyContinue
    }
    catch {
        # Silently fail if unable to write to log file
    }
}

# Set-LogLevel - Configure the minimum log level
function Set-LogLevel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Debug", "Info", "Warning", "Error", "Critical")]
        [string]$Level
    )
    
    $script:LogLevel = $Level
    Write-Log -Level Info -Message "Log level set to: $Level" -Component "Logging"
}

# Get-LogLevel - Get the current log level
function Get-LogLevel {
    return $script:LogLevel
}

# Set-LogFilePath - Configure the log file path
function Set-LogFilePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    $script:LogFilePath = $Path
    Write-Log -Level Info -Message "Log file path set to: $Path" -Component "Logging"
}

# Get-LogFilePath - Get the current log file path
function Get-LogFilePath {
    return $script:LogFilePath
}

# Clear-LogFile - Clear the current log file
function Clear-LogFile {
    [CmdletBinding()]
    param()
    
    if (Test-Path $script:LogFilePath) {
        Remove-Item -Path $script:LogFilePath -Force
        Write-Log -Level Info -Message "Log file cleared" -Component "Logging"
    }
}

# Get-ErrorReport - Generate a detailed error report
function Get-ErrorReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$AdditionalInfo = @{}
    )
    
    $report = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Message = $ErrorRecord.Exception.Message
        Type = $ErrorRecord.Exception.GetType().FullName
        TargetObject = $ErrorRecord.TargetObject
        Category = $ErrorRecord.CategoryInfo.Category
        Activity = $ErrorRecord.CategoryInfo.Activity
        Reason = $ErrorRecord.CategoryInfo.Reason
        ScriptName = $ErrorRecord.InvocationInfo.ScriptName
        Line = $ErrorRecord.InvocationInfo.ScriptLineNumber
        Column = $ErrorRecord.InvocationInfo.OffsetInLine
        Statement = $ErrorRecord.InvocationInfo.Line
        StackTrace = $ErrorRecord.ScriptStackTrace
        FullyQualifiedErrorId = $ErrorRecord.FullyQualifiedErrorId
    }
    
    # Add inner exception details if present
    if ($null -ne $ErrorRecord.Exception.InnerException) {
        $report.InnerException = @{
            Message = $ErrorRecord.Exception.InnerException.Message
            Type = $ErrorRecord.Exception.InnerException.GetType().FullName
        }
    }
    
    # Merge additional info
    foreach ($key in $AdditionalInfo.Keys) {
        $report[$key] = $AdditionalInfo[$key]
    }
    
    return $report
}

# Format-ErrorForDisplay - Format an error for user-friendly display
function Format-ErrorForDisplay {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        
        [Parameter(Mandatory = $false)]
        [bool]$IncludeStackTrace = $false
    )
    
    $display = [System.Text.StringBuilder]::new()
    
    [void]$display.AppendLine("═" * 60)
    [void]$display.AppendLine("ERROR OCCURRED")
    [void]$display.AppendLine("═" * 60)
    [void]$display.AppendLine()
    [void]$display.AppendLine("Message: $($ErrorRecord.Exception.Message)")
    [void]$display.AppendLine("Type: $($ErrorRecord.Exception.GetType().Name)")
    
    if ($null -ne $ErrorRecord.InvocationInfo.ScriptName) {
        [void]$display.AppendLine("Script: $($ErrorRecord.InvocationInfo.ScriptName)")
        [void]$display.AppendLine("Line: $($ErrorRecord.InvocationInfo.ScriptLineNumber)")
    }
    
    if ($IncludeStackTrace -and -not [string]::IsNullOrWhiteSpace($ErrorRecord.ScriptStackTrace)) {
        [void]$display.AppendLine()
        [void]$display.AppendLine("Stack Trace:")
        [void]$display.AppendLine($ErrorRecord.ScriptStackTrace)
    }
    
    [void]$display.AppendLine()
    [void]$display.AppendLine("═" * 60)
    
    return $display.ToString()
}

# Initialize-ErrorHandling - Set up global error handling
function Initialize-ErrorHandling {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$LogLevel = "Info",
        
        [Parameter(Mandatory = $false)]
        [string]$LogPath = $null
    )
    
    # Set log level
    Set-LogLevel -Level $LogLevel
    
    # Set custom log path if provided
    if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
        Set-LogFilePath -Path $LogPath
    }
    
    # Set global error action preference
    $global:ErrorActionPreference = "Stop"
    
    # Register global error event handler
    Register-EngineEvent -SourceIdentifier "Application.Error" -Action {
        $errorData = $Event.MessageData
        
        # Log to Windows Event Log if available
        try {
            $source = "PMCTerminal"
            if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
                [System.Diagnostics.EventLog]::CreateEventSource($source, "Application")
            }
            
            $message = "Component: $($errorData.Component)`nContext: $($errorData.Context)`nError: $($errorData.Error)"
            [System.Diagnostics.EventLog]::WriteEntry($source, $message, [System.Diagnostics.EventLogEntryType]::Error)
        }
        catch {
            # Silently fail if unable to write to event log
        }
    }
    
    Write-Log -Level Info -Message "Error handling initialized" -Component "ErrorHandling"
}

# Export all functions
Export-ModuleMember -Function @(
    'Invoke-WithErrorHandling',
    'Write-Log',
    'Set-LogLevel',
    'Get-LogLevel',
    'Set-LogFilePath',
    'Get-LogFilePath',
    'Clear-LogFile',
    'Get-ErrorReport',
    'Format-ErrorForDisplay',
    'Initialize-ErrorHandling'
)