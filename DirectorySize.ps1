<#
.SYNOPSIS
    Analyzes directory sizes with administrator privilege handling and folder-only output.

.DESCRIPTION
    A powerful PowerShell script that calculates directory sizes recursively with comprehensive
    error handling, administrator privilege detection, and auto-elevation capabilities.
    Provides formatted output focused on directories only, with visual indicators for access restrictions.
    Files are included in calculations but only folder totals are displayed.

.PARAMETER Path
    The directory path to analyze. This parameter is mandatory.

.PARAMETER Recurse
    Include subdirectories in the size calculation. When enabled, the script will
    traverse all subdirectories and provide a hierarchical view of folder-level disk usage.

.PARAMETER RequireAdmin
    Force the script to run with administrator privileges. If not running as admin,
    the script will attempt to auto-elevate using UAC prompt.

.PARAMETER SkipRestrictedDirs
    Suppress warning messages for directories that cannot be accessed due to
    permission restrictions. Useful for cleaner output when scanning large drives.

.EXAMPLE
    .\DirectorySize.ps1 -Path "C:\Users\Documents"
    Analyzes the Documents directory showing only folder sizes (no individual files).

.EXAMPLE
    .\DirectorySize.ps1 -Path "C:\Program Files" -Recurse
    Recursively analyzes the Program Files directory showing hierarchical folder structure.

.EXAMPLE
    .\DirectorySize.ps1 -Path "C:\Windows" -Recurse -RequireAdmin
    Analyzes Windows directory with forced administrator privileges, displaying folder totals only.

.EXAMPLE
    .\DirectorySize.ps1 -Path "D:\" -Recurse -SkipRestrictedDirs
    Scans entire D: drive recursively with suppressed access warnings.

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
    
    [Parameter(HelpMessage = "Include subdirectories in the analysis")]
    [switch]$Recurse,
    
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
    
    .LINK
        https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process
    #>
    
    param(
        [string]$ScriptPath,
        [string[]]$Arguments
    )
    
    try {
        $argumentString = $Arguments -join ' '
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" $argumentString" -Verb RunAs
        exit
    }
    catch {
        Write-Error "Failed to restart script with administrator privileges: $($_.Exception.Message)"
        exit 1
    }
}

function Get-DirectorySize {
    <#
    .SYNOPSIS
        Recursively calculates directory size with comprehensive error handling and folder-only display.
    
    .DESCRIPTION
        Core function that traverses directories, calculates file sizes, handles
        permission errors, and provides visual feedback. Displays only directories
        with their total sizes (including files), supporting hierarchical view
        with indentation and access restriction indicators.
    
    .PARAMETER DirectoryPath
        The full path to the directory to analyze.
    
    .PARAMETER Level
        Internal parameter for recursion depth tracking (controls indentation).
        Default is 0 for root level.
    
    .PARAMETER RestrictedDirs
        Reference to counter for tracking directories with access restrictions.
        Used to maintain count across recursive calls.
    
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
        
        [Parameter(Mandatory = $true)]
        [ref]$RestrictedDirs
    )
    
    $indent = "  " * $Level
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
        
        # Process subdirectories if recursion is enabled
        if ($Recurse -and $directories) {
            foreach ($dir in $directories) {
                try {
                    $subDirSize = Get-DirectorySize -DirectoryPath $dir.FullName -Level ($Level + 1) -RestrictedDirs $RestrictedDirs
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
        
        # Display directory information (always show when recursing, or if root level)
        if ($Recurse -or $Level -eq 0) {
            # Format size for display
            $sizeFormatted = Format-Size $totalSize
            
            # Display current directory info with access status
            $accessIndicator = if ($hasAccessIssues) { " [!]" } else { "" }
            Write-Host "$indent$(Split-Path $DirectoryPath -Leaf) - $sizeFormatted$accessIndicator"
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

# Check administrator privileges
$isAdmin = Test-IsAdministrator

if ($RequireAdmin -and -not $isAdmin) {
    Write-Host "Administrator privileges required but not detected." -ForegroundColor Red
    
    # Try to restart with elevated privileges if this is a saved script file
    if ($MyInvocation.MyCommand.Path) {
        Write-Host "Attempting to restart with administrator privileges..." -ForegroundColor Yellow
        $scriptArgs = @()
        $scriptArgs += "-Path `"$Path`""
        if ($Recurse) { $scriptArgs += "-Recurse" }
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
Write-Host "Recursive: $Recurse"
Write-Host "Administrator: $isAdmin"
if (-not $isAdmin) {
    Write-Host "Note: Some directories may require administrator privileges to access." -ForegroundColor Yellow
}
Write-Host ""

# Initialize counter for restricted directories
$restrictedDirCount = 0

$totalSize = Get-DirectorySize -DirectoryPath $Path -RestrictedDirs ([ref]$restrictedDirCount)
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