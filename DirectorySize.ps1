<#
.SYNOPSIS
    Analyzes directory sizes with administrator privilege handling and folder-only output.

.DESCRIPTION
    A powerful PowerShell script that calculates directory sizes recursively with comprehensive
    error handling, administrator privilege detection, and validation capabilities.
    Always calculates ALL subdirectory sizes for accurate totals, but displays only up to
    the specified depth level. Operates quietly by default with clean output and visual indicators.

.PARAMETER Path
    The directory path to analyze. This parameter is mandatory.

.PARAMETER Depth
    Specify the maximum depth level for DISPLAY (1 = current directory only,
    2 = show one level deep, etc.). Use 0 for unlimited display. Always calculates
    all subdirectories for accurate totals regardless of display depth. Default is 1.

.PARAMETER RequireAdmin
    Require the script to run with administrator privileges. If not running as admin,
    the script will exit with an error message instead of continuing with limited access.

.PARAMETER FastMode
    Use optimized enumeration for better performance. Gets files and directories in
    a single call and reduces progress updates. May use more memory for large directories.

.EXAMPLE
    .\DirectorySize.ps1 -Path "C:\Users\Documents"
    Analyzes the Documents directory (current level only - default behavior).

.EXAMPLE
    .\DirectorySize.ps1 -Path "C:\Program Files" -Depth 2
    Displays Program Files directory and one level of subdirectories, but calculates
    all subdirectories for accurate size totals.

.EXAMPLE
    .\DirectorySize.ps1 -Path "C:\Windows" -Depth 0 -RequireAdmin
    Requires administrator privileges for Windows directory analysis.
    Will exit with error if not running as administrator.

.EXAMPLE
    .\DirectorySize.ps1 -Path "D:\" -Depth 3
    Scans D: drive up to 3 levels deep with clean output (warnings suppressed by default).

.EXAMPLE
    .\DirectorySize.ps1 -Path "C:\Program Files" -Depth 2 -FastMode
    Analyzes Program Files with optimized performance for faster results.

.NOTES
    File Name      : DirectorySize.ps1
    Author         : Jan Tiedemann
    Prerequisite   : PowerShell 5.1 or later
    License        : MIT License

.LINK
    https://github.com/jantiede/DirectorySize
#>
param(
    [Parameter(Mandatory = $true, HelpMessage = "Enter the directory path to analyze")]
    [ValidateScript({
            if (-not (Test-Path $_ -PathType Container)) {
                throw "Path '$_' does not exist or is not a directory."
            }
            return $true
        })]
    [string]$Path,
    
    [Parameter(HelpMessage = "Maximum depth level (1=current only, 2=one level deep, 0=unlimited)")]
    [ValidateRange(0, 100)]
    [int]$Depth = 1,
    
    [Parameter(HelpMessage = "Require administrator privileges (exit with error if not admin)")]
    [switch]$RequireAdmin,
    
    [Parameter(HelpMessage = "Use faster enumeration (may use more memory for large directories)")]
    [switch]$FastMode,

    [Parameter(HelpMessage = "Save output tree to a UTF-8 text file")]
    [string]$SaveToFile
)

