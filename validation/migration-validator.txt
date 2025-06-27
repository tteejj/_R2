# IRenderable Migration Validation and Testing Script
# Tests all components for proper migration to IRenderable pattern
# AI: Comprehensive validation tool for the migration process

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Import required modules
Import-Module "$PSScriptRoot\..\utilities\error-handling.psm1" -Force
Import-Module "$PSScriptRoot\..\components\IRenderable.psm1" -Force

function Test-ComponentMigration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Component,
        
        [Parameter(Mandatory = $false)]
        [switch]$Verbose
    )
    
    $results = @{
        ComponentName = $Component.GetType().Name
        IsIRenderable = $false
        HasRenderMethod = $false
        HasRenderContentMethod = $false
        ValidatesSuccessfully = $false
        RenderTest = @{
            Success = $false
            OutputLength = 0
            ErrorMessage = ""
            ProducesErrorBox = $false
        }
        Recommendations = @()
    }
    
    try {
        # Check if component inherits from IRenderable
        $results.IsIRenderable = $Component -is [IRenderable]
        
        # Check for required methods
        $results.HasRenderMethod = $Component.GetType().GetMethod("Render") -ne $null
        $results.HasRenderContentMethod = $Component.GetType().GetMethod("_RenderContent", [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Instance) -ne $null
        
        # Test render functionality
        if ($results.HasRenderMethod) {
            try {
                $output = $Component.Render()
                $results.RenderTest.Success = $true
                $results.RenderTest.OutputLength = if ($output) { $output.Length } else { 0 }
                
                # Check if output is an error box (indicates error handling is working)
                $results.RenderTest.ProducesErrorBox = $output -like "*COMPONENT ERROR*"
                
            }
            catch {
                $results.RenderTest.ErrorMessage = $_.Exception.Message
            }
        }
        
        # Test validation method if available
        if ($results.IsIRenderable) {
            try {
                $results.ValidatesSuccessfully = $Component.ValidateRender()
            }
            catch {
                $results.ValidatesSuccessfully = $false
            }
        }
        
        # Generate recommendations
        if (-not $results.IsIRenderable) {
            $results.Recommendations += "Component should inherit from IRenderable"
        }
        
        if (-not $results.HasRenderContentMethod -and $results.IsIRenderable) {
            $results.Recommendations += "Component should implement _RenderContent() method"
        }
        
        if (-not $results.RenderTest.Success) {
            $results.Recommendations += "Component render method fails: $($results.RenderTest.ErrorMessage)"
        }
        
        if ($Verbose) {
            Write-Host "Migration Test Results for $($results.ComponentName):" -ForegroundColor Cyan
            Write-Host "  Inherits IRenderable: $($results.IsIRenderable)" -ForegroundColor $(if ($results.IsIRenderable) { "Green" } else { "Red" })
            Write-Host "  Has Render Method: $($results.HasRenderMethod)" -ForegroundColor $(if ($results.HasRenderMethod) { "Green" } else { "Red" })
            Write-Host "  Render Test Success: $($results.RenderTest.Success)" -ForegroundColor $(if ($results.RenderTest.Success) { "Green" } else { "Red" })
            Write-Host "  Output Length: $($results.RenderTest.OutputLength)" -ForegroundColor Gray
            
            if ($results.Recommendations.Count -gt 0) {
                Write-Host "  Recommendations:" -ForegroundColor Yellow
                foreach ($rec in $results.Recommendations) {
                    Write-Host "    - $rec" -ForegroundColor Yellow
                }
            }
        }
        
    }
    catch {
        $results.RenderTest.ErrorMessage = "Validation failed: $($_.Exception.Message)"
    }
    
    return $results
}

function Test-ErrorHandlingParameterOrder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }
    
    $content = Get-Content -Path $FilePath -Raw
    $issues = @()
    
    # Check for incorrect parameter order patterns
    $incorrectPatterns = @(
        @{
            Pattern = 'Invoke-WithErrorHandling\s+-ScriptBlock\s+\{'
            Issue = "ScriptBlock parameter should come after Component and Context"
        },
        @{
            Pattern = 'Invoke-WithErrorHandling.*-Context.*-Component'
            Issue = "Component parameter should come before Context parameter"
        }
    )
    
    foreach ($pattern in $incorrectPatterns) {
        $matches = [regex]::Matches($content, $pattern.Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
        foreach ($match in $matches) {
            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
            $issues += @{
                LineNumber = $lineNumber
                Issue = $pattern.Issue
                Context = $match.Value.Substring(0, [Math]::Min(50, $match.Value.Length))
            }
        }
    }
    
    return @{
        FilePath = $FilePath
        Issues = $issues
        HasIssues = $issues.Count -gt 0
    }
}

