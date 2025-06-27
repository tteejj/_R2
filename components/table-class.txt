# Table Component Classes Module for PMC Terminal v5
# Implements table display functionality with column formatting and selection
# AI: Implements Phase 2.1 of the class migration plan - Table Component

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Import base classes
using module '.\ui-classes.psm1'

# Import utilities for error handling
Import-Module -Name "$PSScriptRoot\..\utilities\error-handling.psm1" -Force

# TableColumn - Defines a single column in a table
class TableColumn {
    [string] $Name
    [string] $Header
    [int] $Width
    [scriptblock] $Formatter
    [string] $Alignment = "Left" # Left, Center, Right
    [bool] $Sortable = $true
    
    TableColumn([string]$name, [string]$header, [int]$width) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw [System.ArgumentException]::new("Column name cannot be null or empty")
        }
        if ($width -le 0) {
            throw [System.ArgumentException]::new("Column width must be positive")
        }
        
        $this.Name = $name
        $this.Header = $header
        $this.Width = $width
    }
    
    # AI: Format a value according to column settings
    [string] FormatValue([object]$value) {
        $formattedValue = ""
        
        if ($null -ne $this.Formatter) {
            try {
                $formattedValue = & $this.Formatter $value
            }
            catch {
                Write-Log -Level Warning -Message "Column formatter failed: $_" -Component "TableColumn"
                $formattedValue = $value.ToString()
            }
        }
        else {
            $formattedValue = if ($null -eq $value) { "" } else { $value.ToString() }
        }
        
        # Apply width constraints
        if ($formattedValue.Length -gt $this.Width) {
            $formattedValue = $formattedValue.Substring(0, $this.Width - 3) + "..."
        }
        
        # Apply alignment
        switch ($this.Alignment) {
            "Center" {
                $padding = $this.Width - $formattedValue.Length
                $padLeft = [Math]::Floor($padding / 2)
                $padRight = $padding - $padLeft
                $formattedValue = (' ' * $padLeft) + $formattedValue + (' ' * $padRight)
            }
            "Right" {
                $formattedValue = $formattedValue.PadLeft($this.Width)
            }
            default {
                $formattedValue = $formattedValue.PadRight($this.Width)
            }
        }
        
        return $formattedValue
    }
}

# Table - Component for displaying tabular data with selection and scrolling
class Table : Component {
    [TableColumn[]] $Columns = @()
    [object[]] $Data = @()
    [int] $SelectedIndex = 0
    [bool] $ShowHeaders = $true
    [bool] $ShowRowNumbers = $false
    [ConsoleColor] $HeaderColor = [ConsoleColor]::Cyan
    [ConsoleColor] $SelectedRowColor = [ConsoleColor]::Yellow
    [ConsoleColor] $TextColor = [ConsoleColor]::White
    [int] $ScrollOffset = 0
    [int] $MaxVisibleRows = 10
    [string] $SortColumn = ""
    [bool] $SortDescending = $false
    
    Table([string]$name) : base($name) {
    }
    
    [void] SetColumns([TableColumn[]]$columns) {
        if ($null -eq $columns) {
            throw [System.ArgumentNullException]::new("columns", "Columns cannot be null")
        }
        if ($columns.Count -eq 0) {
            throw [System.ArgumentException]::new("Table must have at least one column")
        }
        
        $this.Columns = $columns
    }
    
    [void] SetData([object[]]$data) {
        $this.Data = if ($null -eq $data) { @() } else { $data }
        
        # Reset selection if out of bounds
        if ($this.SelectedIndex -ge $this.Data.Count) {
            $this.SelectedIndex = if ($this.Data.Count -gt 0) { $this.Data.Count - 1 } else { 0 }
        }
        
        # Apply current sort if set
        if (-not [string]::IsNullOrWhiteSpace($this.SortColumn)) {
            $this.SortData($this.SortColumn, $this.SortDescending)
        }
    }
    
