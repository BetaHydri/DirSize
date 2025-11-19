# DirectorySize PowerShell Tool

A powerful PowerShell script for analyzing directory sizes with administrator privilege handling and comprehensive error management.

## 🌟 Features

- **Directory-Only Analysis** - Shows folder sizes without individual file listings
- **File Explorer-Like Hierarchy** - Tree structure display with ├──, └──, │ characters
- **Size-Based Color Coding** - Visual highlighting of large directories (Red >10GB, Magenta >5GB, Yellow >1GB)
- **Performance Optimized** - Fast mode option for improved calculation speed
- **Progress Indicator** - Rotating cursor shows analysis progress for large directory structures
- **Flexible Depth Control** - Specify exact analysis depth from current directory only to unlimited
- **Administrator Privilege Detection** - Automatically detects and validates elevated permissions
- **Clean Output** - Quiet operation by default with visual indicators for access issues
- **Access Control Handling** - Gracefully handles permission-denied scenarios
- **Formatted Output** - Human-readable size formatting (KB, MB, GB, TB)
- **Simple Interface** - Minimal parameter set focused on essential functionality

## 🚀 Quick Start

### Basic Usage

```powershell
# Analyze current directory only (default)
.\DirectorySize.ps1 -Path "C:\Users\YourName\Documents"

# Analyze with subdirectories (2 levels deep)
.\DirectorySize.ps1 -Path "C:\Program Files" -Depth 2

# Unlimited depth analysis
.\DirectorySize.ps1 -Path "D:\Projects" -Depth 0
```

### Advanced Usage

```powershell
# Require administrator privileges (will exit if not admin)
.\DirectorySize.ps1 -Path "C:\Windows" -Depth 0 -RequireAdmin

# Fast analysis with optimized performance
.\DirectorySize.ps1 -Path "C:\Program Files" -Depth 2 -FastMode

# Save output to a text file
.\DirectorySize.ps1 -Path "C:\Program Files" -Depth 2 -SaveToFile "analysis.txt"

# Deep analysis with clean output (default quiet operation)
.\DirectorySize.ps1 -Path "C:\" -Depth 3

# High-performance system analysis with file output
.\DirectorySize.ps1 -Path "C:\Windows\System32" -Depth 0 -RequireAdmin -FastMode -SaveToFile "system_analysis.txt"
```

**Note**: The tool operates quietly by default with clean output. Access restrictions are indicated by `[!]` markers and summarized at the end.

## 📋 Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Path` | String | **Required.** The directory path to analyze |
| `-Depth` | Integer | Analysis depth level (1=current only, 2=one level deep, 0=unlimited). Default: 1 |
| `-RequireAdmin` | Switch | Require administrator privileges (exit with error if not admin) |
| `-FastMode` | Switch | Use optimized enumeration for better performance (may use more memory) |
| `-SaveToFile` | String | Save the complete directory tree output to a UTF-8 text file |

**Note**: The tool operates quietly by default, showing only essential information with visual indicators `[!]` for access restrictions.

```

## ⚡ Performance Optimization

The tool includes several performance enhancements for faster directory analysis:

### FastMode Option

```powershell
# Standard mode (balanced performance and memory usage)
.\DirectorySize.ps1 -Path "C:\Program Files" -Depth 2

# Fast mode (optimized for speed)
.\DirectorySize.ps1 -Path "C:\Program Files" -Depth 2 -FastMode
```

### Performance Features

- **Optimized Enumeration** - Single call to get files and directories when using FastMode
- **Reduced Function Calls** - Minimized overhead in recursive processing
- **Smart Progress Updates** - Less frequent progress indicator updates in FastMode
- **Efficient Memory Usage** - Standard mode balances speed and memory consumption
- **Fast File Counting** - Optimized file size calculations

### When to Use FastMode

- ✅ **Large directories** with many subdirectories
- ✅ **System analysis** where speed is prioritized
- ✅ **Sufficient RAM** available (uses more memory temporarily)
- ❌ **Memory-constrained systems** (stick to standard mode)
- ❌ **Network drives** (may not provide significant benefit)

## 🎯 Depth Control

The `-Depth` parameter controls **display depth** while always calculating complete directory sizes:

- **`-Depth 1`** (Default): Shows only root directory total (calculates all subdirectories for accuracy)
- **`-Depth 2`**: Shows root + one level of subdirectories (with accurate totals including deeper levels)
- **`-Depth 3`**: Shows root + two levels of subdirectories (with complete size calculations)
- **`-Depth 0`**: Shows complete directory tree (unlimited display and calculation)

### Key Feature: Accurate Totals

📊 **The tool always calculates ALL subdirectories** for accurate size totals, regardless of display depth.
This means a folder shown at depth 2 includes the sizes of ALL its subdirectories, even those not displayed.

### Depth Examples

```powershell
# Show only total Program Files size (includes all subdirectories in calculation)
.\DirectorySize.ps1 -Path "C:\Program Files" -Depth 1

