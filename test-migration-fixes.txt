# Immediate Migration Validation Test
# Quick test to verify the error handling fixes work correctly
# AI: Run this script to immediately test if the parameter binding issues are resolved

Set-StrictMode -Version Latest

Write-Host "=== PMC Terminal v5 - Migration Fix Validation ===" -ForegroundColor Magenta
Write-Host ""

# Test 1: Error Handling Module
Write-Host "Test 1: Error Handling Module" -ForegroundColor Cyan
try {
    Import-Module "$PSScriptRoot\..\utilities\error-handling.psm1" -Force
    Write-Host "✅ Error handling module imported successfully" -ForegroundColor Green
    
    # Test the fixed parameter pattern
    $result = Invoke-WithErrorHandling -Component "TestComponent" -Context "TestMethod" -ScriptBlock {
        return "Parameter binding working correctly!"
    }
    
    Write-Host "✅ Parameter binding test: PASSED" -ForegroundColor Green
    Write-Host "   Result: $result" -ForegroundColor Gray
    
}
catch {
    Write-Host "❌ Error handling test: FAILED" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 2: IRenderable Base Class
Write-Host "Test 2: IRenderable Base Class" -ForegroundColor Cyan
try {
    Import-Module "$PSScriptRoot\..\components\IRenderable.psm1" -Force
    Write-Host "✅ IRenderable module imported successfully" -ForegroundColor Green
    
    # Create a test component
    class TestComponent : IRenderable {
        TestComponent() : base("TestComponent") { }
        
        hidden [string] _RenderContent() {
            return "Test component rendering successfully!"
        }
    }
    
    $testComponent = [TestComponent]::new()
    $output = $testComponent.Render()
    
    Write-Host "✅ IRenderable test: PASSED" -ForegroundColor Green
    Write-Host "   Output: $output" -ForegroundColor Gray
    
    # Test validation
    $isValid = $testComponent.ValidateRender()
    Write-Host "✅ Component validation: $isValid" -ForegroundColor $(if ($isValid) { "Green" } else { "Red" })
    
}
catch {
    Write-Host "❌ IRenderable test: FAILED" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 3: Dashboard Screen Parameter Fix
Write-Host "Test 3: Dashboard Screen Parameter Fix" -ForegroundColor Cyan
try {
    # Check if the dashboard file has the correct parameter pattern
    $dashboardPath = "$PSScriptRoot\..\screens\dashboard-screen-helios.psm1"
    
    if (Test-Path $dashboardPath) {
        $content = Get-Content -Path $dashboardPath -Raw
        
        # Check for old incorrect pattern
        $incorrectPattern = 'Invoke-WithErrorHandling\s+-ScriptBlock'
        $hasIncorrectPattern = $content -match $incorrectPattern
        
        if ($hasIncorrectPattern) {
            Write-Host "❌ Dashboard still has incorrect parameter pattern" -ForegroundColor Red
        }
        else {
            Write-Host "✅ Dashboard parameter pattern: FIXED" -ForegroundColor Green
        }
        
        # Check for correct pattern
        $correctPattern = 'Invoke-WithErrorHandling\s+-Component.*-Context.*-ScriptBlock'
        $hasCorrectPattern = $content -match $correctPattern
        
        if ($hasCorrectPattern) {
            Write-Host "✅ Dashboard uses correct parameter order" -ForegroundColor Green
        }
        else {
            Write-Host "⚠️ Dashboard may need parameter order verification" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "⚠️ Dashboard file not found for testing" -ForegroundColor Yellow
    }
    
}
catch {
    Write-Host "❌ Dashboard parameter test: FAILED" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Red
}

Write-Host ""

# Test 4: Error Handling in Practice
Write-Host "Test 4: Error Handling Robustness" -ForegroundColor Cyan
try {
    # Test error handling with intentional error
    $errorOutput = Invoke-WithErrorHandling -Component "TestError" -Context "IntentionalError" -ScriptBlock {
        throw "This is a test error to verify error handling"
    }
}
catch {
    Write-Host "✅ Error handling caught exception correctly" -ForegroundColor Green
    Write-Host "   Exception type: $($_.Exception.GetType().Name)" -ForegroundColor Gray
}

# Test IRenderable error handling
try {
    class ErrorTestComponent : IRenderable {
        ErrorTestComponent() : base("ErrorTestComponent") { }
        
        hidden [string] _RenderContent() {
            throw "Intentional render error for testing"
        }
    }
    
    $errorComponent = [ErrorTestComponent]::new()
    $errorOutput = $errorComponent.Render()
    
    if ($errorOutput -like "*COMPONENT ERROR*") {
        Write-Host "✅ IRenderable error handling: PASSED" -ForegroundColor Green
        Write-Host "   Error box generated correctly" -ForegroundColor Gray
    }
    else {
        Write-Host "❌ IRenderable error handling: No error box generated" -ForegroundColor Red
    }
}
catch {
    Write-Host "❌ IRenderable error handling test: FAILED" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Red
}

Write-Host ""

# Summary
Write-Host "=== VALIDATION SUMMARY ===" -ForegroundColor Magenta
Write-Host "If all tests show ✅ PASSED, your migration fixes are working correctly!" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Run your main application to test the dashboard fix" -ForegroundColor White
Write-Host "2. Use the migration guide to convert other components" -ForegroundColor White
Write-Host "3. Run the full validation script for comprehensive testing" -ForegroundColor White
Write-Host ""
Write-Host "Migration Guide: See the artifact created for detailed migration patterns" -ForegroundColor Yellow
Write-Host "Full Validation: Run validation\migration-validator.ps1" -ForegroundColor Yellow
