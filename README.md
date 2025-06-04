# Fast WordPress Plugin Deployment Script

A time-saving one-click deployment script for local WordPress plugin development, eliminates manual file copying and plugin reactivation; uses wp-cli for automatic plugin deactivation and reactivation (for initilization) with automatic local and remote backups, fallbacks, and easy setup using a config file.

![Windows](https://img.shields.io/badge/Windows-10%2B-blue.svg)
![WordPress](https://img.shields.io/badge/WordPress-5.0%2B-21759B.svg)
![Version](https://img.shields.io/badge/Version-1.5.4-green.svg)
![License](https://img.shields.io/badge/License-GPLv3-orange.svg)

> **Created by:** [lso2](https://github.com/lso2)  
> **Repository:** [wp-fast-remote-deploy](https://github.com/lso2/wp-fast-remote-deploy


## Summary

This automates several things to save time:
- Backs up the local folder to a .tar.gz
- Backs up the remote folder to a .tar.gz
- Renames remote folder by appending the version number for quick reverting during testing
- Copies the folder quickly from local to remote to the WP plugin directory using a temporary .tar.gz and unpacking remotely
- Deactivates and reactivates the plugin using WP-CLI, to help re-initialize it
- Gives a summary of what was done

## Quick Usage Summary

- Two files are used: a .bat in the root, and a .sh file in the .run folder.
- Download the repo and drop it directly into your root, so that the .bat file and config file are in the same folder as your plugin folder.
- Configure the config.sh file by adding your real paths and server details.
- In the config file:
	- Include the folder name of your plugin like your-plugin-folder-name
	- Update the local and remote backup paths
	- Set up your ssh connection
	- Optionally, you can also customize many things, or leave it as is. Remote tar.gz is disabled by default for speed.
- Run the script by double-clicking the .bat file. It will open a CMD window which will show you the progress and details.

## 📸 Screenshot

![Screenshot of CMD window on completion](images/screenshot.jpg)

## 🚀 Features

- ⚡ **Fast Deployment** - SSH multiplexing and parallel operations
- 🔄 **Automatic Plugin Management** - Deactivates/reactivates plugins via WP-CLI
- 💾 **Dual Backup System** - Creates both folder and tar.gz backups locally
- 🗂️ **Version-based Organization** - Automatically extracts version numbers and organizes backups
- 🌐 **Remote Backup Management** - Renames existing remote plugins with version timestamps
- 🎨 **Beautiful Console Output** - Color-coded progress with clean formatting
- 🔧 **WSL Integration** - Windows batch script that calls WSL bash script

## Speed Optimizations

- **SSH Connection Multiplexing** - Reuses connections instead of opening new ones
- **Parallel Local Operations** - Folder backup, tar.gz creation, and upload preparation run simultaneously
- **Combined Remote Operations** - Multiple server commands executed in single SSH sessions
- **Reduced Timeouts** - Optimized connection timeouts for faster failures

## Requirements

- Windows with WSL (Windows Subsystem for Linux)
- SSH access to your WordPress server
- WP-CLI installed on the server (optional but recommended)
- WordPress plugin with version number in main PHP file
- SSH key authentication configured (see setup guide below)
- **pigz** for faster compression (optional, auto-falls back to gzip)

## SSH Key Setup Guide

### Step 1: Generate SSH Key with PuTTYgen

1. **Download and open PuTTYgen** (comes with PuTTY or download separately)
2. **Generate key pair**:
   - Select "RSA" key type
   - Set key size to 2048 or 4096 bits
   - Click "Generate"
   - Move mouse randomly in the blank area to generate randomness
3. **Set key passphrase** (optional but recommended):
   - Enter passphrase in "Key passphrase" field
   - Confirm passphrase
4. **Save the private key**:
   - Click "Save private key"
   - Save as `your-key-name.ppk` (PuTTY format)
5. **Copy the public key**:
   - Select all text in the "Public key for pasting into OpenSSH authorized_keys file" box
   - Copy to clipboard (Ctrl+C)

### Step 2: Convert PuTTY Key to OpenSSH Format

**Option A: Using PuTTYgen**
1. In PuTTYgen, go to **Conversions** → **Export OpenSSH key**
2. Save as `id_rsa` (no extension) in your WSL home directory:
   ```bash
   # From Windows, save to:
   \\wsl$\Ubuntu\home\yourusername\.ssh\id_rsa
   ```

**Option B: Using WSL command line**
```bash
# Install putty-tools in WSL
sudo apt update
sudo apt install putty-tools

# Convert the .ppk file to OpenSSH format
puttygen /mnt/c/path/to/your-key.ppk -O private-openssh -o ~/.ssh/id_rsa

# Set proper permissions
chmod 600 ~/.ssh/id_rsa
```

### Step 3: Add Public Key to Server

**Method 1: Using ssh-copy-id (recommended)**
```bash
# Copy public key to server
ssh-copy-id -i ~/.ssh/id_rsa.pub username@your-server-ip -p 22
```

**Method 2: Manual setup**
1. **Create the public key file locally**:
   ```bash
   # Extract public key from private key
   ssh-keygen -y -f ~/.ssh/id_rsa > ~/.ssh/id_rsa.pub
   ```

2. **Add to server manually**:
   ```bash
   # Connect to server with password
   ssh username@your-server-ip -p 22
   
   # Create .ssh directory if it doesn't exist
   mkdir -p ~/.ssh
   chmod 700 ~/.ssh
   
   # Create/edit authorized_keys file
   nano ~/.ssh/authorized_keys
   
   # Paste your public key (from PuTTYgen clipboard) into this file
   # Save and exit (Ctrl+X, Y, Enter in nano)
   
   # Set proper permissions
   chmod 600 ~/.ssh/authorized_keys
   ```

### Step 4: Test SSH Connection

```bash
# Test connection from WSL
ssh -i ~/.ssh/id_rsa username@your-server-ip -p 22

# If successful, you should connect without password prompt
# (unless you set a passphrase on your key)
```

### Step 5: Configure SSH for Convenience (Optional)

Create SSH config file for easier connections:
```bash
# Edit SSH config
nano ~/.ssh/config

# Add your server configuration:
Host myserver
    HostName your-server-ip
    Port 22
    User username
    IdentityFile ~/.ssh/id_rsa
    IdentitiesOnly yes

# Set permissions
chmod 600 ~/.ssh/config
```

Now you can connect with just:
```bash
ssh myserver
```

### Installing pigz (Optional - Recommended for Speed)

pigz is a parallel implementation of gzip that provides **2-4x faster compression** on multi-core systems. The script automatically detects and uses pigz if available, otherwise falls back to standard gzip.

**Ubuntu/Debian (WSL):**
```bash
sudo apt update && sudo apt install pigz
```

**CentOS/RHEL/Amazon Linux (WSL):**
```bash
sudo yum install pigz
# or on newer versions:
sudo dnf install pigz
```

**Arch Linux (WSL):**
```bash
sudo pacman -S pigz
```

**openSUSE (WSL):**
```bash
sudo zypper install pigz
```

**Remote Server Installation:**
Install pigz on your remote server using the same commands for your server's Linux distribution.

**Configuration:**
```bash
# In config.sh - for pigz (default, faster)
COMPRESSION_TOOL="pigz"

# In config.sh - for standard gzip
COMPRESSION_TOOL="gzip"
```

**Performance Comparison:**
- **gzip**: Single-threaded, slower but universally available
- **pigz**: Multi-threaded, 2-4x faster on multi-core systems
- **Auto-fallback**: Script uses pigz if available, gzip otherwise (no user intervention needed)

### Troubleshooting SSH Issues

**Permission denied (publickey)**
```bash
# Check key permissions
ls -la ~/.ssh/
# id_rsa should be 600, id_rsa.pub should be 644

# Fix permissions if needed
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
chmod 700 ~/.ssh
```

**Connection refused**
- Verify server IP and port
- Check if SSH service is running on server
- Ensure firewall allows SSH connections

**Key not being used**
```bash
# Test with verbose output
ssh -v -i ~/.ssh/id_rsa username@your-server-ip -p 22

# Check if key is loaded
ssh-add -l

# Add key to agent if needed
ssh-add ~/.ssh/id_rsa
```

## Installation

1. Clone this repository to your plugin development directory
2. Edit the configuration variables in `deploy-wsl.sh`
3. Set up SSH key authentication to your server
4. Make the script executable: `chmod +x deploy-wsl.sh`

## Configuration

Edit the `config.sh` file in the root directory with your settings:

```bash
# Plugin Configuration
PLUGIN_NAME="your-plugin-name"
LOCAL_PLUGIN_DIR="/mnt/c/path/to/your/plugin/$PLUGIN_NAME"
BACKUP_DIR="/mnt/c/path/to/your/plugin/_plugin_backups"
AUTO_CLOSE=false

# SSH Configuration  
SSH_HOST="your-server-ip"
SSH_PORT="22"
SSH_USER="username"
SSH_KEY="~/.ssh/id_rsa"
REMOTE_PLUGINS_DIR="/path/to/wp-content/plugins"
REMOTE_BACKUP_DIR="/path/to/wp-content/plugin-backups"
WP_PATH="/path/to/wordpress/root"

# Performance Options (all default to false = enabled)
SKIP_WP_CLI=false                    # Skip WP-CLI plugin deactivation/reactivation
SKIP_REMOTE_TAR_BACKUP=false         # Skip creating remote tar.gz backup
SKIP_REMOTE_FOLDER_RENAME=false      # Skip renaming remote folder backup
SKIP_FILE_COUNT_VERIFICATION=true    # Skip slow file count comparison

# Compression Settings
COMPRESSION_TOOL="pigz"              # pigz (parallel/faster) or gzip (standard)
COMPRESSION_LEVEL=1                  # 1=fastest, 9=best compression
```

## Performance Optimization

### Speed vs Safety Modes

**Default Mode (Balanced)**
- All backups enabled
- Fast compression (level 1)
- File count verification skipped
- Typical time: 8-12 seconds

**Ultra-Fast Mode (Maximum Speed)**
```bash
SKIP_WP_CLI=true
SKIP_REMOTE_TAR_BACKUP=true
SKIP_REMOTE_FOLDER_RENAME=true
COMPRESSION_LEVEL=1
```
- Only essential operations
- Typical time: 3-5 seconds
- Use for rapid development iterations

**Safe Mode (Maximum Backups)**
```bash
SKIP_WP_CLI=false
SKIP_REMOTE_TAR_BACKUP=false
SKIP_REMOTE_FOLDER_RENAME=false
SKIP_FILE_COUNT_VERIFICATION=false
COMPRESSION_LEVEL=6
```
- All backups and verification enabled
- Better compression
- Typical time: 15-20 seconds
- Use for production deployments

## Usage

### Windows (Recommended)
Double-click `deploy.bat` or run from command line:
```cmd
deploy.bat
```

### WSL/Linux Direct
```bash
./deploy-wsl.sh
```

## How It Works

1. **Version Detection** - Automatically extracts version from plugin's main PHP file
2. **Local Backups** - Creates timestamped folder and tar.gz backups
3. **Remote Preparation** - Connects via SSH, deactivates plugin, renames existing installation
4. **Fast Upload** - Uses tar.gz compression for quick file transfer
5. **Extraction** - Extracts files directly on server
6. **Reactivation** - Automatically reactivates the plugin via WP-CLI
7. **Verification** - Confirms deployment success with file count comparison

## Version Number Detection

The script automatically detects version numbers from these formats in your main plugin file:

```php
// WordPress standard
Version: 1.2.3

// PHPDoc format
@version 1.2.3

// PHP constant
define('PLUGIN_VERSION', '1.2.3');
```

## Backup Organization

### Local Backups
```
_plugin_backups/
└── backups_plugin-name/
    ├── plugin-name.1.0.0-143022.tar.gz
    ├── plugin-name.1.0.1-151205.tar.gz
    └── plugin-name.1.0.2-162845.tar.gz
```

### Remote Backups
```
wp-content/
├── plugins/
│   ├── plugin-name/           # Current version
│   ├── plugin-name.1.0.0/     # Previous version backup
│   └── plugin-name.1.0.1-143022/  # Duplicate version with timestamp
└── .backups/
    └── backups_plugin-name/
        ├── plugin-name.1.0.0-143022.tar.gz
        └── plugin-name.1.0.1-151205.tar.gz
```

## Performance

Typical deployment times:
- **Original manual process**: ~2-3 minutes
- **Fast deployment script**: ~15-20 seconds  

Speed improvements come from:
- Script automates manual repetitive operations 
- SSH connection reuse (saves ~5 seconds)
- Parallel local operations (saves ~3 seconds)
- Combined remote commands (saves ~4 seconds)
- Optimized timeouts (saves ~2 seconds)

## Troubleshooting

### SSH Connection Issues
- Verify SSH key authentication works: `ssh -i ~/.ssh/id_rsa user@host`
- Check SSH port and host configuration
- Ensure SSH key has proper permissions: `chmod 600 ~/.ssh/id_rsa`

### WP-CLI Issues
- Script works without WP-CLI but won't auto-activate plugins
- Install WP-CLI on server for full functionality
- Verify WP-CLI works: `wp --version`

### Permission Issues
- Ensure web server user can write to plugins directory
- Check file ownership after deployment
- Verify SSH user has proper permissions

### Version Detection Fails
- Ensure your main plugin file has a version number in supported format
- Check file is named correctly (matches PLUGIN_NAME variable)
- Verify file is readable and properly formatted

## File Structure

```
project/
├── deploy.bat              # Windows batch script
├── config.sh               # Configuration file
├── .run/
│   └── deploy-wsl.sh      # Main deployment script
└── README.md              # This file
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly with your own plugin
5. Submit a pull request

## Author

**lso2**
- GitHub: [@lso2](https://github.com/lso2)
- Repository: [wp-fast-remote-deploy](https://github.com/lso2/wp-fast-remote-deploy)

## License

MIT License - feel free to use and modify for your projects.

---

**⭐ If this script saved you time, please star the repository!**

## Changelog

### v1.3.0
- **Added pigz support** - Much faster parallel compression (default) with automatic fallback to gzip
- **Configurable compression tool** - Choose between pigz (multi-threaded) or gzip (standard)
- **Significant speed improvement** - pigz can be 2-4x faster than gzip on multi-core systems
- **Automatic detection** - Falls back to gzip gracefully if pigz is not installed
- **Both local and remote** - Uses selected compression tool for all tar operations

### v1.2.1
- **Fixed compression level syntax** - Corrected tar compression level implementation using GZIP environment variable
- **Resolved tar options error** - Fixed "Options not supported" error when using custom compression levels

### v1.2.0
- **Added comprehensive performance options** - New config flags for skipping WP-CLI, remote backups, and folder renaming
- **Configurable compression levels** - Set compression from 1 (fastest) to 9 (best compression)
- **Better temp file naming** - Upload files now use plugin name (e.g., `tr-donate-upload-123456.tar.gz`)
- **Smarter output messages** - Shows appropriate messages when operations are skipped
- **Faster verification** - Optimized file existence check
- **Ultra-fast mode support** - Can skip all backups for maximum deployment speed

### v1.1.0
- **Added optional file count verification** - New `SKIP_FILE_COUNT_VERIFICATION` config option (default: true)
- **Significantly faster deployments** - Skips slow recursive file counting by default
- **Smart verification** - Still verifies main plugin file exists for deployment confirmation
- **Configurable verification** - Set to false if you want detailed file count comparison
- **Performance improvement** - Reduces verification time from 10-15 seconds to <1 second

### v1.0.8
- **Fixed remote version detection** - Now properly extracts version from remote plugin files
- **Enhanced backup naming** - Remote backups use actual remote version instead of new local version
- **Added fallback handling** - Uses "old" as fallback when version detection fails
- **Improved regex pattern** - Better version number detection with case-insensitive matching
- **Fixed quote escaping** - Resolved bash syntax errors in SSH commands

### v1.0.1
- **Fixed backup logic bug** - only creates tar.gz locally, proper folder+tar.gz remotely
- **Added config.sh file** - centralized configuration, no need to edit script files
- **Fixed timestamp bug** - no longer adds timestamp when folder doesn't exist remotely
- **Dynamic script naming** - batch file reads script name from config
- **Enhanced remote backups** - creates both tar.gz and folder backups on server
- **Improved documentation** - added usage summary and configuration guide

### v1.0.0
- Initial release with basic deployment functionality
- SSH multiplexing for speed optimization
- Dual backup system (folder + tar.gz)
- WP-CLI integration for plugin management
- Color-coded console output
- Windows WSL integration