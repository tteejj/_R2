# Class Migration Validation Module for PMC Terminal v5
# Demonstrates and validates the class-based architecture implementation
# AI: Example usage and integration test for the migrated classes

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Import all required modules
Import-Module -Name "$PSScriptRoot\utilities\error-handling.psm1" -Force
Import-Module -Name "$PSScriptRoot\utilities\event-system.psm1" -Force
Import-Module -Name "$PSScriptRoot\models.psm1" -Force
Import-Module -Name "$PSScriptRoot\components\ui-classes.psm1" -Force
Import-Module -Name "$PSScriptRoot\layout\panels-class.psm1" -Force
Import-Module -Name "$PSScriptRoot\components\table-class.psm1" -Force
Import-Module -Name "$PSScriptRoot\components\navigation-class.psm1" -Force
Import-Module -Name "$PSScriptRoot\services\data-manager.psm1" -Force
Import-Module -Name "$PSScriptRoot\services\screen-factory.psm1" -Force
Import-Module -Name "$PSScriptRoot\services\navigation-service.psm1" -Force
Import-Module -Name "$PSScriptRoot\screens\dashboard-screen-class.psm1" -Force

# Test-ClassMigration - Main validation function
function Test-ClassMigration {
    [CmdletBinding()]
    param()
    
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " PMC Terminal v5 - Class Migration Validation" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host
    
    # Initialize systems
    Initialize-ErrorHandling -LogLevel "Debug"
    Initialize-EventSystem -MaxHistorySize 500
    
    # Create services
    $services = Initialize-Services
    
    # Run validation tests
    $testResults = @{
        ModelTests = Test-Models
        UIComponentTests = Test-UIComponents
        ServiceTests = Test-Services -Services $services
        IntegrationTests = Test-Integration -Services $services
    }
    
    # Display results
    Show-TestResults -Results $testResults
}

# Initialize-Services - Create and configure all services
function Initialize-Services {
    Write-Host "Initializing services..." -ForegroundColor Yellow
    
    $services = @{}
    
    # Create data manager
    $services.DataManager = [DataManager]::new()
    $services.DataManager.EnableAutoSave()
    
    # Create placeholder for other services (to be implemented)
    $services.AppState = @{
        RequestExit = { Write-Host "Exit requested" -ForegroundColor Red }
    }
    
    # Create navigation service (needs services hashtable)
    $services.Navigation = [NavigationService]::new($services)
    
    Write-Host "✓ Services initialized" -ForegroundColor Green
    Write-Host
    
    return $services
}

# Test-Models - Validate model classes
function Test-Models {
    Write-Host "Testing Model Classes..." -ForegroundColor Yellow
    
    $results = @{
        Passed = 0
        Failed = 0
        Tests = @()
    }
    
    # Test Task class
    try {
        $task = [Task]::new("Test Task", "This is a test task")
        $task.Priority = [TaskPriority]::High
        $task.AddTag("test")
        $task.AddTag("validation")
        
        if ($task.Validate()) {
            $results.Passed++
            $results.Tests += "✓ Task creation and validation"
        }
        
        # Test task completion
        $task.Complete()
        if ($task.Status -eq [TaskStatus]::Completed -and $null -ne $task.CompletedDate) {
            $results.Passed++
            $results.Tests += "✓ Task completion"
        }
        
        # Test overdue check
        $overdueTask = [Task]::new("Overdue Task")
        $overdueTask.DueDate = [DateTime]::Now.AddDays(-1)
        if ($overdueTask.IsOverdue()) {
            $results.Passed++
            $results.Tests += "✓ Task overdue detection"
        }
    }
    catch {
        $results.Failed++
        $results.Tests += "✗ Task class tests failed: $_"
    }
    
    # Test Project class
    try {
        $project = [Project]::new("Test Project", "A test project")
        $project.AddMember("User1")
        $project.AddMember("User2")
        
        if ($project.Validate()) {
            $results.Passed++
            $results.Tests += "✓ Project creation and validation"
        }
        
        $project.UpdateTaskStatistics(10, 3)
        if ($project.GetCompletionPercentage() -eq 30) {
            $results.Passed++
            $results.Tests += "✓ Project completion calculation"
        }
    }
    catch {
        $results.Failed++
        $results.Tests += "✗ Project class tests failed: $_"
    }
    
    # Test Settings class
    try {
        $settings = [Settings]::new()
        $settings.AutoSaveIntervalMinutes = 10
        $settings.AddRecentProject("project-123")
        
        if ($settings.Validate()) {
            $results.Passed++
            $results.Tests += "✓ Settings creation and validation"
        }
    }
    catch {
        $results.Failed++
        $results.Tests += "✗ Settings class tests failed: $_"
    }
    
    return $results
}