function Test-IsAdministrator {
    <#
    .SYNOPSIS
        Checks if the current PowerShell session is running with administrator privileges.
    
    .DESCRIPTION
        This function determines whether the current PowerShell session has administrator
        privileges by checking the Windows Principal and Built-in Administrator role.
        It's essential for operations that require elevated permissions.
    
    .OUTPUTS
        System.Boolean
        Returns $true if the current session has administrator privileges, $false otherwise.
    
    .EXAMPLE
        Test-IsAdministrator
        Returns True if running as administrator, False otherwise.
    
    .EXAMPLE
        if (Test-IsAdministrator) {
            Write-Host "Running with admin privileges"
        } else {
            Write-Host "Standard user privileges"
        }
        
    .NOTES
        This function is Windows-specific and relies on .NET Security Principal classes.
        It gracefully handles any exceptions and defaults to $false on errors.
    #>
    
    try {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Start-ElevatedScript {
    <#
    .SYNOPSIS
        [DEPRECATED] Previously used for automatic elevation - now removed.
    
    .DESCRIPTION
        This function was used for automatic UAC elevation but has been removed
        from the current implementation. The script now requires manual elevation
        when administrator privileges are needed.
    
    .NOTES
        This function is kept for backward compatibility but is no longer called.
        Users must manually run PowerShell as Administrator when needed.
    #>
    param(
        [string]$ScriptPath,
        [string[]]$Arguments
    )
    
    Write-Warning "Automatic elevation has been disabled. Please run PowerShell as Administrator manually."
}

function Get-TreePrefix {
    <#
    .SYNOPSIS
        Generates tree-like prefix characters for hierarchical display.
    
    .DESCRIPTION
        Creates visual tree characters (├──, └──, │) similar to File Explorer
        to show directory hierarchy relationships clearly.
    
    .PARAMETER Level
        The current depth level in the directory tree.
    
    .PARAMETER IsLast
        Whether this is the last item at the current level.
    
    .PARAMETER ParentPrefixes
        Array of prefix characters from parent levels.
    
    .OUTPUTS
        System.String
        Returns formatted tree prefix string for display.
    
    .EXAMPLE
        Get-TreePrefix -Level 1 -IsLast $false -ParentPrefixes @()
        Returns "├── " for a non-last item at level 1.
    #>
    param(
        [int]$Level,
        [bool]$IsLast,
        [string[]]$ParentPrefixes = @()
    )
    
    if ($Level -eq 0) {
        return ""
    }
    
    $prefix = ""
    
    # Add parent prefixes
    for ($i = 0; $i -lt ($Level - 1); $i++) {
        if ($i -lt $ParentPrefixes.Count) {
            $prefix += $ParentPrefixes[$i]
        }
        else {
            $prefix += "    "
        }
    }
    
    # Add current level prefix
    if ($IsLast) {
        $prefix += "└── "
    }
    else {
        $prefix += "├── "
    }
    
    return $prefix
}

function Get-DirectorySize {
    <#
    .SYNOPSIS
        Recursively calculates directory size with comprehensive error handling and depth-controlled display.
    
    .DESCRIPTION
        Core function that traverses ALL directories for accurate size calculation, but only
        displays directories up to the specified depth level. This ensures accurate totals
        while providing clean, controlled output. Supports hierarchical tree view with
        visual indicators for access restrictions.
    
    .PARAMETER DirectoryPath
        The full path to the directory to analyze.
    
    .PARAMETER Level
        Internal parameter for recursion depth tracking (controls indentation).
        Default is 0 for root level.

    .PARAMETER MaxDepth
        Maximum allowed depth for recursion. 0 means unlimited depth.
        Used to control how deep the analysis goes.

    .PARAMETER DisplayDepth
        Maximum depth level for displaying directories. Calculation continues beyond this
        depth for accuracy, but display is limited to this level.

    .PARAMETER RestrictedDirs
        Reference to counter for tracking directories with access restrictions.
        Used to maintain count across recursive calls.
    
    .PARAMETER ParentPrefixes
        Array of prefix strings from parent levels for tree display formatting.
        Used internally for maintaining proper hierarchy visualization.
    
    .PARAMETER IsLast
        Whether this directory is the last item at its level.
        Used for proper tree character selection (├── vs └──).
    
    .OUTPUTS
        System.Int64
        Returns the total size in bytes of the directory and its contents.
    
    .EXAMPLE
        $restrictedCount = 0
        $size = Get-DirectorySize -DirectoryPath "C:\Program Files" -RestrictedDirs ([ref]$restrictedCount)
        
    .EXAMPLE
        Get-DirectorySize -DirectoryPath "C:\Users\Documents" -Level 1 -RestrictedDirs ([ref]$counter)
        Calculates size with level 1 indentation (used in recursive calls).
    
    .NOTES
        - Handles UnauthorizedAccessException gracefully with quiet operation
        - Uses [!] indicator for directories with access issues
        - Operates quietly by default for clean output
        - Automatically formats and displays sizes using Format-Size function
        - Tracks restricted directory count for summary display
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath,
        
        [Parameter()]
        [int]$Level = 0,
        
        [Parameter()]
        [int]$MaxDepth = 0,
        
        [Parameter()]
        [int]$DisplayDepth = 0,
        
        [Parameter(Mandatory = $true)]
        [ref]$RestrictedDirs,
        
        [Parameter()]
        [string[]]$ParentPrefixes = @(),
        
        [Parameter()]
        [bool]$IsLast = $true,
        
        [Parameter()]
        [bool]$FastMode = $false
    )
    
    $totalSize = 0
    $hasAccessIssues = $false
    
    try {
        # Optimized file enumeration - get files and directories in one call when possible
        if ($FastMode) {
            # Fast mode: Get all items at once (uses more memory but faster)
            $allItems = Get-ChildItem -Path $DirectoryPath -ErrorAction SilentlyContinue
            $files = $allItems | Where-Object { -not $_.PSIsContainer }
            $directories = $allItems | Where-Object { $_.PSIsContainer }
        }
        else {
            # Standard mode: Separate calls (uses less memory)
            $files = Get-ChildItem -Path $DirectoryPath -File -ErrorAction SilentlyContinue
            $directories = Get-ChildItem -Path $DirectoryPath -Directory -ErrorAction SilentlyContinue
        }
        
        # Optimized file size calculation
        if ($files.Count -gt 0) {
            $fileSize = ($files | Measure-Object -Property Length -Sum).Sum
            if ($null -eq $fileSize) { $fileSize = 0 }
        }
        else {
            $fileSize = 0
        }
        
        # Start with files in current directory
        $totalSize = $fileSize
        
        # Display directory information only if within display depth (or unlimited display)
        $shouldDisplay = ($DisplayDepth -eq 0) -or ($Level -lt $DisplayDepth) -or ($Level -eq 0)
        
        # Stop progress indicator before any display to prevent interference
        if ($shouldDisplay -and $Global:ProgressActive -eq $true) {
            $Global:ProgressActive = $false
            Write-Host "`b" -NoNewline  # Erase the spinner
            Write-Host "Complete!" -ForegroundColor Green
            Write-Host ""
        }
        
        # Display current directory IMMEDIATELY (before processing subdirectories)
        if ($shouldDisplay) {
            $directoryName = Split-Path $DirectoryPath -Leaf
            $treePrefix = if ($Level -eq 0) { "" } else { Get-TreePrefix -Level $Level -IsLast $IsLast -ParentPrefixes $ParentPrefixes }
            
            # Display directory name immediately - we'll show files+subdirs size for now
            $tempSize = Format-Size $fileSize
            $tempColor = Get-SizeColor $fileSize
            
            # Create display text
            $displayText = "$treePrefix$directoryName - $tempSize"
            if ($hasAccessIssues) { $displayText += " [!]" }
            
            # Display the directory entry
            Write-Host "$treePrefix$directoryName - " -NoNewline
            Write-Host $tempSize -ForegroundColor $tempColor -NoNewline
            if ($hasAccessIssues) { Write-Host " [!]" } else { Write-Host "" }
            
            # Capture output for file saving if requested
            if ($SaveToFile -and $script:outputLines) {
                $script:outputLines += $displayText
            }
        }
        
        # Always process ALL subdirectories for accurate size calculation
        if ($directories -and $directories.Count -gt 0) {
            $dirCount = $directories.Count
            
            # Reduced progress updates for better performance
            $progressUpdateInterval = if ($FastMode) { 10 } else { 5 }
            
            for ($i = 0; $i -lt $dirCount; $i++) {
                $dir = $directories[$i]
                $isLastDir = ($i -eq ($dirCount - 1))
                
                # Update progress less frequently for better performance (only when not displaying tree)
                if ($Level -le 1 -and ($i % $progressUpdateInterval -eq 0) -and ($Level -eq 0)) {
                    Update-ProgressIndicator
                }
                
                try {
                    # Prepare parent prefixes for next level
                    # Use current directory's IsLast status to determine if we add vertical line or spaces
                    $currentPrefix = if ($Level -eq 0) {
                        # At root level, don't add any prefix
                        ""
                    }
                    else {
                        # At non-root levels, use the current directory's IsLast status
                        if ($IsLast) { "    " } else { "│   " }
                    }
                    
                    $newParentPrefixes = if ($Level -eq 0) {
                        @()
                    }
                    else {
                        $ParentPrefixes + @($currentPrefix)
                    }
                    
                    # Always calculate subdirectory size, but control display depth
                    $subDirSize = Get-DirectorySize -DirectoryPath $dir.FullName -Level ($Level + 1) -MaxDepth $MaxDepth -DisplayDepth $DisplayDepth -RestrictedDirs $RestrictedDirs -ParentPrefixes $newParentPrefixes -IsLast $isLastDir -FastMode $FastMode
                    $totalSize += $subDirSize
                }
                catch [System.UnauthorizedAccessException] {
                    $hasAccessIssues = $true
                    $RestrictedDirs.Value++
                    # Quiet operation by default - no warning messages for cleaner output
                }
                catch {
                    # Quiet operation by default - no error messages for cleaner output
                }
            }
        }
        
        return $totalSize
    }
    catch [System.UnauthorizedAccessException] {
        $RestrictedDirs.Value++
        # Quiet operation by default - no warning for cleaner output
        return 0
    }
    catch {
        # Quiet operation by default - no error messages for cleaner output
        return 0
    }
}

function Initialize-ProgressIndicator {
    <#
    .SYNOPSIS
        Initializes the progress indicator for directory analysis.
    
    .DESCRIPTION
        Sets up a rotating cursor progress indicator to show that directory
        analysis is in progress. Uses a global variable to track state.
        Uses a separate line to prevent interference with tree output.
    #>
    
    $Global:ProgressCounter = 0
    $Global:ProgressChars = @('|', '/', '-', '\\')
    $Global:ProgressActive = $true
    Write-Host "Analyzing directories..." -NoNewline
    Write-Host " |" -NoNewline  # Initial character
}

function Update-ProgressIndicator {
    <#
    .SYNOPSIS
        Updates the rotating cursor progress indicator.
    
    .DESCRIPTION
        Shows a rotating cursor to indicate ongoing directory analysis.
        Call this function periodically during long-running operations.
        Only updates if progress is still active.
    #>
    
    if ($Global:ProgressActive -eq $true -and $Global:ProgressCounter -ne $null) {
        # Move cursor back one position, write new character
        Write-Host "`b" -NoNewline  # Backspace
        $Global:ProgressCounter++
        Write-Host "$($Global:ProgressChars[$Global:ProgressCounter % 4])" -NoNewline
    }
}

function Complete-ProgressIndicator {
    <#
    .SYNOPSIS
        Completes the progress indicator and cleans up the display.
    
    .DESCRIPTION
        Removes the rotating cursor and shows completion message.
        Cleans up global progress variables and moves to new line.
    #>
    
    if ($Global:ProgressActive -eq $true) {
        Write-Host "`b" -NoNewline  # Erase the spinner
        Write-Host "Complete!" -ForegroundColor Green
        $Global:ProgressActive = $false
        Remove-Variable -Name ProgressCounter -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable -Name ProgressChars -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable -Name ProgressActive -Scope Global -ErrorAction SilentlyContinue
    }
}

function Get-SizeColor {
    <#
    .SYNOPSIS
        Determines the appropriate color for displaying directory sizes based on size thresholds.
    
    .DESCRIPTION
        Returns PowerShell color names based on directory size to provide visual indicators
        for large directories. Uses a tiered color system to highlight storage usage.
    
    .PARAMETER Size
        The size in bytes to evaluate for color assignment.
    
    .OUTPUTS
        System.String
        Returns PowerShell color name (Red, Magenta, Yellow, or White).
    
    .EXAMPLE
        Get-SizeColor 15000000000
        Returns "Red" for sizes over 10GB.
    
    .EXAMPLE
        Get-SizeColor 2000000000
        Returns "Yellow" for sizes over 1GB but under 5GB.
    
    .NOTES
        Color thresholds:
        - Red: Over 10GB (very large)
        - Magenta: 5GB to 10GB (large)
        - Yellow: 1GB to 5GB (medium-large)
        - White: Under 1GB (normal)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [long]$Size
    )
    
    if ($Size -ge 10GB) {
        return "Red"        # Very large directories (>10GB)
    }
    elseif ($Size -ge 5GB) {
        return "Magenta"    # Large directories (5-10GB)
    }
    elseif ($Size -ge 1GB) {
        return "Yellow"     # Medium-large directories (1-5GB)
    }
    else {
        return "White"      # Normal directories (<1GB)
    }
}

