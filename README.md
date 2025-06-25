# PMC Terminal v5 - Class Migration Implementation

## Overview

This repository contains the refactored PowerShell TUI application "PMC Terminal v5" that has been migrated from a JavaScript-inspired architecture to a more robust, idiomatic PowerShell architecture using PowerShell classes and a Service-Oriented approach.

## Architecture Principles

### 1. Service-Oriented Architecture
- Application logic is organized into services (e.g., `DataManager`, `NavigationService`)
- Services are initialized once and made available through a central `$services` hashtable
- Each service has a specific responsibility and clear interface

### 2. Direct Interaction Model
- UI components interact with services via direct method calls
- No abstract dispatch pattern - just simple, clear method invocations
- Example: `$services.DataManager.AddTask($task)`

### 3. One-Way Data Flow & Eventing
- **Change**: State is only changed by calling service methods
- **Announce**: Services broadcast events after state changes
- **React**: UI components subscribe to events and refresh their data

### 4. Strict Data Contracts (Classes)
- All core entities (Task, Project, Settings) are defined as PowerShell classes
- No generic hashtables for business data
- Type safety and data integrity across module boundaries

### 5. Global State Purity
- Only `$global:Data` is used for shared state (managed by DataManager)
- All other dependencies passed as parameters
- No `$script:` scope pollution

## Implementation Status

### ✅ Completed Components

#### Phase 1: Base UI Classes
- `ui-classes.psm1` - Base classes (UIElement, Component, Panel, Screen)
- `panels-class.psm1` - Panel implementations (BorderPanel, ContentPanel)

#### Phase 2: Core Components
- `table-class.psm1` - Table component with sorting and selection
- `navigation-class.psm1` - Navigation menu system

#### Phase 3: Screens
- `dashboard-screen-class.psm1` - Main dashboard implementation

#### Phase 4: Services
- `screen-factory.psm1` - Factory pattern for screen creation
- `navigation-service.psm1` - Navigation stack management
- `data-manager.psm1` - Centralized data management

#### Utilities
- `error-handling.psm1` - Robust error handling and logging
- `event-system.psm1` - Event publishing and subscription
- `models.psm1` - Business entity classes (Task, Project, Settings)

#### Validation
- `test-class-migration.ps1` - Comprehensive validation suite

### 🚧 To Be Implemented

1. **Additional Screens**
   - TaskListScreen
   - NewTaskScreen
   - EditTaskScreen
   - ProjectListScreen
   - SettingsScreen
   - FilterScreen

2. **Additional Components**
   - Form components (TextInput, DatePicker, Select)
   - Dialog/Modal system
   - Status bar component
   - Progress indicators

3. **Additional Services**
   - AppStateService (application-wide state)
   - ThemeService (theming support)
   - ShortcutService (keyboard shortcuts)
   - NotificationService

## Project Structure

```
C:\Users\jhnhe\Documents\GitHub\_HELIOS - Refactored\
├── components/
│   ├── ui-classes.psm1         # Base UI classes
│   ├── table-class.psm1        # Table component
│   └── navigation-class.psm1   # Navigation component
├── layout/
│   └── panels-class.psm1       # Panel components
├── screens/
│   └── dashboard-screen-class.psm1  # Dashboard screen
├── services/
│   ├── data-manager.psm1       # Data management service
│   ├── screen-factory.psm1     # Screen factory service
│   └── navigation-service.psm1 # Navigation service
├── utilities/
│   ├── error-handling.psm1     # Error handling utilities
│   └── event-system.psm1       # Event system
├── models.psm1                 # Business entity classes
└── test-class-migration.ps1    # Validation suite
```

## Usage Example

```powershell
# Import required modules
Import-Module ".\utilities\error-handling.psm1"
Import-Module ".\utilities\event-system.psm1"
Import-Module ".\services\data-manager.psm1"
Import-Module ".\services\navigation-service.psm1"

# Initialize systems
Initialize-ErrorHandling -LogLevel "Info"
Initialize-EventSystem

# Create services
$services = @{
    DataManager = [DataManager]::new()
}
$services.Navigation = [NavigationService]::new($services)

# Create and add a task
$task = [Task]::new("Complete refactoring", "Finish the class migration")
$task.Priority = [TaskPriority]::High
$task.DueDate = [DateTime]::Now.AddDays(7)

$services.DataManager.AddTask($task)

# Navigate to dashboard
$services.Navigation.PushScreen("DashboardScreen")
```

## Running Tests

To validate the implementation:

```powershell
.\test-class-migration.ps1
```

This will run comprehensive tests on:
- Model classes (Task, Project, Settings)
- UI components (Panels, Tables, Navigation)
- Services (DataManager, NavigationService)
- Integration between components

## Migration Guidelines

When migrating additional components:

1. **Always use classes** - Define proper PowerShell classes with constructors
2. **Validate inputs** - Check parameters in constructors and methods
3. **Use Invoke-WithErrorHandling** - Wrap all public methods
4. **Publish events** - Broadcast changes for loose coupling
5. **Follow naming conventions** - Use Verb-Noun for functions, PascalCase for classes
6. **Document thoroughly** - Add comments explaining the purpose and any AI: tags for changes

## Error Handling Pattern

```powershell
[void] SomeMethod([string]$parameter) {
    Invoke-WithErrorHandling -Component "ComponentName" -Context "MethodName" -ScriptBlock {
        # Validate parameters
        if ([string]::IsNullOrWhiteSpace($parameter)) {
            throw [System.ArgumentException]::new("Parameter cannot be empty")
        }
        
        # Method implementation
        # ...
        
        # Publish event if state changed
        Publish-Event -EventName "Component.Changed" -Data @{
            Parameter = $parameter
        }
    }
}
```

## Benefits of the New Architecture

1. **Type Safety** - PowerShell validates method signatures and property types
2. **Better Debugging** - Clear stack traces with actual method names
3. **IDE Support** - Full IntelliSense for properties and methods
4. **Maintainability** - Clear separation of concerns and dependencies
5. **Performance** - Direct method calls instead of dispatch overhead
6. **Testability** - Easy to unit test individual components

## Next Steps

1. Implement remaining screens following the DashboardScreen pattern
2. Add form components for user input
3. Implement keyboard shortcut handling
4. Add theme support
5. Create installation and deployment scripts
6. Add comprehensive documentation

## Contributing

When adding new components:
- Follow the established patterns
- Ensure all public methods use error handling
- Add appropriate logging
- Include unit tests
- Update this README with your additions

## License

[Include your license information here]