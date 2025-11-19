# DirectorySize PowerShell Tool

A powerful PowerShell script for analyzing directory sizes with administrator privilege handling and comprehensive error management.

## 🌟 Features

- **Directory-Only Analysis** - Shows folder sizes without individual file listings
- **File Explorer-Like Hierarchy** - Tree structure display with ├──, └──, │ characters
- **Size-Based Color Coding** - Visual highlighting of large directories (Red >10GB, Magenta >5GB, Yellow >1GB)
- **Flexible Depth Control** - Specify exact analysis depth from current directory only to unlimited
- **Administrator Privilege Detection** - Automatically detects and validates elevated permissions
- **Privilege Validation** - Ensures required permissions are available before analysis
- **Access Control Handling** - Gracefully handles permission-denied scenarios
- **Formatted Output** - Human-readable size formatting (KB, MB, GB, TB)
- **Visual Indicators** - Shows directories with access restrictions
- **Simple Interface** - Clean parameter set focused on depth control

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

# Limit analysis to 2 levels deep
.\DirectorySize.ps1 -Path "C:\Program Files" -Depth 2

# Deep analysis with quiet mode (3 levels)
.\DirectorySize.ps1 -Path "C:\" -Depth 3 -SkipRestrictedDirs

# System analysis with admin validation
.\DirectorySize.ps1 -Path "C:\Windows\System32" -Depth 0 -RequireAdmin -SkipRestrictedDirs
```

**Note**: When using `-RequireAdmin`, you must manually start PowerShell as Administrator first.

## 📋 Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Path` | String | **Required.** The directory path to analyze |
| `-Depth` | Integer | Analysis depth level (1=current only, 2=one level deep, 0=unlimited). Default: 1 |
| `-RequireAdmin` | Switch | Require administrator privileges (exit with error if not admin) |
| `-SkipRestrictedDirs` | Switch | Suppress warning messages for access-denied directories |

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

---

**Made with ❤️ by jantiede for the PowerShell community**