function Format-Size {
    <#
    .SYNOPSIS
        Converts byte values to human-readable size format.
    
    .DESCRIPTION
        Formats file sizes from bytes into appropriate units (Bytes, KB, MB, GB, TB)
        with proper decimal precision. Uses 1024-based calculations for binary prefixes.
    
    .PARAMETER Size
        The size in bytes to format. Must be a valid long integer.
    
    .OUTPUTS
        System.String
        Returns formatted size string with appropriate unit suffix.
    
    .EXAMPLE
        Format-Size 1024
        Returns "1.00 KB"
    
    .EXAMPLE
        Format-Size 1073741824
        Returns "1.00 GB"
    
    .EXAMPLE
        Format-Size 500
        Returns "500 Bytes"
    
    .EXAMPLE
        $files = Get-ChildItem | Measure-Object -Property Length -Sum
        Format-Size $files.Sum
        Formats the total size of files in current directory.
    
    .NOTES
        - Uses binary prefixes (1024-based) rather than decimal (1000-based)
        - Provides 2 decimal places for KB, MB, GB, and TB
        - Shows exact byte count for values under 1KB
        - Supports sizes up to terabytes
    #>
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [long]$Size
    )
    
    if ($Size -ge 1TB) { return "{0:N2} TB" -f ($Size / 1TB) }
    elseif ($Size -ge 1GB) { return "{0:N2} GB" -f ($Size / 1GB) }
    elseif ($Size -ge 1MB) { return "{0:N2} MB" -f ($Size / 1MB) }
    elseif ($Size -ge 1KB) { return "{0:N2} KB" -f ($Size / 1KB) }
    else { return "$Size Bytes" }
}

