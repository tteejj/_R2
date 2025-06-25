# TUI Framework Integration Module - COMPLIANT VERSION
# Contains compliant utility functions. Deprecated functions have been removed.

$script:TuiAsyncJobs = @()

function global:Invoke-TuiMethod {
    <#
    .SYNOPSIS
    Safely invokes a method on a TUI component.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Component,

        [Parameter(Mandatory = $true)]
        [string]$MethodName,

        [Parameter()]
        [hashtable]$Arguments = @{}
    )

    # AI: Defensive check for null component to prevent errors.
    if ($null -eq $Component) { return }
    
    # AI: Check if the method key exists and is a scriptblock before attempting invocation.
    # This prevents "The term '...' is not recognized" errors for optional methods.
    if (-not $Component.ContainsKey($MethodName)) { return }
    $method = $Component[$MethodName]
    if ($null -eq $method -or $method -isnot [scriptblock]) {
        return
    }

    # Add the component itself as the 'self' parameter for convenience within the method.
    $Arguments['self'] = $Component

    Invoke-WithErrorHandling -Component "$($Component.Name ?? $Component.Type).$MethodName" -Context "Invoking component method" -ScriptBlock {
        # Use splatting with the @ operator for robust parameter passing.
        & $method @Arguments
    } -Context @{ Component = $Component.Name; Method = $MethodName } -ErrorHandler {
        param($Exception)
        # Log the error but do not re-throw, allowing the UI to remain responsive.
        Write-Log -Level Error -Message "Error invoking method '$($Exception.Context.Method)' on component '$($Exception.Context.Component)': $($Exception.Message)" -Data $Exception.Context
        Request-TuiRefresh
    }
}

function global:Initialize-TuiFramework {
    <#
    .SYNOPSIS
    Initializes the TUI framework.
    #>
    Invoke-WithErrorHandling -Component "TuiFramework.Initialize" -Context "Initializing framework" -ScriptBlock {
        # Ensure engine is initialized before the framework.
        if (-not $global:TuiState) {
            throw "TUI Engine must be initialized before the TUI Framework."
        }
        Write-Log -Level Info -Message "TUI Framework initialized."
    }
}

function global:Invoke-TuiAsync {
    <#
    .SYNOPSIS
    Executes a script block asynchronously with proper job management.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        [Parameter()]
        [scriptblock]$OnComplete = {},
        [Parameter()]
        [scriptblock]$OnError = {},
        [Parameter()]
        [array]$ArgumentList = @()
    )
    
    Invoke-WithErrorHandling -Component "TuiFramework.InvokeAsync" -Context "Starting async job" -ScriptBlock {
        $job = Start-Job -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
        $script:TuiAsyncJobs += $job
        
        $timer = New-Object System.Timers.Timer
        $timer.Interval = 100
        $timer.AutoReset = $true
        
        $timerEvent = Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action {
            param($Event)
            $jobData = $Event.MessageData
            $job = $jobData.Job
            
            if ($job.State -in 'Completed', 'Failed') {
                $jobData.Timer.Stop()
                $jobData.Timer.Dispose()
                Unregister-Event -SourceIdentifier $Event.SourceIdentifier
                
                $script:TuiAsyncJobs = @($script:TuiAsyncJobs | Where-Object { $_.Id -ne $job.Id })

                if ($job.State -eq 'Completed') {
                    $result = Receive-Job -Job $job
                    if ($jobData.OnComplete) { & $jobData.OnComplete -Data $result }
                } else {
                    $error = $job.ChildJobs[0].JobStateInfo.Reason
                    if ($jobData.OnError) { & $jobData.OnError -Error $error }
                }
                Remove-Job -Job $job -Force
                Request-TuiRefresh
            }
        } -MessageData @{
            Job = $job
            OnComplete = $OnComplete
            OnError = $OnError
            Timer = $timer
        }
        
        $timer.Start()
        return @{ Job = $job; Timer = $timer; EventSubscription = $timerEvent }
    }
}

function global:Stop-AllTuiAsyncJobs {
    <#
    .SYNOPSIS
    Stops and cleans up all tracked async jobs.
    #>
    Invoke-WithErrorHandling -Component "TuiFramework.StopAsyncJobs" -Context "Cleaning up async jobs" -ScriptBlock {
        foreach ($job in $script:TuiAsyncJobs) {
            try {
                if ($job.State -eq 'Running') { Stop-Job -Job $job -ErrorAction SilentlyContinue }
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            } catch {
                Write-Log -Level Warning -Message "Failed to stop or remove job $($job.Id)" -Data $_
            }
        }
        $script:TuiAsyncJobs = @()
        
        Get-EventSubscriber | Where-Object { $_.SourceObject -is [System.Timers.Timer] } | ForEach-Object {
            try {
                Unregister-Event -SourceIdentifier $_.SourceIdentifier -ErrorAction SilentlyContinue
                if ($_.SourceObject) {
                    $_.SourceObject.Stop()
                    $_.SourceObject.Dispose()
                }
            } catch { }
        }
    }
}

Export-ModuleMember -Function @(
    'Initialize-TuiFramework',
    'Invoke-TuiMethod',
    'Invoke-TuiAsync',
    'Stop-AllTuiAsyncJobs'
)