# PMC Terminal v5 - MVP Quick Start

## Running the Application

### Option 1: Using the Batch File (Recommended)
Simply double-click `run-pmc.bat` or run it from command prompt:
```
run-pmc.bat
```

### Option 2: Using PowerShell
Right-click `Start-PMC.ps1` and select "Run with PowerShell", or from PowerShell:
```powershell
.\Start-PMC.ps1
```

### Option 3: Direct Execution
From PowerShell with appropriate execution policy:
```powershell
.\main-class.ps1
```

## MVP Features

This minimal viable product includes:

1. **Dashboard Screen**
   - View task summary
   - Quick navigation to other screens
   - Task list with selection

2. **Task List Screen** 
   - View all tasks with filtering
   - Toggle task completion with Space
   - Navigate to create new tasks

3. **New Task Screen**
   - Create tasks with title and description
   - Set priority and due date
   - Assign to projects

## Key Shortcuts

### Global
- `Ctrl+Q` - Exit application (with confirmation)
- `Esc` - Go back to previous screen

### Dashboard
- `N` - Create new task
- `T` - Go to task list
- `E` - Edit selected task
- `D` - Delete selected task
- `↑↓` - Navigate tasks

### Task List
- `N` - Create new task
- `Space` - Toggle task completion
- `F` - Cycle through filters (All/Active/Completed)
- `E` - Edit selected task
- `D` - Delete selected task
- `↑↓` - Navigate tasks

### New Task Form
- `↑↓` - Navigate fields
- `Enter` - Edit field / Cycle options
- `Tab` - Next field
- `S` - Save task
- `C` - Clear form
- `Esc` - Cancel

## Data Storage

Task data is automatically saved to:
`%APPDATA%\PMCTerminal\data.json`

## Requirements

- Windows PowerShell 5.1 or higher
- Windows Terminal or PowerShell console
- Minimum console size: 80x24

## Troubleshooting

If you see module loading errors:
1. Ensure all files are in the correct directories
2. Check that PowerShell execution policy allows scripts
3. Try running as Administrator if permission errors occur

For other issues, check the log file at:
`%TEMP%\PMCTerminal_YYYY-MM-DD.log`
