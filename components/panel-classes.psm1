# Panel Classes Module - Specialized panel implementations
# Fixes the Context parameter binding issues by using strongly-typed classes

using namespace System.Collections.Generic
using namespace System.Text

# Import base classes
using module .\ui-classes.psm1

# Import utilities
Import-Module "$PSScriptRoot\..\utilities\exceptions.psm1" -Force
Import-Module "$PSScriptRoot\..\utilities\logging.psm1" -Force

# BorderPanel - Panel with customizable border
class BorderPanel : Panel {
    [ConsoleColor] $BorderColor = [ConsoleColor]::Gray
    [string] $BorderStyle = "Single" # Single, Double, Rounded
    hidden [hashtable] $BorderChars = @{
        Single = @{
            TopLeft = "┌"; TopRight = "┐"; BottomLeft = "└"; BottomRight = "┘"
            Horizontal = "─"; Vertical = "│"
        }
        Double = @{
            TopLeft = "╔"; TopRight = "╗"; BottomLeft = "╚"; BottomRight = "╝"
            Horizontal = "═"; Vertical = "║"
        }
        Rounded = @{
            TopLeft = "╭"; TopRight = "╮"; BottomLeft = "╰"; BottomRight = "╯"
            Horizontal = "─"; Vertical = "│"
        }
    }
    
    BorderPanel([string]$name, [int]$x, [int]$y, [int]$width, [int]$height) : base($name, $x, $y, $width, $height) {
        Write-Log -Level Debug -Message "Creating BorderPanel: $name at ($x,$y) size ($width,$height)"
    }
    
    [string] Render() {
        return Invoke-WithErrorHandling -Component "BorderPanel" -Context "Render.$($this.Name)" -ScriptBlock {
            $output = [StringBuilder]::new()
            
            if ($this.ShowBorder) {
                [void]$output.Append($this.RenderBorder())
            }
            
            # Render children inside border
            $contentArea = $this.GetContentArea()
            foreach ($child in $this.Children) {
                if ($child.Visible) {
                    [void]$output.Append($child.Render())
                }
            }
            
            return $output.ToString()
        }
    }
    
    hidden [string] RenderBorder() {
        $chars = $this.BorderChars[$this.BorderStyle]
        $output = [StringBuilder]::new()
        
        # Top border
        [void]$output.Append("`e[$($this.Y);$($this.X)H")
        [void]$output.Append($chars.TopLeft)
        
        if (-not [string]::IsNullOrEmpty($this.Title)) {
            $titleText = " $($this.Title) "
            $titleLength = $titleText.Length
            $borderWidth = $this.Width - 2
            $leftPadding = [Math]::Max(0, ($borderWidth - $titleLength) / 2)
            
            [void]$output.Append($chars.Horizontal * [Math]::Floor($leftPadding))
            [void]$output.Append($titleText)
            [void]$output.Append($chars.Horizontal * [Math]::Ceiling($borderWidth - $titleLength - $leftPadding))
        } else {
            [void]$output.Append($chars.Horizontal * ($this.Width - 2))
        }
        
        [void]$output.Append($chars.TopRight)
        
        # Side borders
        for ($i = 1; $i -lt $this.Height - 1; $i++) {
            [void]$output.Append("`e[$($this.Y + $i);$($this.X)H")
            [void]$output.Append($chars.Vertical)
            [void]$output.Append("`e[$($this.Y + $i);$($this.X + $this.Width - 1)H")
            [void]$output.Append($chars.Vertical)
        }
        
        # Bottom border
        [void]$output.Append("`e[$($this.Y + $this.Height - 1);$($this.X)H")
        [void]$output.Append($chars.BottomLeft)
        [void]$output.Append($chars.Horizontal * ($this.Width - 2))
        [void]$output.Append($chars.BottomRight)
        
        return $output.ToString()
    }
    
    hidden [hashtable] GetContentArea() {
        if ($this.ShowBorder) {
            return @{
                X = $this.X + 1
                Y = $this.Y + 1
                Width = $this.Width - 2
                Height = $this.Height - 2
            }
        } else {
            return @{
                X = $this.X
                Y = $this.Y
                Width = $this.Width
                Height = $this.Height
            }
        }
    }
}

# ContentPanel - Panel that displays scrollable text content
class ContentPanel : Panel {
    [string[]] $Content = @()
    [int] $ScrollOffset = 0
    [bool] $WordWrap = $true
    [ConsoleColor] $TextColor = [ConsoleColor]::Gray
    
    ContentPanel([string]$name, [int]$x, [int]$y, [int]$width, [int]$height) : base($name, $x, $y, $width, $height) {
        Write-Log -Level Debug -Message "Creating ContentPanel: $name"
    }
    
    [void] SetContent([string[]]$content) {
        $this.Content = $content ?? @()
        $this.ScrollOffset = 0
        Write-Log -Level Debug -Message "ContentPanel $($this.Name): Set content with $($this.Content.Count) lines"
    }
    
    [void] AppendContent([string]$text) {
        $this.Content += $text
    }
    
    [void] ClearContent() {
        $this.Content = @()
        $this.ScrollOffset = 0
    }
    
    [void] ScrollUp([int]$lines = 1) {
        $this.ScrollOffset = [Math]::Max(0, $this.ScrollOffset - $lines)
    }
    
    [void] ScrollDown([int]$lines = 1) {
        $maxScroll = [Math]::Max(0, $this.Content.Count - $this.Height)
        $this.ScrollOffset = [Math]::Min($maxScroll, $this.ScrollOffset + $lines)
    }
    
    [string] Render() {
        return Invoke-WithErrorHandling -Component "ContentPanel" -Context "Render.$($this.Name)" -ScriptBlock {
            $output = [StringBuilder]::new()
            
            # Get visible lines
            $visibleLines = $this.Height
            $endLine = [Math]::Min($this.Content.Count, $this.ScrollOffset + $visibleLines)
            
            for ($i = $this.ScrollOffset; $i -lt $endLine; $i++) {
                $line = $this.Content[$i]
                $y = $this.Y + ($i - $this.ScrollOffset)
                
                [void]$output.Append("`e[$y;$($this.X)H")
                
                # Truncate or wrap line based on WordWrap setting
                if ($this.WordWrap -and $line.Length -gt $this.Width) {
                    $wrappedLine = $line.Substring(0, $this.Width)
                    [void]$output.Append($wrappedLine)
                } else {
                    $displayLine = if ($line.Length -gt $this.Width) {
                        $line.Substring(0, $this.Width - 3) + "..."
                    } else {
                        $line.PadRight($this.Width)
                    }
                    [void]$output.Append($displayLine)
                }
            }
            
            # Clear remaining lines
            for ($i = $endLine - $this.ScrollOffset; $i -lt $visibleLines; $i++) {
                $y = $this.Y + $i
                [void]$output.Append("`e[$y;$($this.X)H")
                [void]$output.Append(" " * $this.Width)
            }
            
            return $output.ToString()
        }
    }
}

# Export classes
Export-ModuleMember -Function * -Cmdlet * -Variable * -Alias *