# Set depth description based on parameter
$DepthDescription = if ($Depth -eq 0) { "Unlimited" } elseif ($Depth -eq 1) { "Current directory only" } else { "$Depth levels" }

# Check administrator privileges
$isAdmin = Test-IsAdministrator

if ($RequireAdmin -and -not $isAdmin) {
    Write-Host "Error: Administrator privileges required but not detected." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Gray
    exit 1
}

# Validate path
if (-not (Test-Path $Path)) {
    Write-Error "Path '$Path' does not exist."
    exit 1
}

# Display header information
Write-Host "Directory Size Analysis" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan
Write-Host "Path: $Path"
Write-Host "Analysis Depth: $DepthDescription"
Write-Host "Administrator: $isAdmin"
if (-not $isAdmin) {
    Write-Host "Note: Some directories may require administrator privileges to access." -ForegroundColor Yellow
}
Write-Host ""

# Initialize output capture if saving to file
$script:outputLines = @()
if ($SaveToFile) {
    $script:outputLines += "Directory Size Analysis"
    $script:outputLines += "======================"
    $script:outputLines += "Path: $Path"
    $script:outputLines += "Analysis Depth: $DepthDescription"
    $script:outputLines += "Administrator: $isAdmin"
    if (-not $isAdmin) {
        $script:outputLines += "Note: Some directories may require administrator privileges to access."
    }
    $script:outputLines += ""
}