    [void] SelectNext() {
        if ($this.SelectedIndex -lt $this.Data.Count - 1) {
            $this.SelectedIndex++
            $this.EnsureSelectedVisible()
        }
    }
    
    [void] SelectPrevious() {
        if ($this.SelectedIndex -gt 0) {
            $this.SelectedIndex--
            $this.EnsureSelectedVisible()
        }
    }
    
    [void] SelectFirst() {
        $this.SelectedIndex = 0
        $this.ScrollOffset = 0
    }
    
    [void] SelectLast() {
        if ($this.Data.Count -gt 0) {
            $this.SelectedIndex = $this.Data.Count - 1
            $this.EnsureSelectedVisible()
        }
    }
    
    [object] GetSelectedItem() {
        if ($this.Data.Count -gt 0 -and $this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Data.Count) {
            return $this.Data[$this.SelectedIndex]
        }
        return $null
    }
    
    [void] SortData([string]$columnName, [bool]$descending = $false) {
        $column = $this.Columns | Where-Object { $_.Name -eq $columnName } | Select-Object -First 1
        
        if ($null -eq $column) {
            Write-Log -Level Warning -Message "Sort column '$columnName' not found" -Component "Table"
            return
        }
        
        if (-not $column.Sortable) {
            Write-Log -Level Warning -Message "Column '$columnName' is not sortable" -Component "Table"
            return
        }
        
        $this.SortColumn = $columnName
        $this.SortDescending = $descending
        
        try {
            $this.Data = if ($descending) {
                $this.Data | Sort-Object -Property $columnName -Descending
            }
            else {
                $this.Data | Sort-Object -Property $columnName
            }
        }
        catch {
            Write-Log -Level Error -Message "Failed to sort by column '$columnName': $_" -Component "Table"
        }
    }
    
