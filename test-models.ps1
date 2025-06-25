# Test script to validate models module loading
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    Write-Host "Testing models module loading..." -ForegroundColor Cyan
    
    # Import the models module
    $modelsPath = "C:\Users\jhnhe\Documents\GitHub\_HELIOS - Refactored\modules\models.psm1"
    Import-Module $modelsPath -Force -Global
    
    Write-Host "✓ Models module imported successfully" -ForegroundColor Green
    
    # Test enum availability
    Write-Host "Testing enum types..." -ForegroundColor Cyan
    
    $testStatus = [TaskStatus]::Pending
    Write-Host "✓ TaskStatus enum works: $testStatus" -ForegroundColor Green
    
    $testPriority = [TaskPriority]::High
    Write-Host "✓ TaskPriority enum works: $testPriority" -ForegroundColor Green
    
    $testBilling = [BillingType]::Billable
    Write-Host "✓ BillingType enum works: $testBilling" -ForegroundColor Green
    
    # Test class instantiation
    Write-Host "Testing class instantiation..." -ForegroundColor Cyan
    
    $task = [PmcTask]::new()
    Write-Host "✓ PmcTask default constructor works: $($task.Title)" -ForegroundColor Green
    
    $taskWithTitle = [PmcTask]::new("Test Task")
    Write-Host "✓ PmcTask title constructor works: $($taskWithTitle.Title)" -ForegroundColor Green
    
    $project = [PmcProject]::new()
    Write-Host "✓ PmcProject default constructor works: $($project.Key)" -ForegroundColor Green
    
    Write-Host "`n✅ All models module tests passed!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Test failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
    exit 1
}