# Start progress indicator for calculation phase
Initialize-ProgressIndicator

# Initialize counter for restricted directories
$restrictedDirCount = 0

# Calculate directory size (progress indicator will complete automatically when display starts)
$totalSize = Get-DirectorySize -DirectoryPath $Path -MaxDepth 0 -DisplayDepth $Depth -RestrictedDirs ([ref]$restrictedDirCount) -FastMode $FastMode

# Ensure progress indicator is complete (in case no display occurred)
if ($Global:ProgressActive -eq $true) {
    Complete-ProgressIndicator
    Write-Host ""
}

# Display results with tree hierarchy (no progress interference)

$totalFormatted = Format-Size $totalSize
$totalColor = Get-SizeColor $totalSize

Write-Host ""
Write-Host "Total Size: " -NoNewline
Write-Host $totalFormatted -ForegroundColor $totalColor

if ($restrictedDirCount -gt 0) {
    Write-Host "Restricted Directories: $restrictedDirCount" -ForegroundColor Yellow
    Write-Host "Note: [!] indicates directories with access restrictions" -ForegroundColor Gray
    
    if (-not $isAdmin) {
        Write-Host "Tip: Run with -RequireAdmin to ensure administrator privileges" -ForegroundColor Cyan
    }
}

# Display color legend
Write-Host ""
Write-Host "Size Color Legend:" -ForegroundColor Gray
Write-Host "  " -NoNewline
Write-Host "Red" -ForegroundColor Red -NoNewline
Write-Host " = Very Large (>10GB)  " -NoNewline -ForegroundColor Gray
Write-Host "Magenta" -ForegroundColor Magenta -NoNewline
Write-Host " = Large (5-10GB)  " -NoNewline -ForegroundColor Gray
Write-Host "Yellow" -ForegroundColor Yellow -NoNewline
Write-Host " = Medium (1-5GB)" -ForegroundColor Gray

