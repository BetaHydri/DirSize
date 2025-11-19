# DirectorySize PowerShell Tool

A powerful PowerShell script for analyzing directory sizes with administrator privilege handling and comprehensive error management.

## 🌟 Features

- **Directory-Only Analysis** - Shows folder sizes without individual file listings
- **Recursive Directory Analysis** - Calculate sizes of directories and their subdirectories
- **Administrator Privilege Detection** - Automatically detects and handles elevated permissions
- **Auto-Elevation** - Can restart itself with administrator privileges when needed
- **Access Control Handling** - Gracefully handles permission-denied scenarios
- **Formatted Output** - Human-readable size formatting (KB, MB, GB, TB)
- **Visual Indicators** - Shows directories with access restrictions
- **Flexible Options** - Multiple parameters for different use cases

## 🚀 Quick Start

### Basic Usage

```powershell
# Analyze a single directory
.\DirectorySize.ps1 -Path "C:\Users\YourName\Documents"

# Recursive analysis
.\DirectorySize.ps1 -Path "C:\Program Files" -Recurse
```

### Advanced Usage

```powershell
# Force administrator mode (auto-elevate if possible)
.\DirectorySize.ps1 -Path "C:\Windows" -Recurse -RequireAdmin

# Suppress warnings for restricted directories
.\DirectorySize.ps1 -Path "C:\" -Recurse -SkipRestrictedDirs

# Combined options
.\DirectorySize.ps1 -Path "C:\Program Files" -Recurse -RequireAdmin -SkipRestrictedDirs
```

## 📋 Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Path` | String | **Required.** The directory path to analyze |
| `-Recurse` | Switch | Include subdirectories in the analysis |
| `-RequireAdmin` | Switch | Force administrator privileges (auto-elevate if needed) |
| `-SkipRestrictedDirs` | Switch | Suppress warning messages for access-denied directories |

## 🔐 Administrator Privileges

The script includes sophisticated administrator privilege handling:

- **Detection**: Automatically detects if running with admin privileges
- **Auto-Elevation**: Can restart itself with elevated permissions
- **Graceful Fallback**: Continues operation with limited access when elevation isn't possible
- **Clear Feedback**: Shows admin status and restricted directory counts

### When do you need admin privileges?

- System directories (e.g., `C:\Windows`, `C:\Program Files`)
- User profile directories of other users
- Protected application data folders
- System-level temporary directories

## 📊 Output Format

The script provides color-coded, formatted output focused on directories only:

```
Directory Size Analysis
======================
Path: C:\Program Files
Recursive: True
Administrator: True

Program Files - 15.2 GB
  Adobe - 2.34 GB
  Microsoft Office - 3.21 GB [!]
  Windows Defender - 89.45 MB
  Common Files - 156.78 MB

Total Size: 15.2 GB
Restricted Directories: 1
Note: [!] indicates directories with access restrictions
```

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

---

**Made with ❤️ by jantiede for the PowerShell community**