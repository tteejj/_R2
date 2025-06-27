# Quick validation test for PMC Terminal v5 fixes
Write-Host "Testing PMC Terminal v5 Critical Fixes..." -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan

$testResults = @{
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    Issues = @()
}

function Test-Result {
    param([bool]$Success, [string]$TestName, [string]$ErrorMessage = "")
    $testResults.TotalTests++
    if ($Success) {
        $testResults.PassedTests++
        Write-Host "✓ $TestName" -ForegroundColor Green
    } else {
        $testResults.FailedTests++
        $testResults.Issues += "$TestName - $ErrorMessage"
        Write-Host "✗ $TestName - $ErrorMessage" -ForegroundColor Red
    }
}

try {
    # Test 1: Can import layout panels without Context duplication
    Write-Host "`n1. Testing Layout Panels Import..." -ForegroundColor Yellow
    try {
        Import-Module ".\layout\panels.psm1" -Force -ErrorAction Stop
        Test-Result $true "Layout Panels Module Import"
    } catch {
        Test-Result $false "Layout Panels Module Import" $_.Exception.Message
    }

    # Test 2: Can create panels with AddChild method
    Write-Host "`n2. Testing Panel Creation..." -ForegroundColor Yellow
    try {
        $testPanel = New-TuiStackPanel -Props @{ Name = "TestPanel"; Width = 50; Height = 20 }
        $hasAddChild = $null -ne $testPanel.AddChild
        Test-Result $hasAddChild "Panel AddChild Method Available"
    } catch {
        Test-Result $false "Panel Creation" $_.Exception.Message
    }

    # Test 3: Can import text-resources without Context duplication
    Write-Host "`n3. Testing Text Resources Import..." -ForegroundColor Yellow
    try {
        Import-Module ".\modules\text-resources.psm1" -Force -ErrorAction Stop
        Test-Result $true "Text Resources Module Import"
    } catch {
        Test-Result $false "Text Resources Module Import" $_.Exception.Message
    }

    # Test 4: Can import TUI components
    Write-Host "`n4. Testing TUI Components Import..." -ForegroundColor Yellow
    try {
        Import-Module ".\components\tui-components.psm1" -Force -ErrorAction Stop
        Test-Result $true "TUI Components Module Import"
    } catch {
        Test-Result $false "TUI Components Module Import" $_.Exception.Message
    }

    # Test 5: Can create components
    Write-Host "`n5. Testing Component Creation..." -ForegroundColor Yellow
    try {
        $testLabel = New-TuiLabel -Props @{ Text = "Test"; Name = "TestLabel" }
        $hasRender = $null -ne $testLabel.Render
        Test-Result $hasRender "Label Component Creation"
    } catch {
        Test-Result $false "Label Component Creation" $_.Exception.Message
    }

    # Test 6: Can import dashboard screen
    Write-Host "`n6. Testing Dashboard Screen Import..." -ForegroundColor Yellow
    try {
        Import-Module ".\screens\dashboard-screen-helios.psm1" -Force -ErrorAction Stop
        Test-Result $true "Dashboard Screen Module Import"
    } catch {
        Test-Result $false "Dashboard Screen Module Import" $_.Exception.Message
    }

} catch {
    Write-Host "Critical test failure: $_" -ForegroundColor Red
}

# Summary
Write-Host "`n" + "="*50 -ForegroundColor Magenta
Write-Host "Test Results Summary:" -ForegroundColor Magenta
Write-Host "Total Tests: $($testResults.TotalTests)" -ForegroundColor White
Write-Host "Passed: $($testResults.PassedTests)" -ForegroundColor Green
Write-Host "Failed: $($testResults.FailedTests)" -ForegroundColor Red

if ($testResults.FailedTests -eq 0) {
    Write-Host "`n🎉 ALL TESTS PASSED! 🎉" -ForegroundColor Green
    Write-Host "✅ Parameter binding errors should be resolved" -ForegroundColor Green
    Write-Host "✅ Context duplication errors should be fixed" -ForegroundColor Green
    Write-Host "✅ Component function issues should be resolved" -ForegroundColor Green
    Write-Host "`nThe application should now run without the critical errors!" -ForegroundColor Cyan
    Write-Host "Try running: .\main.ps1" -ForegroundColor Yellow
} else {
    Write-Host "`n⚠️  Some tests failed:" -ForegroundColor Yellow
    foreach ($issue in $testResults.Issues) {
        Write-Host "  - $issue" -ForegroundColor Red
    }
    Write-Host "`nPlease address the failing tests before running the main application." -ForegroundColor Yellow
}

Write-Host "`nTest completed." -ForegroundColor Cyan