# Save output to file if requested
if ($SaveToFile) {
    try {
        # Add final sections to output
        $script:outputLines += ""
        $script:outputLines += "Total Size: $(Format-Size $totalSize)"
        
        if ($restrictedDirCount -gt 0) {
            $script:outputLines += "Restricted Directories: $restrictedDirCount"
            $script:outputLines += "Note: [!] indicates directories with access restrictions"
            
            if (-not $isAdmin) {
                $script:outputLines += "Tip: Run with -RequireAdmin to ensure administrator privileges"
            }
        }
        
        $script:outputLines += ""
        $script:outputLines += "Size Color Legend:"
        $script:outputLines += "  Red = Very Large (>10GB)  Magenta = Large (5-10GB)  Yellow = Medium (1-5GB)"
        
        # Ensure the directory exists
        $fileDir = Split-Path $SaveToFile -Parent
        if ($fileDir -and !(Test-Path $fileDir)) {
            New-Item -ItemType Directory -Path $fileDir -Force | Out-Null
        }
        
        # Save with UTF-8 encoding
        $script:outputLines | Out-File -FilePath $SaveToFile -Encoding UTF8 -Force
        Write-Host ""
        Write-Host "Output saved to: $SaveToFile" -ForegroundColor Green
    }
    catch {
        Write-Host ""
        Write-Host "Error saving to file: $($_.Exception.Message)" -ForegroundColor Red
    }
}