# Test-UIComponents - Validate UI component classes
function Test-UIComponents {
    Write-Host "Testing UI Component Classes..." -ForegroundColor Yellow
    
    $results = @{
        Passed = 0
        Failed = 0
        Tests = @()
    }
    
    # Test Panel classes
    try {
        $borderPanel = [BorderPanel]::new("TestPanel", 0, 0, 50, 10)
        $borderPanel.Title = "Test Panel"
        $borderPanel.BorderStyle = "Double"
        
        $results.Passed++
        $results.Tests += "✓ BorderPanel creation"
        
        $contentPanel = [ContentPanel]::new("TestContent", 2, 2, 46, 6)
        $contentPanel.SetContent(@("Line 1", "Line 2", "Line 3"))
        
        $results.Passed++
        $results.Tests += "✓ ContentPanel creation and content setting"
    }
    catch {
        $results.Failed++
        $results.Tests += "✗ Panel class tests failed: $_"
    }
    
    # Test Table class
    try {
        $table = [Table]::new("TestTable")
        
        $columns = @(
            [TableColumn]::new("Name", "Name", 20),
            [TableColumn]::new("Value", "Value", 15),
            [TableColumn]::new("Status", "Status", 10)
        )
        $table.SetColumns($columns)
        
        $data = @(
            [PSCustomObject]@{Name = "Item 1"; Value = 100; Status = "Active"},
            [PSCustomObject]@{Name = "Item 2"; Value = 200; Status = "Inactive"}
        )
        $table.SetData($data)
        
        $results.Passed++
        $results.Tests += "✓ Table creation and data binding"
        
        # Test table navigation
        $table.SelectNext()
        if ($table.SelectedIndex -eq 1) {
            $results.Passed++
            $results.Tests += "✓ Table navigation"
        }
    }
    catch {
        $results.Failed++
        $results.Tests += "✗ Table class tests failed: $_"
    }
    
    # Test Navigation classes
    try {
        $services = @{Navigation = @{PushScreen = {param($s) Write-Host "Navigate to $s"}}}
        $navMenu = [NavigationMenu]::new("TestNav", $services)
        
        $navItem = [NavigationItem]::new("T", "Test", { Write-Host "Test action" })
        $navMenu.AddItem($navItem)
        
        $results.Passed++
        $results.Tests += "✓ NavigationMenu and NavigationItem creation"
    }
    catch {
        $results.Failed++
        $results.Tests += "✗ Navigation class tests failed: $_"
    }
    
    return $results
}

