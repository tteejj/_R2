# Script to find and fix all Invoke-WithErrorHandling issues
param(
    [switch]$DryRun = $true,
    [switch]$Verbose = $false
)

$basePath = Split-Path -Parent $MyInvocation.MyCommand.Path
$issues = @()
$fixCount = 0

Write-Host "Scanning for Invoke-WithErrorHandling issues..." -ForegroundColor Cyan
Write-Host "DryRun mode: $DryRun" -ForegroundColor Yellow

# Get all PowerShell files
$files = Get-ChildItem -Path $basePath -Filter "*.psm1" -Recurse
$files += Get-ChildItem -Path $basePath -Filter "*.ps1" -Recurse

foreach ($file in $files) {
    # Skip this script and test scripts
    if ($file.Name -match "(fix-error-handling|test-|validate-).ps1") { continue }
    
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content
    $fileChanged = $false
    
    # Pattern 1: Fix -Context with hashtable (should be string)
    $pattern1 = '(-Context\s+)(@\{[^}]+\})'
    $matches1 = [regex]::Matches($content, $pattern1)
    foreach ($match in $matches1) {
        $hashtableContent = $match.Groups[2].Value
        # Extract a meaningful string from the hashtable
        if ($hashtableContent -match 'Operation\s*=\s*["\''](.*?)["\''']') {
            $contextString = $matches[1]
        } else {
            $contextString = "Operation"
        }
        
        $replacement = '$1"' + $contextString + '"'
        $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
        
        $issues += [PSCustomObject]@{
            File = $file.FullName.Replace($basePath, ".")
            Line = $lineNumber
            Issue = "Context using hashtable"
            Original = $match.Value
            Fixed = $match.Groups[1].Value + '"' + $contextString + '"'
        }
        
        if (-not $DryRun) {
            $content = $content.Replace($match.Value, $match.Groups[1].Value + '"' + $contextString + '"')
            $fileChanged = $true
            $fixCount++
        }
    }
    
    # Pattern 2: Fix empty -Context parameter
    $pattern2 = '-Context\s+("")|(-Context\s+\$null)'
    $matches2 = [regex]::Matches($content, $pattern2)
    foreach ($match in $matches2) {
        $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
        
        # Try to infer context from surrounding code
        $startIndex = [Math]::Max(0, $match.Index - 500)
        $endIndex = [Math]::Min($content.Length, $match.Index + 500)
        $surroundingCode = $content.Substring($startIndex, $endIndex - $startIndex)
        
        $inferredContext = "Operation"
        if ($surroundingCode -match 'Component\s*[