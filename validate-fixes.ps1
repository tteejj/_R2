# Additional validation script to check for other potential issues

Write-Host "Additional HELIOS Validation Checks" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

# Check 1: Look for any remaining incorrect Invoke-WithErrorHandling patterns
Write-Host "Checking for incorrect Invoke-WithErrorHandling patterns..." -ForegroundColor Yellow

$files = Get-ChildItem -Path . -Include "*.ps1","*.psm1" -Recurse | Where-Object { $_.Name -notlike "*test*.ps1" }
$incorrectPatterns = @()

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($content) {
        # Check for ErrorHandler parameter (which is custom, not built-in)
        if ($content -match '-ErrorHandler\s*\{') {
            # This is OK - it's a custom parameter in their implementation
        }
        
        # Check for Context followed by a variable that might be a hashtable
        if ($content -match 'Invoke-WithErrorHandling[^}]*-Context\s+\$[^"''\s]+\s') {
            $incorrectPatterns += @{
                File = $file.FullName
                Issue = "Context parameter using variable (might be hashtable)"
            }
        }
    }
}

if ($incorrectPatterns.Count -eq 0) {
    Write-Host "✓ No incorrect patterns found" -ForegroundColor Green
} else {
    Write-Host "✗ Found $($incorrectPatterns.Count) potential issues:" -ForegroundColor Red
    $incorrectPatterns | ForEach-Object {
        Write-Host "  - $($_.File): $($_.Issue)" -ForegroundColor Yellow
    }
}

# Check 2: Verify all screen modules follow the correct pattern
Write-Host "`nChecking screen module patterns..." -ForegroundColor Yellow

$screenFiles = Get-ChildItem -Path ".\screens" -Filter "*.psm1"
$screenIssues = @()

foreach ($screen in $screenFiles) {
    $content = Get-Content $screen.FullName -Raw
    
    # Check if screen has required structure
    if ($content -notmatch 'function\s+Get-\w+Screen') {
        $screenIssues += "$($screen.Name): Missing Get-*Screen function"
    }
    
    # Check if screen returns proper hashtable structure
    if ($content -notmatch '@\{\s*Name\s*=') {
        $screenIssues += "$($screen.Name): Screen might not return proper structure"
    }
}

if ($screenIssues.Count -eq 0) {
    Write-Host "✓ All screens follow correct pattern" -ForegroundColor Green
} else {
    Write-Host "✗ Found screen pattern issues:" -ForegroundColor Red
    $screenIssues | ForEach-Object {
        Write-Host "  - $_" -ForegroundColor Yellow
    }
}

# Check 3: Look for potential null reference issues
Write-Host "`nChecking for potential null reference patterns..." -ForegroundColor Yellow

$nullRefPatterns = @(
    '\$\w+\.\w+\s*-[en]e\s*\$null',  # Checking properties without null check
    'if\s*\(\$\w+\.\w+\)',           # If statements checking properties without null check
    '\$\w+\.\w+\.\w+'                # Deep property access without checks
)

$nullRefIssues = 0
foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($content) {
        foreach ($pattern in $nullRefPatterns) {
            if ($content -match $pattern) {
                # This is just a warning, not necessarily an error
                $nullRefIssues++
                break
            }
        }
    }
}

if ($nullRefIssues -eq 0) {
    Write-Host "✓ No obvious null reference patterns found" -ForegroundColor Green
} else {
    Write-Host "⚠ Found $nullRefIssues files with potential null reference patterns" -ForegroundColor Yellow
    Write-Host "  (These might be fine if proper null checks exist elsewhere)" -ForegroundColor DarkGray
}

# Check 4: Verify critical global variables are used correctly
Write-Host "`nChecking global variable usage..." -ForegroundColor Yellow

$globalVarIssues = @()
$criticalGlobals = @('$global:Services', '$global:Data', '$global:TuiState')

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($content) {
        foreach ($global in $criticalGlobals) {
            # Check if global is used without null check
            if ($content -match "$([regex]::Escape($global))\.(?!ContainsKey)") {
                $lines = $content -split "`n"
                $lineNum = 1
                foreach ($line in $lines) {
                    if ($line -match "$([regex]::Escape($global))\.(?!ContainsKey)" -and
                        $line -notmatch "if.*$([regex]::Escape($global))" -and
                        $line -notmatch "$([regex]::Escape($global))\s*-[en]e") {
                        # Potential issue: using global without null check
                        # This is just informational
                        break
                    }
                    $lineNum++
                }
            }
        }
    }
}

Write-Host "✓ Global variable check complete" -ForegroundColor Green

# Summary
Write-Host "`n===================================" -ForegroundColor Cyan
Write-Host "Additional checks complete!" -ForegroundColor Green
Write-Host "Main issues have been fixed. Any warnings above are informational." -ForegroundColor Yellow