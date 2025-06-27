# PowerShell 5.1 Compatibility Fix for Advanced Data Components
# AI: Addresses potential syntax issues that could cause 'if' statement errors

Write-Host "Checking for PowerShell 5.1 compatibility issues..." -ForegroundColor Cyan

$componentPath = Join-Path $PSScriptRoot "components\advanced-data-components.psm1"

if (Test-Path $componentPath) {
    try {
        # Test if the module can be imported without syntax errors
        Import-Module $componentPath -Force -ErrorAction Stop
        Write-Host "SUCCESS: advanced-data-components.psm1 imported without syntax errors" -ForegroundColor Green
        
        # Test if the main function exists
        if (Get-Command "New-TuiDataTable" -ErrorAction SilentlyContinue) {
            Write-Host "SUCCESS: New-TuiDataTable function is available" -ForegroundColor Green
            
            # Test basic component creation
            $testTable = New-TuiDataTable -Props @{
                Name = "TestTable"
                Columns = @(
                    @{ Name = "Test"; Header = "Test Column"; Width = 20 }
                )
                Data = @()
            }
            
            if ($testTable -and $testTable.Type -eq "DataTable") {
                Write-Host "SUCCESS: DataTable component created successfully" -ForegroundColor Green
            } else {
                Write-Host "WARNING: DataTable component creation returned unexpected result" -ForegroundColor Yellow
            }
        } else {
            Write-Host "FAIL: New-TuiDataTable function not found!" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "FAIL: advanced-data-components.psm1 has syntax errors:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host "Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
        Write-Host "Position: $($_.InvocationInfo.OffsetInLine)" -ForegroundColor Red
    }
} else {
    Write-Host "FAIL: advanced-data-components.psm1 not found at $componentPath" -ForegroundColor Red
}

Write-Host "`nCompatibility check completed." -ForegroundColor Cyan