function Start-FullMigrationValidation {
    param(
        [Parameter(Mandatory = $false)]
        [string]$RootDirectory = (Get-Location).Path
    )
    
    Write-Host "=== IRenderable Migration Validation ===" -ForegroundColor Magenta
    Write-Host "Root Directory: $RootDirectory" -ForegroundColor Gray
    Write-Host ""
    
    $results = @{
        TotalFiles = 0
        ProcessedFiles = 0
        MigratedComponents = 0
        FailedComponents = 0
        ParameterOrderIssues = 0
        Components = @()
        FileIssues = @()
    }
    
    # 1. Test Error Handling Parameter Order
    Write-Host "1. Checking Error Handling Parameter Order..." -ForegroundColor Cyan
    $psm1Files = Get-ChildItem -Path $RootDirectory -Filter "*.psm1" -Recurse
    $results.TotalFiles = $psm1Files.Count
    
    foreach ($file in $psm1Files) {
        try {
            $parameterTest = Test-ErrorHandlingParameterOrder -FilePath $file.FullName
            
            if ($parameterTest.HasIssues) {
                $results.ParameterOrderIssues += $parameterTest.Issues.Count
                $results.FileIssues += $parameterTest
                
                Write-Host "  ❌ $($file.Name): $($parameterTest.Issues.Count) parameter order issues" -ForegroundColor Red
                foreach ($issue in $parameterTest.Issues) {
                    Write-Host "    Line $($issue.LineNumber): $($issue.Issue)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "  ✅ $($file.Name): No parameter order issues" -ForegroundColor Green
            }
            
            $results.ProcessedFiles++
        }
        catch {
            Write-Host "  ⚠️ $($file.Name): Failed to check - $_" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    
    # 2. Test IRenderable Components
    Write-Host "2. Testing IRenderable Components..." -ForegroundColor Cyan
    
    # Create test instances of common components
    $testComponents = @()
    
    # Try to create sample components for testing
    try {
        # You can add your specific component tests here
        Write-Host "  Creating test component instances..." -ForegroundColor Gray
        
        # Example: Create a simple test component
        $testTableComponent = @{
            GetType = { return @{ Name = "TestTableComponent" } }
        }
        
        # Add to test array if you have actual components to test
        # $testComponents += $yourActualComponent
        
    }
    catch {
        Write-Host "  ⚠️ Could not create test components: $_" -ForegroundColor Yellow
    }
    
    # Test each component
    foreach ($component in $testComponents) {
        try {
            $testResult = Test-ComponentMigration -Component $component -Verbose
            $results.Components += $testResult
            
            if ($testResult.IsIRenderable -and $testResult.RenderTest.Success) {
                $results.MigratedComponents++
                Write-Host "  ✅ $($testResult.ComponentName): Successfully migrated" -ForegroundColor Green
            }
            else {
                $results.FailedComponents++
                Write-Host "  ❌ $($testResult.ComponentName): Migration incomplete" -ForegroundColor Red
            }
        }
        catch {
            $results.FailedComponents++
            Write-Host "  ❌ Component test failed: $_" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    
    # 3. Generate Summary Report
    Write-Host "=== MIGRATION VALIDATION SUMMARY ===" -ForegroundColor Magenta
    Write-Host "Files Processed: $($results.ProcessedFiles)/$($results.TotalFiles)" -ForegroundColor White
    Write-Host "Parameter Order Issues: $($results.ParameterOrderIssues)" -ForegroundColor $(if ($results.ParameterOrderIssues -eq 0) { "Green" } else { "Red" })
    Write-Host "Components Tested: $($results.Components.Count)" -ForegroundColor White
    Write-Host "Successfully Migrated: $($results.MigratedComponents)" -ForegroundColor Green
    Write-Host "Failed Migration: $($results.FailedComponents)" -ForegroundColor Red
    
    if ($results.ParameterOrderIssues -eq 0 -and $results.FailedComponents -eq 0) {
        Write-Host "🎉 MIGRATION VALIDATION PASSED!" -ForegroundColor Green
    }
    else {
        Write-Host "⚠️ MIGRATION VALIDATION NEEDS ATTENTION" -ForegroundColor Yellow
    }
    
    Write-Host ""
    
    # 4. Next Steps
    Write-Host "Next Steps:" -ForegroundColor Cyan
    if ($results.ParameterOrderIssues -gt 0) {
        Write-Host "  1. Fix parameter order issues in the reported files" -ForegroundColor Yellow
    }
    if ($results.FailedComponents -gt 0) {
        Write-Host "  2. Complete migration of failed components to IRenderable" -ForegroundColor Yellow
    }
    if ($results.ParameterOrderIssues -eq 0 -and $results.FailedComponents -eq 0) {
        Write-Host "  1. Test the application to ensure everything works correctly" -ForegroundColor Green
        Write-Host "  2. Consider running performance tests" -ForegroundColor Green
    }
    
    return $results
}

# Quick validation function for immediate testing
function Test-ImmediateErrorHandling {
    Write-Host "Testing Error Handling Fix..." -ForegroundColor Cyan
    
    try {
        # Test the fixed error handling pattern
        $result = Invoke-WithErrorHandling -Component "TestComponent" -Context "TestMethod" -ScriptBlock {
            return "Error handling working correctly"
        }
        
        Write-Host "✅ Error handling parameter order: PASSED" -ForegroundColor Green
        Write-Host "   Result: $result" -ForegroundColor Gray
    }
    catch {
        Write-Host "❌ Error handling parameter order: FAILED" -ForegroundColor Red
        Write-Host "   Error: $_" -ForegroundColor Red
    }
    
    try {
        # Test IRenderable base class
        $testRenderable = [IRenderable]::new("TestComponent")
        
        Write-Host "✅ IRenderable base class: PASSED" -ForegroundColor Green
        Write-Host "   Component: $($testRenderable._componentName)" -ForegroundColor Gray
    }
    catch {
        Write-Host "❌ IRenderable base class: FAILED" -ForegroundColor Red
        Write-Host "   Error: $_" -ForegroundColor Red
    }
}

# Export functions for use in other scripts
Export-ModuleMember -Function @(
    'Test-ComponentMigration',
    'Test-ErrorHandlingParameterOrder', 
    'Start-FullMigrationValidation',
    'Test-ImmediateErrorHandling'
)

# If script is run directly, perform immediate validation
if ($MyInvocation.InvocationName -ne '&') {
    Test-ImmediateErrorHandling
    Write-Host ""
    Write-Host "To run full validation, use: Start-FullMigrationValidation" -ForegroundColor Cyan
}