# Show Program Files + immediate subdirectories (with accurate totals)
.\DirectorySize.ps1 -Path "C:\Program Files" -Depth 2

# Complete tree display and calculation
.\DirectorySize.ps1 -Path "C:\Program Files" -Depth 0
```

## 🔐 Administrator Privileges

The script includes administrator privilege detection and validation:

- **Detection**: Automatically detects if running with admin privileges
- **Validation**: Can require admin privileges with `-RequireAdmin` parameter
- **Clear Feedback**: Shows admin status and provides helpful error messages
- **Manual Elevation**: Users must manually start PowerShell as Administrator when needed
- **Graceful Fallback**: Continues with limited access when admin not required

### When do you need admin privileges?

- System directories (e.g., `C:\Windows`, `C:\Program Files`)
- User profile directories of other users
- Protected application data folders
- System-level temporary directories

## 📊 Output Format

The script provides color-coded, formatted output with File Explorer-like hierarchy:

```
Directory Size Analysis
======================
Path: C:\Program Files
Analysis Depth: 3 levels
Administrator: True

Analyzing directories Complete!

Program Files - 15.2 GB                    [Red - Very Large]
├── Adobe - 2.34 GB                      [Yellow - Medium]
│   ├── Acrobat DC - 1.8 GB               [Yellow - Medium]
│   └── Creative Cloud - 540 MB           [White - Normal]
├── Microsoft Office - 3.21 GB           [Yellow - Medium]
│   ├── Office16 - 2.1 GB                 [Yellow - Medium]
│   └── Templates - 110 MB                [White - Normal]
├── Windows Defender - 89.45 MB          [White - Normal]
└── Common Files - 156.78 MB             [White - Normal]
    ├── Microsoft Shared - 98.2 MB        [White - Normal]
    └── System - 58.6 MB                  [White - Normal]

Total Size: 15.2 GB                        [Red - Very Large]
Restricted Directories: 1
Note: [!] indicates directories with access restrictions

Size Color Legend:
  Red = Very Large (>10GB)  Magenta = Large (5-10GB)  Yellow = Medium (1-5GB)
```

## 💾 File Output

The `-SaveToFile` parameter allows you to save the complete directory tree analysis to a UTF-8 text file:

### File Output Features

- **UTF-8 Encoding** - Preserves Unicode tree characters (├──, └──, │)
- **Complete Tree Structure** - Exact copy of console output without color formatting
- **Header Information** - Includes analysis path, depth, and admin status
- **Summary Data** - Contains total size, color legend, and restriction notes
- **Automatic Directory Creation** - Creates output directory if it doesn't exist

### File Output Examples

```powershell
# Save to current directory
.\DirectorySize.ps1 -Path "C:\Program Files" -Depth 2 -SaveToFile "programs.txt"

# Save with timestamp
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
.\DirectorySize.ps1 -Path "C:\Windows" -SaveToFile "Windows_Analysis_$timestamp.txt"

# Save to specific location
.\DirectorySize.ps1 -Path "D:\Projects" -Depth 0 -FastMode -SaveToFile "C:\Reports\project_sizes.txt"
```

### Sample File Output

```plaintext
Directory Size Analysis
======================
Path: C:\Program Files
Analysis Depth: 2 levels
Administrator: True

Program Files - 15,2 GB
├── Adobe - 2,34 GB
├── Microsoft Office - 3,21 GB
├── Windows Defender - 89,45 MB
└── Common Files - 156,78 MB

Total Size: 15,2 GB
Size Color Legend:
  Red = Very Large (>10GB)  Magenta = Large (5-10GB)  Yellow = Medium (1-5GB)