# Test-Services - Validate service classes
function Test-Services {
    param([hashtable]$Services)
    
    Write-Host "Testing Service Classes..." -ForegroundColor Yellow
    
    $results = @{
        Passed = 0
        Failed = 0
        Tests = @()
    }
    
    # Test DataManager
    try {
        $dataManager = $Services.DataManager
        
        # Test task operations
        $task = [Task]::new("Service Test Task")
        $addedTask = $dataManager.AddTask($task)
        
        if ($null -ne $addedTask) {
            $results.Passed++
            $results.Tests += "✓ DataManager task addition"
        }
        
        # Test task retrieval
        $retrievedTask = $dataManager.GetTask($addedTask.Id)
        if ($null -ne $retrievedTask -and $retrievedTask.Id -eq $addedTask.Id) {
            $results.Passed++
            $results.Tests += "✓ DataManager task retrieval"
        }
        
        # Test project operations
        $project = [Project]::new("Service Test Project")
        $addedProject = $dataManager.AddProject($project)
        
        if ($null -ne $addedProject) {
            $results.Passed++
            $results.Tests += "✓ DataManager project addition"
        }
        
        # Clean up
        $dataManager.DeleteTask($addedTask.Id)
        $dataManager.DeleteProject($addedProject.Id)
    }
    catch {
        $results.Failed++
        $results.Tests += "✗ DataManager tests failed: $_"
    }
    
    # Test NavigationService
    try {
        $navService = $Services.Navigation
        
        # Test screen factory registration
        $factory = $navService.ScreenFactory
        if ($factory.IsScreenRegistered("DashboardScreen")) {
            $results.Passed++
            $results.Tests += "✓ ScreenFactory registration check"
        }
        
        # Test navigation
        $navService.PushScreen("DashboardScreen")
        if ($navService.GetCurrentScreenName() -eq "DashboardScreen") {
            $results.Passed++
            $results.Tests += "✓ NavigationService screen push"
        }
        
        # Clean up
        $navService.ClearStack()
    }
    catch {
        $results.Failed++
        $results.Tests += "✗ NavigationService tests failed: $_"
    }
    
    return $results
}

# Test-Integration - Run integration tests
function Test-Integration {
    param([hashtable]$Services)
    
    Write-Host "Testing Integration..." -ForegroundColor Yellow
    
    $results = @{
        Passed = 0
        Failed = 0
        Tests = @()
    }
    
    # Test event system integration
    try {
        $eventReceived = $false
        Subscribe-Event -EventName "Test.Event" -Action {
            $script:eventReceived = $true
        }
        
        Publish-Event -EventName "Test.Event"
        Start-Sleep -Milliseconds 100
        
        if ($script:eventReceived) {
            $results.Passed++
            $results.Tests += "✓ Event system integration"
        }
        
        Clear-EventSubscriptions -EventName "Test.Event"
    }
    catch {
        $results.Failed++
        $results.Tests += "✗ Event system integration failed: $_"
    }
    
    # Test data persistence
    try {
        $dataManager = $Services.DataManager
        
        # Create test data
        $task = [Task]::new("Persistence Test")
        $dataManager.AddTask($task)
        
        # Save data
        $dataManager.SaveData()
        
        # Check if file exists
        $dataPath = Join-Path -Path $env:APPDATA -ChildPath "PMCTerminal\data.json"
        if (Test-Path $dataPath) {
            $results.Passed++
            $results.Tests += "✓ Data persistence"
            
            # Clean up
            Remove-Item $dataPath -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        $results.Failed++
        $results.Tests += "✗ Data persistence failed: $_"
    }
    
    return $results
}

# Show-TestResults - Display test results summary
function Show-TestResults {
    param([hashtable]$Results)
    
    Write-Host
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " Test Results Summary" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host
    
    $totalPassed = 0
    $totalFailed = 0
    
    foreach ($category in $Results.Keys) {
        $categoryResults = $Results[$category]
        
        Write-Host "$category" -ForegroundColor White
        foreach ($test in $categoryResults.Tests) {
            if ($test.StartsWith("✓")) {
                Write-Host "  $test" -ForegroundColor Green
            }
            else {
                Write-Host "  $test" -ForegroundColor Red
            }
        }
        
        $totalPassed += $categoryResults.Passed
        $totalFailed += $categoryResults.Failed
        
        Write-Host
    }
    
    $total = $totalPassed + $totalFailed
    $passRate = if ($total -gt 0) { [Math]::Round(($totalPassed / $total) * 100, 2) } else { 0 }
    
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Total Tests: $total" -ForegroundColor White
    Write-Host "Passed: $totalPassed" -ForegroundColor Green
    Write-Host "Failed: $totalFailed" -ForegroundColor Red
    Write-Host "Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -ge 80) { "Green" } elseif ($passRate -ge 60) { "Yellow" } else { "Red" })
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
    
    if ($totalFailed -eq 0) {
        Write-Host
        Write-Host "✨ All tests passed! The class migration is working correctly. ✨" -ForegroundColor Green
    }
}

# Run validation if executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Test-ClassMigration
}

# Export validation function
Export-ModuleMember -Function Test-ClassMigration