    # AI: Ensure selected row is visible in viewport
    hidden [void] EnsureSelectedVisible() {
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        }
        elseif ($this.SelectedIndex -ge ($this.ScrollOffset + $this.MaxVisibleRows)) {
            $this.ScrollOffset = $this.SelectedIndex - $this.MaxVisibleRows + 1
        }
    }
    
    [string] Render() {
        return Invoke-WithErrorHandling -Component "Table" -Context "Render:$($this.Name)" -ScriptBlock {
            if ($this.Columns.Count -eq 0) {
                return ""
            }
            
            $tableBuilder = [System.Text.StringBuilder]::new()
            $currentY = 0
            
            # Render headers if enabled
            if ($this.ShowHeaders) {
                [void]$tableBuilder.Append($this.RenderHeaders())
                $currentY++
                
                # Header separator
                [void]$tableBuilder.Append($this.RenderSeparator())
                $currentY++
            }
            
            # Render data rows
            $endRow = [Math]::Min($this.ScrollOffset + $this.MaxVisibleRows, $this.Data.Count)
            
            for ($i = $this.ScrollOffset; $i -lt $endRow; $i++) {
                $isSelected = ($i -eq $this.SelectedIndex)
                [void]$tableBuilder.Append($this.RenderRow($this.Data[$i], $i, $isSelected))
                $currentY++
            }
            
            # Fill empty rows if data doesn't fill viewport
            $emptyRows = $this.MaxVisibleRows - ($endRow - $this.ScrollOffset)
            for ($i = 0; $i -lt $emptyRows; $i++) {
                [void]$tableBuilder.Append($this.RenderEmptyRow())
                $currentY++
            }
            
            return $tableBuilder.ToString()
        }
    }
    
    hidden [string] RenderHeaders() {
        $headerBuilder = [System.Text.StringBuilder]::new()
        
        [void]$headerBuilder.Append($this.SetColor($this.HeaderColor))
        
        if ($this.ShowRowNumbers) {
            [void]$headerBuilder.Append(" # ".PadRight(5))
            [void]$headerBuilder.Append(" | ")
        }
        
        foreach ($column in $this.Columns) {
            $headerText = $column.Header
            
            # Add sort indicator
            if ($column.Name -eq $this.SortColumn) {
                $sortIndicator = if ($this.SortDescending) { " ▼" } else { " ▲" }
                $headerText += $sortIndicator
            }
            
            [void]$headerBuilder.Append($column.FormatValue($headerText))
            [void]$headerBuilder.Append(" | ")
        }
        
        [void]$headerBuilder.Append($this.ResetColor())
        [void]$headerBuilder.AppendLine()
        
        return $headerBuilder.ToString()
    }
    
    hidden [string] RenderSeparator() {
        $separatorBuilder = [System.Text.StringBuilder]::new()
        
        if ($this.ShowRowNumbers) {
            [void]$separatorBuilder.Append("-" * 5)
            [void]$separatorBuilder.Append("-+-")
        }
        
        foreach ($column in $this.Columns) {
            [void]$separatorBuilder.Append("-" * $column.Width)
            [void]$separatorBuilder.Append("-+-")
        }
        
        # Remove last separator
        if ($separatorBuilder.Length -ge 3) {
            $separatorBuilder.Length -= 3
        }
        
        [void]$separatorBuilder.AppendLine()
        
        return $separatorBuilder.ToString()
    }
    
    hidden [string] RenderRow([object]$rowData, [int]$rowIndex, [bool]$isSelected) {
        $rowBuilder = [System.Text.StringBuilder]::new()
        
        $rowColor = if ($isSelected) { $this.SelectedRowColor } else { $this.TextColor }
        [void]$rowBuilder.Append($this.SetColor($rowColor))
        
        if ($this.ShowRowNumbers) {
            [void]$rowBuilder.Append(($rowIndex + 1).ToString().PadRight(5))
            [void]$rowBuilder.Append(" | ")
        }
        
        foreach ($column in $this.Columns) {
            $value = $null
            
            # AI: Safe property access with error handling
            try {
                if ($null -ne $rowData) {
                    $value = $rowData.($column.Name)
                }
            }
            catch {
                Write-Log -Level Warning -Message "Failed to access property '$($column.Name)': $_" -Component "Table"
                $value = "ERROR"
            }
            
            [void]$rowBuilder.Append($column.FormatValue($value))
            [void]$rowBuilder.Append(" | ")
        }
        
        [void]$rowBuilder.Append($this.ResetColor())
        [void]$rowBuilder.AppendLine()
        
        return $rowBuilder.ToString()
    }
    
    hidden [string] RenderEmptyRow() {
        $emptyBuilder = [System.Text.StringBuilder]::new()
        
        if ($this.ShowRowNumbers) {
            [void]$emptyBuilder.Append(" " * 5)
            [void]$emptyBuilder.Append(" | ")
        }
        
        foreach ($column in $this.Columns) {
            [void]$emptyBuilder.Append(" " * $column.Width)
            [void]$emptyBuilder.Append(" | ")
        }
        
        [void]$emptyBuilder.AppendLine()
        
        return $emptyBuilder.ToString()
    }
    
    # AI: Helper methods for ANSI colors
    hidden [string] SetColor([ConsoleColor]$color) {
        $colorMap = @{
            'Black' = 30; 'DarkRed' = 31; 'DarkGreen' = 32; 'DarkYellow' = 33
            'DarkBlue' = 34; 'DarkMagenta' = 35; 'DarkCyan' = 36; 'Gray' = 37
            'DarkGray' = 90; 'Red' = 91; 'Green' = 92; 'Yellow' = 93
            'Blue' = 94; 'Magenta' = 95; 'Cyan' = 96; 'White' = 97
        }
        $colorCode = $colorMap[$color.ToString()]
        return "`e[${colorCode}m"
    }
    
    hidden [string] ResetColor() {
        return "`e[0m"
    }
}

# Export all classes
Export-ModuleMember -Function * -Cmdlet * -Variable * -Alias *