```

### Progress Indication

- **Rotating Cursor** - Shows | / - \\ animation during analysis
- **Smart Updates** - Updates every few directories to avoid flickering
- **Completion Message** - Clear "Complete!" when analysis finishes
- **Non-Blocking** - Doesn't slow down the analysis process

### Color Coding System

- 🔴 **Red**: Very large directories (>10GB) - Immediate attention needed
- 🔵 **Magenta**: Large directories (5-10GB) - Consider for cleanup
- 🟡 **Yellow**: Medium directories (1-5GB) - Monitor usage
- ⚪ **White**: Normal directories (<1GB) - Standard size

### Hierarchy Display Features

- **Tree Structure** - Uses ├──, └──, and │ characters like File Explorer
- **Visual Relationships** - Clear parent-child directory relationships
- **Last Item Indicators** - └── shows the last item at each level
- **Continuation Lines** - │ shows ongoing hierarchy levels
- **Clean Alignment** - Proper spacing for easy reading

### Output Features

- **Directory Totals Only** - Shows folder sizes including all files within them
- **Hierarchical Structure** - Indented display shows folder relationships
- **File Inclusion** - All files are counted in their parent directory totals
- **Clean Display** - No individual file listings for easier folder-level analysis

### Output Indicators

- **[!]** - Directory has access restrictions
- **Green Text** - Total size summary
- **Yellow Text** - Warnings and restricted directory counts
- **Red Text** - Error messages
- **Cyan Text** - Headers and tips

## 🛠️ System Requirements

- **Windows** with PowerShell 5.1 or later
- **PowerShell Core** (6.0+) support
- No additional modules required

## 📁 Project Structure

```
DirSize/
├── DirectorySize.ps1    # Main script
├── README.md           # This file
└── LICENSE            # MIT License
```

## 🔧 Functions

### `Test-IsAdministrator`
Checks if the current PowerShell session has administrator privileges.

### `Start-ElevatedScript`
Restarts the script with administrator privileges using UAC prompt.

### `Get-DirectorySize`
Core function that recursively calculates directory sizes with error handling.

### `Format-Size`
Converts byte values to human-readable format (KB, MB, GB, TB).

## 🚨 Error Handling

The script handles various error scenarios:

- **Access Denied**: Gracefully skips restricted directories
- **Path Not Found**: Validates paths before processing
- **Elevation Failures**: Provides fallback options
- **Unexpected Errors**: Captures and reports general exceptions

## 📝 Examples

### Example 1: Basic Directory Analysis
```powershell
.\DirectorySize.ps1 -Path "C:\Users\Documents"
```

### Example 2: System Directory with Auto-Elevation
```powershell
.\DirectorySize.ps1 -Path "C:\Windows\System32" -Recurse -RequireAdmin
```

### Example 3: Large Drive Analysis (Quiet Mode)
```powershell
.\DirectorySize.ps1 -Path "D:\" -Recurse -SkipRestrictedDirs
```

## 🤝 Contributing

Feel free to contribute to this project by:

1. Reporting bugs or issues
2. Suggesting new features
3. Submitting pull requests
4. Improving documentation

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

If you encounter issues:

1. **Check PowerShell Version**: Ensure you're using PowerShell 5.1+
2. **Execution Policy**: You may need to run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
3. **Path Validation**: Verify the target path exists and is accessible
4. **Administrator Mode**: Try running PowerShell as administrator for system directories

## 🔄 Version History

- **v1.0** - Initial release with basic directory size calculation
- **v1.1** - Added administrator privilege handling and auto-elevation
- **v1.2** - Enhanced error handling and visual indicators
- **v1.3** - Directory-only output for cleaner folder-level analysis
- **v1.4** - Added depth control parameter with flexible recursion options
- **v1.5** - Simplified interface by removing -Recurse switch, depth-only control
- **v1.6** - File Explorer-like tree hierarchy display with visual characters
- **v1.7** - Separated display depth from calculation depth for accurate totals
- **v1.8** - Added pause functionality to prevent elevated windows from auto-closing
- **v1.9** - Removed auto-elevation, simplified to manual admin privilege requirement
- **v2.0** - Added size-based color coding for improved large directory visibility
- **v2.1** - Removed -SkipRestrictedDirs parameter, quiet operation by default
- **v2.2** - Added rotating cursor progress indicator for long-running analyses
- **v2.3** - Performance optimizations with FastMode option and improved enumeration

---

**Made with ❤️ by jantiede for the PowerShell community**