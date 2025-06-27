# Test Script for Class-Based Services
# This script tests the new class-based NavigationService and KeybindingService

param([switch]$Verbose)

# Set up test environment
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Get script directory
$script:BasePath = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Testing Class-Based Services..." -ForegroundColor Cyan

try {
    # Test 1: Import utilities
    Write-Host "1. Testing utility imports..." -ForegroundColor Yellow
    Import-Module "$script:BasePath\utilities\error-handling.psm1" -Force
    Write-Host "   ✓ Error handling imported" -ForegroundColor Green
    
    # Test 2: Import services  
    Write-Host "2. Testing service imports..." -ForegroundColor Yellow
    Import-Module "$script:BasePath\services\navigation-service.psm1" -Force
    Import-Module "$script:BasePath\services\keybinding-service.psm1" -Force
    Write-Host "   ✓ Services imported" -ForegroundColor Green
    
    # Test 3: Create mock services
    Write-Host "3. Testing service creation..." -ForegroundColor Yellow
    $mockServices = @{
        DataManager = @{ GetTasks = { return @() } }
    }
    
    # Test NavigationService
    $navService = Initialize-NavigationService $mockServices
    if ($navService -and $navService.GetType().Name -eq 'NavigationService') {
        Write-Host "   ✓ NavigationService created successfully" -ForegroundColor Green
    } else {
        throw "NavigationService creation failed"
    }
    
    # Test KeybindingService
    $keyService = Initialize-KeybindingService -EnableChords $false
    if ($keyService -and $keyService.GetType().Name -eq 'KeybindingService') {
        Write-Host "   ✓ KeybindingService created successfully" -ForegroundColor Green
    } else {
        throw "KeybindingService creation failed"
    }
    
    # Test 4: Test service methods
    Write-Host "4. Testing service methods..." -ForegroundColor Yellow
    
    # Test navigation routes
    $routes = $navService.GetAvailableRoutes()
    if ($routes.Count -gt 0) {
        Write-Host "   ✓ Navigation routes available: $($routes.Count)" -ForegroundColor Green
    } else {
        throw "No navigation routes found"
    }
    
    # Test keybinding operations
    $keyService.SetBinding("test.action", [System.ConsoleKey]::F1, @())
    $description = $keyService.GetBindingDescription("test.action")
    if ($description) {
        Write-Host "   ✓ Keybinding operations working: $description" -ForegroundColor Green
    } else {
        throw "Keybinding operations failed"
    }
    
    # Test 5: Test class method calls (no scriptblock patterns)
    Write-Host "5. Testing direct method calls..." -ForegroundColor Yellow
    
    # Test navigation
    $validRoute = $navService.IsValidRoute("/dashboard")
    if ($validRoute) {
        Write-Host "   ✓ Navigation route validation works" -ForegroundColor Green
    } else {
        throw "Navigation route validation failed"
    }
    
    # Test keybinding
    $keyInfo = [System.ConsoleKeyInfo]::new([char]0, [System.ConsoleKey]::F1, $false, $false, $false)
    $actionResult = $keyService.IsAction("test.action", $keyInfo)
    if ($actionResult) {
        Write-Host "   ✓ Keybinding action detection works" -ForegroundColor Green
    } else {
        throw "Keybinding action detection failed"
    }
    
    Write-Host "`n🎉 All tests passed! Class-based services are working correctly." -ForegroundColor Green
    Write-Host "The application should now start properly without NavigationService errors." -ForegroundColor Green
    
} catch {
    Write-Host "`n❌ Test failed: $_" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    exit 1
}

if ($Verbose) {
    Write-Host "`nDetailed Service Information:" -ForegroundColor Blue
    Write-Host "NavigationService type: $($navService.GetType().FullName)" -ForegroundColor Gray
    Write-Host "NavigationService routes: $($navService.GetAvailableRoutes() -join ', ')" -ForegroundColor Gray
    Write-Host "KeybindingService type: $($keyService.GetType().FullName)" -ForegroundColor Gray
    Write-Host "KeybindingService bindings: $($keyService.GetAllBindings().Count)" -ForegroundColor Gray
}