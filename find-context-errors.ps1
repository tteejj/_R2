# Script to find all instances of Invoke-WithErrorHandling and check for correct usage
$basePath = Split-Path -Parent $MyInvocation.MyCommand.Path
$issues = @()

# Get all PowerShell files
$files = Get-ChildItem -Path $basePath -Filter "*.psm1" -Recurse
$files += Get-ChildItem -Path $basePath -Filter "*.ps1" -Recurse

foreach ($file in $files) {
    if ($file.Name -eq "find-context-errors.ps1") { continue }
    
    $content = Get-Content $file.FullName -Raw
    
    # Find all instances of Invoke-WithErrorHandling
    $matches = [regex]::Matches($content, 'Invoke-WithErrorHandling[^}]+\}', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    
    foreach ($match in $matches) {
        $invocation = $match.Value
        
        # Check if -Context is used with @{ } (hashtable)
        if ($invocation -match '-Context\s+@\{') {
            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
            $issues += [PSCustomObject]@{
                File = $file.FullName.Replace($basePath, ".")
                Line = $lineNumber
                Issue = "Context parameter is using a hashtable instead of a string"
                Code = $invocation.Substring(0, [Math]::Min(200, $invocation.Length)) + "..."
            }
        }
        
        # Check if Context appears multiple times
        $contextCount = ([regex]::Matches($invocation, '-Context\s+')).Count
        if ($contextCount -gt 1) {
            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
            $issues += [PSCustomObject]@{
                File = $file.FullName.Replace($basePath, ".")
                Line = $lineNumber
                Issue = "Multiple -Context parameters found"
                Code = $invocation.Substring(0, [Math]::Min(200, $invocation.Length)) + "..."
            }
        }
    }
}

if ($issues.Count -gt 0) {
    Write-Host "Found $($issues.Count) issues with Invoke-WithErrorHandling usage:" -ForegroundColor Red
    $issues | Format-Table -AutoSize -Wrap
    
    # Export to file for review
    $issues | Export-Csv -Path "$basePath\context-errors.csv" -NoTypeInformation
    Write-Host "`nDetailed report saved to context-errors.csv" -ForegroundColor Yellow
} else {
    Write-Host "No issues found with Invoke-WithErrorHandling usage!" -ForegroundColor Green
}

# Additional check for component handlers that might be passing wrong parameters
Write-Host "`nChecking for potential parameter passing issues in handlers..." -ForegroundColor Cyan

$handlerIssues = @()
foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    
    # Look for event handlers that might be passing Context as hashtable
    $patterns = @(
        'ErrorHandler\s*=\s*\{[^}]*-Context\s+@\{',
        'OnClick\s*=\s*\{[^}]*Invoke-WithErrorHandling[^}]*-Context\s+@\{',
        'OnChange\s*=\s*\{[^}]*Invoke-WithErrorHandling[^}]*-Context\s+@\{',
        'OnFocus\s*=\s*\{[^}]*Invoke-WithErrorHandling[^}]*-Context\s+@\{',
        'OnBlur\s*=\s*\{[^}]*Invoke-WithErrorHandling[^}]*-Context\s+@\{'
    )
    
    foreach ($pattern in $patterns) {
        $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        foreach ($match in $matches) {
            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
            $handlerIssues += [PSCustomObject]@{
                File = $file.FullName.Replace($basePath, ".")
                Line = $lineNumber
                Pattern = $pattern
                Issue = "Handler using hashtable for Context parameter"
            }
        }
    }
}

if ($handlerIssues.Count -gt 0) {
    Write-Host "`nFound $($handlerIssues.Count) handler issues:" -ForegroundColor Red
    $handlerIssues | Format-Table -AutoSize -Wrap
}

Write-Host "`nDone!" -ForegroundColor Green