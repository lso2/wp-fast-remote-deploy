#!/bin/bash

# WordPress Plugin Fast Deployment Script - Configuration
# Created by: lso2 (https://github.com/lso2)
# Repository: https://github.com/lso2/wp-fast-remote-deploy
# License: MIT

# Script Configuration
SCRIPT_NAME="deploy-wsl.sh"  # Name of the deployment script
VERSION="1.0.4"              # Script version

# ============================================================================
# PLUGIN CONFIGURATION - Quickly switch between plugins
# ============================================================================

PLUGIN_NAME="your-plugin-name"  # Change this to switch plugins instantly

# ============================================================================
# BASE PATHS - Set once, used for all plugins
# ============================================================================

# Local Environment
LOCAL_BASE="/mnt/c/path/to/your/plugins"

# Remote Environment  
REMOTE_BASE="/path/to/wordpress/root"

# SSH Configuration
SSH_HOST="your-server-ip"
SSH_PORT="22"
SSH_USER="username"
SSH_KEY="~/.ssh/id_rsa"

# ============================================================================
# Other Settings (Optional)
# ============================================================================

# Whether to close the cmd window automatically on completion
AUTO_CLOSE=false

# Other Paths (for customization)
LOCAL_BACKUP_FOLDER=".plugin_backups"  # Folder name for backups
REMOTE_PLUGINS_FOLDER="wp-content/plugins"
REMOTE_BACKUP_FOLDER=".backups"

# ============================================================================
# AUTO-GENERATED VALUES - Don't edit below this line
# ============================================================================

# Build full paths from base paths
LOCAL_PLUGIN_DIR="$LOCAL_BASE/$PLUGIN_NAME"
BACKUP_DIR="$LOCAL_BASE/$LOCAL_BACKUP_FOLDER"
REMOTE_PLUGINS_DIR="$REMOTE_BASE/$REMOTE_PLUGINS_FOLDER"
REMOTE_BACKUP_DIR="$REMOTE_BASE/$REMOTE_BACKUP_FOLDER"
WP_PATH="$REMOTE_BASE"
