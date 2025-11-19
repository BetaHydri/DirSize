<#
.SYNOPSIS
    Analyzes directory sizes with administrator privilege handling and folder-only output.

.DESCRIPTION
    A powerful PowerShell script that calculates directory sizes recursively with comprehensive
    error handling, administrator privilege detection, and auto-elevation capabilities.
    Always calculates ALL subdirectory sizes for accurate totals, but displays only up to
    the specified depth level. Files are included in calculations but only folder totals are displayed.

.PARAMETER Path
    The directory path to analyze. This parameter is mandatory.

.PARAMETER Depth
    Specify the maximum depth level for DISPLAY (1 = current directory only,
    2 = show one level deep, etc.). Use 0 for unlimited display. Always calculates
    all subdirectories for accurate totals regardless of display depth. Default is 1.

.PARAMETER RequireAdmin
    Force the script to run with administrator privileges. If not running as admin,
    the script will attempt to auto-elevate using UAC prompt.

.PARAMETER SkipRestrictedDirs
    Suppress warning messages for directories that cannot be accessed due to
    permission restrictions. Useful for cleaner output when scanning large drives.

.EXAMPLE
    .\DirectorySize.ps1 -Path "C:\Users\Documents"
    Analyzes the Documents directory (current level only - default behavior).

.EXAMPLE
    .\DirectorySize.ps1 -Path "C:\Program Files" -Depth 2
    Displays Program Files directory and one level of subdirectories, but calculates
    all subdirectories for accurate size totals.

.EXAMPLE
    .\DirectorySize.ps1 -Path "C:\Windows" -Depth 0 -RequireAdmin
    Displays unlimited directory depth with forced administrator privileges.
    Calculates and shows complete directory tree.

.EXAMPLE
    .\DirectorySize.ps1 -Path "D:\" -Depth 3 -SkipRestrictedDirs
    Scans D: drive up to 3 levels deep with suppressed access warnings.

