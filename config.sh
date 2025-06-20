#!/bin/bash

# WordPress Plugin/Theme Fast Deployment Script - Configuration
# Created by: lso2 (https://github.com/lso2)
# Repository: https://github.com/lso2/wp-fast-remote-deploy
# License: MIT

# Script Configuration
VERSION="2.1.2"  # Script version

# ============================================================================
# REQUIRED: CONFIG - Quickly switch between plugins/themes & Set Type
# ============================================================================

# Folder name of plugin or theme
FOLDER_NAME="your-folder-name"  # Change this to switch plugins/themes instantly

# Deployment Type
TYPE="plugin"  					# Set to "plugin" or "theme" - switches deployment mode


# ============================================================================
# ONE-TIME SETUP - Set once and forget
# ============================================================================

# ----------------------------------------------------------------------------
# SET ONCE: BASE PATHS - Used for all plugins & themes
# ----------------------------------------------------------------------------

# Local Environment
DRIVE_LETTER="C"
LOCAL_PATH="path/to/your/local/root"	# e.g. C:/dev-projects/plugins --> "dev-projects"
										# Don't include drive letter or leading slash							
# Remote Environment  
REMOTE_BASE="/path/to/wordpress/root"

# ----------------------------------------------------------------------------
# SET ONCE: SSH CONFIGURATION - Check readme for setup & key instructions
# ----------------------------------------------------------------------------

# SSH Configuration
SSH_HOST="your-server-ip"
SSH_PORT="22"
SSH_USER="username"
SSH_KEY="~/.ssh/id_rsa"


# ============================================================================
# OPTIONAL SETTINGS
# ============================================================================

# ----------------------------------------------------------------------------
# OPTIONAL: Other Settings
# ----------------------------------------------------------------------------

# Whether to close the cmd window automatically on completion
AUTO_CLOSE=false

# Skip slow file count verification (just checks main plugin file exists)
SKIP_FILE_COUNT_VERIFICATION=true

# Performance optimization options (all default to false = enabled)
SKIP_WP_CLI=false                    # Skip WP-CLI plugin deactivation/reactivation
SKIP_REMOTE_TAR_BACKUP=false         # Skip creating remote tar.gz backup
SKIP_REMOTE_FOLDER_RENAME=false      # Skip renaming remote folder backup

# Compression settings
COMPRESSION_LEVEL=1                  # 1=fastest, 9=best compression (default: 1 for speed)
COMPRESSION_TOOL="pigz"              # pigz (parallel/faster) or gzip (standard)

# Backup file (folder-name.php or style.css) before incrementing version with update-version.bat
VERSION_BACKUP="false"

# Auto-close the window after running the update-version.bat script
VERSION_AUTO_CLOSE="false"

# ----------------------------------------------------------------------------
# OPTIONAL: CUSTOM PATHS - you can leave as-is if you use default settings
# ----------------------------------------------------------------------------

# Backup paths
PREFIX="."						# puts it at the top, you could change to _ or something
LOCAL_BAK_SUFFIX="backups"  	# Folder name for backups
REMOTE_BACKUP_FOLDER=".backups"

# Custom WP folder names
WPCONTENT_FOLDER="wp-content" 	# Change if you renamed wp-content folder
PLUGINS_FOLDER="plugins" 	 	# Change if you renamed plugins folder
THEMES_FOLDER="themes"  	 	# Change if you renamed themes folder


# ============================================================================
# DO NOT CHANGE: AUTO-GENERATED VALUES - Don't edit below this line
# ============================================================================

# First define TYPE-dependent variables
if [[ "$TYPE" == "theme" ]]; then
    LOCAL_BACKUP_FOLDER="${PREFIX}${TYPE}_${LOCAL_BAK_SUFFIX}"   	# e.g. .themes_backups
    REMOTE_TARGET_FOLDER="${WPCONTENT_FOLDER}/${THEMES_FOLDER}"     # e.g. wp-content/themes
    MAIN_FILE_SUFFIX="/style.css"  									# Themes use style.css for version
    TYPE_PLURAL="themes"
else
    LOCAL_BACKUP_FOLDER="${PREFIX}${TYPE}_${LOCAL_BAK_SUFFIX}"  	# e.g. .plugins_backups
    REMOTE_TARGET_FOLDER="${WPCONTENT_FOLDER}/${PLUGINS_FOLDER}"    # e.g. wp-content/plugins
    MAIN_FILE_SUFFIX="/${FOLDER_NAME}.php"  				        # Plugins use main plugin file
    TYPE_PLURAL="plugins"
fi

# Script name
SCRIPT_NAME="deploy-wsl.sh"  # Name of the deployment script

# Build paths using the defined variables
DRIVE_LETTER="${DRIVE_LETTER,,}" # converts to lowercase for WSL path
LOCAL_BASE="/mnt/${DRIVE_LETTER}/${LOCAL_PATH}/${TYPE_PLURAL}"	# e.g. /mnt/c/dev-projects/plugins

# Build full paths from base paths
LOCAL_TARGET_DIR="${LOCAL_BASE}/${FOLDER_NAME}"
BACKUP_DIR="${LOCAL_BASE}/${LOCAL_BACKUP_FOLDER}/backups_${FOLDER_NAME}"
REMOTE_TARGET_DIR="${REMOTE_BASE}/${REMOTE_TARGET_FOLDER}"
REMOTE_BACKUP_DIR="${REMOTE_BASE}/${REMOTE_BACKUP_FOLDER}/backups_${FOLDER_NAME}"
WP_PATH="${REMOTE_BASE}"

# Legacy compatibility - these maintain backward compatibility with existing scripts
LOCAL_PLUGIN_DIR="${LOCAL_TARGET_DIR}"
REMOTE_PLUGINS_DIR="${REMOTE_TARGET_DIR}"
REMOTE_PLUGINS_FOLDER="${REMOTE_TARGET_FOLDER}"
PLUGIN_NAME="${FOLDER_NAME}"  # Backwards compatibility
