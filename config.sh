#!/bin/bash

# WordPress Plugin Fast Deployment Script - Configuration
# Created by: lso2 (https://github.com/lso2)
# Repository: https://github.com/lso2/wp-fast-remote-deploy
# License: MIT

# Script Configuration
SCRIPT_NAME="deploy-wsl.sh"  # Name of the deployment script
VERSION="1.0.1"              # Script version

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
REMOTE_BACKUP_DIR="/path/to/wp-content/plugin-backups"  # Remote backup directory
WP_PATH="/path/to/wordpress/root"