.NOTES
    File Name      : DirectorySize.ps1
    Author         : jantiede
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
    
    [Parameter(HelpMessage = "Force administrator privileges (auto-elevate if needed)")]
    [switch]$RequireAdmin,
    
    [Parameter(HelpMessage = "Suppress warnings for access-denied directories")]
    [switch]$SkipRestrictedDirs
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
        Restarts the current script with administrator privileges using UAC elevation.
    
    .DESCRIPTION
        This function uses Start-Process with the -Verb RunAs parameter to launch
        a new PowerShell session with elevated privileges. It preserves the original
        script arguments and triggers the Windows User Account Control (UAC) prompt.
        The elevated session will pause at the end to prevent automatic window closure.
    
    .PARAMETER ScriptPath
        The full path to the PowerShell script file that should be elevated.
        Must be a valid .ps1 file path.
    
    .PARAMETER Arguments
        Array of arguments to pass to the elevated script instance.
        Arguments are joined with spaces and passed to the new process.
    
    .EXAMPLE
        Start-ElevatedScript -ScriptPath "C:\Scripts\MyScript.ps1" -Arguments @("-Path", "C:\Windows")
        Restarts MyScript.ps1 with admin privileges and the specified arguments.
    
    .EXAMPLE
        Start-ElevatedScript -ScriptPath $MyInvocation.MyCommand.Path -Arguments $args
        Restarts the current script with elevation, preserving original arguments.
    
    .NOTES
        - Requires the script to be saved as a .ps1 file (doesn't work with unsaved scripts)
        - Triggers UAC prompt - user must approve elevation
        - Original script process exits after starting elevated instance
        - Uses -NoProfile for faster startup and -ExecutionPolicy Bypass for reliability
        - Elevated window will pause at the end to allow user to review results
    
    .LINK
        https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process
    #>
    
    param(
        [string]$ScriptPath,
        [string[]]$Arguments
    )
    
    try {
        $argumentString = $Arguments -join ' '
        # Add pause command to prevent window from closing in elevated mode
        $pauseCommand = "; Write-Host ''; Write-Host 'Press any key to close this window...' -ForegroundColor Yellow; Read-Host"
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command \"& '$ScriptPath' $argumentString$pauseCommand\"" -Verb RunAs
        exit
    }
    catch {
        Write-Error "Failed to restart script with administrator privileges: $($_.Exception.Message)"
        exit 1
    }
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
        - Handles UnauthorizedAccessException gracefully
        - Uses [!] indicator for directories with access issues
        - Supports the global -SkipRestrictedDirs parameter
        - Automatically formats and displays sizes using Format-Size function
        - Recursion controlled by global -Recurse parameter
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
        [bool]$IsLast = $true
    )
    
    $totalSize = 0
    $hasAccessIssues = $false
    
    try {
        # Get files in current directory (for size calculation only)
        $files = Get-ChildItem -Path $DirectoryPath -File -ErrorAction SilentlyContinue
        $fileSize = ($files | Measure-Object -Property Length -Sum).Sum
        if ($null -eq $fileSize) { $fileSize = 0 }
        
        # Get subdirectories
        $directories = Get-ChildItem -Path $DirectoryPath -Directory -ErrorAction SilentlyContinue
        
        # Start with files in current directory
        $totalSize = $fileSize
        
        # Always process ALL subdirectories for accurate size calculation
        if ($directories) {
            $dirCount = $directories.Count
            
            for ($i = 0; $i -lt $dirCount; $i++) {
                $dir = $directories[$i]
                $isLastDir = ($i -eq ($dirCount - 1))
                
                try {
                    # Prepare parent prefixes for next level (only if displaying this level)
                    $newParentPrefixes = $ParentPrefixes + @(
                        if ($IsLast) { "    " } else { "│   " }
                    )
                    
                    # Always calculate subdirectory size, but control display depth
                    $subDirSize = Get-DirectorySize -DirectoryPath $dir.FullName -Level ($Level + 1) -MaxDepth $MaxDepth -DisplayDepth $DisplayDepth -RestrictedDirs $RestrictedDirs -ParentPrefixes $newParentPrefixes -IsLast $isLastDir
                    $totalSize += $subDirSize
                }
                catch [System.UnauthorizedAccessException] {
                    $hasAccessIssues = $true
                    $RestrictedDirs.Value++
                    
                    if (-not $SkipRestrictedDirs) {
                        Write-Warning "Access denied: $($dir.FullName) - Administrator privileges may be required"
                    }
                }
                catch {
                    if (-not $SkipRestrictedDirs) {
                        Write-Warning "Error accessing: $($dir.FullName) - $($_.Exception.Message)"
                    }
                }
            }
        }
        
        # Display directory information only if within display depth (or unlimited display)
        $shouldDisplay = ($DisplayDepth -eq 0) -or ($Level -lt $DisplayDepth) -or ($Level -eq 0)
        if ($shouldDisplay -and ($DisplayDepth -ne 1 -or $Level -eq 0)) {
            # Format size for display
            $sizeFormatted = Format-Size $totalSize
            
            # Generate tree prefix
            $treePrefix = Get-TreePrefix -Level $Level -IsLast $IsLast -ParentPrefixes $ParentPrefixes
            
            # Display current directory info with access status
            $accessIndicator = if ($hasAccessIssues) { " [!]" } else { "" }
            Write-Host "$treePrefix$(Split-Path $DirectoryPath -Leaf) - $sizeFormatted$accessIndicator"
        }
        
        return $totalSize
    }
    catch [System.UnauthorizedAccessException] {
        $RestrictedDirs.Value++
        if (-not $SkipRestrictedDirs) {
            Write-Warning "Access denied: $DirectoryPath - Administrator privileges required"
        }
        return 0
    }
    catch {
        if (-not $SkipRestrictedDirs) {
            Write-Warning "Error accessing: $DirectoryPath - $($_.Exception.Message)"
        }
        return 0
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
    Write-Host "Administrator privileges required but not detected." -ForegroundColor Red
    
    # Try to restart with elevated privileges if this is a saved script file
    if ($MyInvocation.MyCommand.Path) {
        Write-Host "Attempting to restart with administrator privileges..." -ForegroundColor Yellow
        $scriptArgs = @()
        $scriptArgs += "-Path `"$Path`""
        if ($Depth -ne 1) { $scriptArgs += "-Depth $Depth" }
        if ($SkipRestrictedDirs) { $scriptArgs += "-SkipRestrictedDirs" }
        $scriptArgs += "-RequireAdmin"
        
        Start-ElevatedScript -ScriptPath $MyInvocation.MyCommand.Path -Arguments $scriptArgs
    }
    else {
        Write-Host "Please run this script as administrator or save it as a .ps1 file for automatic elevation." -ForegroundColor Yellow
        exit 1
    }
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

# Initialize counter for restricted directories
$restrictedDirCount = 0

$totalSize = Get-DirectorySize -DirectoryPath $Path -MaxDepth 0 -DisplayDepth $Depth -RestrictedDirs ([ref]$restrictedDirCount)
$totalFormatted = Format-Size $totalSize

Write-Host ""
Write-Host "Total Size: $totalFormatted" -ForegroundColor Green

if ($restrictedDirCount -gt 0) {
    Write-Host "Restricted Directories: $restrictedDirCount" -ForegroundColor Yellow
    Write-Host "Note: [!] indicates directories with access restrictions" -ForegroundColor Gray
    
    if (-not $isAdmin) {
        Write-Host "Tip: Run with -RequireAdmin to automatically request administrator privileges" -ForegroundColor Cyan
    }
}

# Check if this is an elevated session that was auto-started (prevent window from closing)
if ($isAdmin -and $RequireAdmin -and $MyInvocation.MyCommand.Path) {
    Write-Host ""
    Write-Host "Analysis complete. Press any key to close this window..." -ForegroundColor Yellow
    $null = Read-Host
}