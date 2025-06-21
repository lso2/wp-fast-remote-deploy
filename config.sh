#!/bin/bash

# WordPress Plugin/Theme Fast Deployment Script - Configuration
# Created by: lso2 (https://github.com/lso2)
# Repository: https://github.com/lso2/wp-fast-remote-deploy
# License: MIT

# Script Configuration
VERSION="3.3.4"  # Script version

# ============================================================================
# REQUIRED: CONFIG - Quickly switch between plugins/themes & Set Type
# ============================================================================

# Folder name of plugin or theme
FOLDER_NAME="my-plugin"  # Change this to switch plugins/themes instantly
# Example: FOLDER_NAME="my-awesome-plugin" or FOLDER_NAME="my-theme"

# Deployment Type
TYPE="plugin"  					# Set to "plugin" or "theme" - switches deployment mode


# ============================================================================
# 							ONE-TIME SETUP
#						  set once and forget
# ============================================================================

# ----------------------------------------------------------------------------
# SET ONCE: REMOTE ENVIRONMENT - Your WordPress server details
# ----------------------------------------------------------------------------

# Remote Environment  
REMOTE_BASE="/path/to/wordpress/root"	# e.g. /home/mysite/public_html/mysite.com

# ----------------------------------------------------------------------------
# SET ONCE: SSH CONFIGURATION - Check readme for setup & key instructions
# ----------------------------------------------------------------------------

# SSH Configuration
SSH_HOST="your-server-ip"
SSH_PORT="22"
SSH_USER="username"
SSH_KEY="~/.ssh/id_rsa"


# ============================================================================
#             NEWBIES CAN STOP HERE! THAT'S ALL YOU NEED! :)
# ============================================================================


#						  DO YOU WISH TO CONTINUE?


# ============================================================================
#                            ADVANCED SETTINGS
#                        for fine-tuning the script
# ============================================================================

# ----------------------------------------------------------------------------
# OPTIONAL: DATABASE BACKUP CONFIGURATION - auto-backup your database
# ----------------------------------------------------------------------------

# Database backups (credentials read automatically from wp-config.php)
DB_BACKUP_MODE="manual"		# "off" = no backups, "manual" = backup tools only, "auto" = backup with deploy

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

# Rollback behavior
ROLLBACK_SYNC_LOCAL="true"   # "true" = rollback both local and remote, "false" = remote only


# ============================================================================
#                              DANGER ZONE!
# ============================================================================


#					 DO YOU REALLY WISH TO CONTINUE?


# ============================================================================
# !                          EXPERT SETTINGS                                 !
# !        These settings may be confusing. Use only if you know.            !
# ============================================================================

# ----------------------------------------------------------------------------
# OPTIONAL: STAGING/DEV DATABASE - uncomment options to use
# ----------------------------------------------------------------------------

# Database override system - use different database than wp-config.php
DB_OVERRIDE_ENABLED="false"			# Whether to use the database override below

# Staging database - manually override the database for development
DB_NAME="db_name" 		# Your database name
DB_USER="db_user" 		# Your sql username
DB_PASS="db_pass" 		# Pass for sql username
DB_HOST="db_host" 		# Advanced: Alternate host for db
DB_PORT="db_port" 		# Advanced: Custom port, if any

# Advanced database backup settings
DB_PATH_ENABLED="false" # Set to true if you want custom backup directory
DB_PATH="/path/to/db/backup/folder" # Enter full path for custom backup location

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

# ----------------------------------------------------------------------------
# OPTIONAL: LOCAL PATH OVERRIDE - only if auto-detection fails
# ----------------------------------------------------------------------------

# ADVANCED: Override auto-detected local paths (leave empty for auto-detection)
LOCAL_PATH_OVERRIDE=""			# e.g. "custom-projects" - overrides auto-detected path
DRIVE_LETTER_OVERRIDE=""		# e.g. "d" - overrides auto-detected drive letter

# ----------------------------------------------------------------------------
# OPTIONAL: EXPERT MODE - GIT INTEGRATION (don't bother if you don't know)
# ----------------------------------------------------------------------------

# Toggle Git
GIT_ENABLED="false"              	# Set to "true" to enable Git integration

# Basic deployment (current)
DEPLOYMENT_METHOD="local"  # "local" Default
						   # "git" for git-based

# Optional Git integration
DEPLOYMENT_METHOD="git_auto"  # "git_auto" = Auto-commit then deploy local
							  # "git_pull" = Deploy from repository

GIT_AUTO_COMMIT="false"          	# Auto-commit before deployment
GIT_REPO_URL=""                  	# https://github.com/username/repo.git
GIT_TOKEN=""                     	# GitHub Personal Access Token
GIT_BRANCH="main"                	# Branch to commit/push to
GIT_USER_NAME="WordPress Deploy" 	# Git commit author name
GIT_USER_EMAIL="deploy@auto.local"	# Git commit author email


# ============================================================================
#                              WARNING!
# ============================================================================


#					DO NOT CONTINUE BELOW THIS LINE!


# ============================================================================
#     DO NOT CHANGE: AUTO-GENERATED VALUES - Don't edit below this line
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

# ----------------------------------------------------------------------------
# AUTO-DETECTION: LOCAL PATHS
# ----------------------------------------------------------------------------

# Auto-detect LOCAL_BASE from config.sh location
CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_BASE="$CONFIG_DIR"

# Apply overrides if provided
if [[ -n "$LOCAL_PATH_OVERRIDE" ]]; then
    CURRENT_DRIVE=$(echo "$CONFIG_DIR" | cut -c6)
    LOCAL_BASE="/mnt/${CURRENT_DRIVE}/${LOCAL_PATH_OVERRIDE}"
fi

if [[ -n "$DRIVE_LETTER_OVERRIDE" ]]; then
    CURRENT_PATH=$(echo "$LOCAL_BASE" | sed 's|^/mnt/[a-z]/||')
    LOCAL_BASE="/mnt/${DRIVE_LETTER_OVERRIDE}/${CURRENT_PATH}"
fi

# Build full paths from base paths
LOCAL_TARGET_DIR="${LOCAL_BASE}/${FOLDER_NAME}"
LOCAL_BACKUP_DIR="${LOCAL_BASE}/${LOCAL_BACKUP_FOLDER}/backups_${FOLDER_NAME}"
REMOTE_TARGET_DIR="${REMOTE_BASE}/${REMOTE_TARGET_FOLDER}"
REMOTE_BACKUP_DIR="${REMOTE_BASE}/${REMOTE_BACKUP_FOLDER}/backups_${FOLDER_NAME}"
WP_PATH="${REMOTE_BASE}"


# Build remote paths
REMOTE_TARGET_DIR="${REMOTE_BASE}/${REMOTE_TARGET_FOLDER}"
REMOTE_BACKUP_DIR="${REMOTE_BASE}/${REMOTE_BACKUP_FOLDER}/backups_${FOLDER_NAME}"
WP_PATH="${REMOTE_BASE}"

# Legacy compatibility - these maintain backward compatibility with existing scripts
REMOTE_PLUGINS_DIR="${REMOTE_TARGET_DIR}"
REMOTE_PLUGINS_FOLDER="${REMOTE_TARGET_FOLDER}"
PLUGIN_NAME="${FOLDER_NAME}"  # Backwards compatibility
