#!/bin/bash

# WordPress Plugin Fast Deployment Script
# Created by: lso2 (https://github.com/lso2)
# Repository: https://github.com/lso2/wp-fast-remote-deploy
# License: GPLv3

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config.sh"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Configuration file not found: $CONFIG_FILE"
    echo "Please create config.sh in the root directory."
    exit 1
fi

source "$CONFIG_FILE"

# Override LOCAL_BASE with actual script location or use configured overrides
SCRIPT_ACTUAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_ROOT_DIR="$(dirname "$SCRIPT_ACTUAL_DIR")"

# Use override paths if configured, otherwise auto-detect
if [[ -n "$LOCAL_PATH_OVERRIDE" && -n "$DRIVE_LETTER_OVERRIDE" ]]; then
    # Use manual override paths
    LOCAL_BASE="/mnt/${DRIVE_LETTER_OVERRIDE}/${LOCAL_PATH_OVERRIDE}/${TYPE_PLURAL}"
else
    # Auto-detect from script location
    LOCAL_BASE="$(dirname "$SCRIPT_ROOT_DIR")/${TYPE_PLURAL}"
fi

LOCAL_TARGET_DIR="${LOCAL_BASE}/${FOLDER_NAME}"
BACKUP_DIR="${LOCAL_BASE}/${LOCAL_BACKUP_FOLDER}/backups_${FOLDER_NAME}"

# SSH connection reuse for speed
SSH_OPTS="-i $SSH_KEY -p $SSH_PORT -o ControlMaster=auto -o ControlPath=/tmp/ssh-%r@%h:%p -o ControlPersist=30s -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no"

# Colors for output - cleaner scheme
RED='\033[38;2;239;68;68m'       # Clean red
GREEN='\033[38;2;34;197;94m'     # Clean green
YELLOW='\033[1;33m'				 # Yellow
GOLD='\033[38;2;251;191;36m'	 # Gold
BLUE='\033[38;2;59;130;246m'     # Clean blue
PURPLE='\033[38;2;147;51;234m'   # Clean purple
PURPLE2='\033[38;2;177;81;255m'  # Lighter purple
PURPLE3='\033[38;2;207;111;255m' # Brighter purple
CYAN='\033[38;2;6;182;212m'      # Clean cyan
PINK='\033[38;2;236;72;153m'     # Clean pink
GREY='\033[38;2;107;114;128m'    # Muted grey
GREY2='\033[38;2;150;160;170m'   # Muted lighter grey
GREY3='\033[38;2;187;194;208m'   # Muted brighter grey
WHITE='\033[38;2;255;255;255m'   # Pure white
NC='\033[0m' 					 # No Color

echo -e "${GREY}---------------------------------------------------${NC}"
echo ""
echo -e "${BLUE}          Fast Deployment Script ${GREY}v$VERSION${NC}"
# Convert WSL path to Windows path properly using bash regex
if [[ "$SCRIPT_ROOT_DIR" =~ ^/mnt/([a-z])/(.*) ]]; then
    DRIVE_LETTER="${BASH_REMATCH[1]^^}"
    REST_PATH="${BASH_REMATCH[2]//\//\\\\}"
    WIN_PATH="${DRIVE_LETTER}:\\${REST_PATH}"
else
    WIN_PATH="$SCRIPT_ROOT_DIR"
fi
echo -e ""
echo -e "${GREY}---------------------------------------------------${NC}"
echo -e ""
echo -e "${GREY} Local path:${NC} ${GREY}$WIN_PATH\\\\$FOLDER_NAME${NC}"
echo -e "${GREY} Remote path:${NC} ${GREY}$REMOTE_BASE${NC}"
# echo -e "${GREY} Converted path:${NC} ${GREY}$SCRIPT_ROOT_DIR${NC}"
echo ""
echo -e "${PINK}+  Deploy $TYPE:${NC} ${GOLD}$FOLDER_NAME${NC}"

# Start SSH connection in background immediately
{
    # Establish SSH master connection in background
    ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "exit" 2>/dev/null
} &
SSH_CONNECT_PID=$!

# Check pigz availability (no installation attempts)
PIGZ_AVAILABLE=false
if [[ "$COMPRESSION_TOOL" == "pigz" ]]; then
    if command -v pigz >/dev/null 2>&1; then
        PIGZ_AVAILABLE=true
    fi
fi

# Extract version based on type
if [[ "$TYPE" == "theme" ]]; then
    # For themes, check style.css
    VERSION_NUMBER=$(grep -m1 "Version:" "$LOCAL_TARGET_DIR/style.css" | sed 's/.*Version:[[:space:]]*\([0-9.]*\).*/\1/' | tr -d "\"' ")
else
    # For plugins, check main plugin file
    VERSION_NUMBER=$(grep -m1 "Version:" "$LOCAL_TARGET_DIR/$FOLDER_NAME.php" | sed 's/.*Version:[[:space:]]*\([0-9.]*\).*/\1/' | tr -d "\"' ")
fi

if [[ -z "$VERSION_NUMBER" ]]; then
    echo -e "${RED}+ No $TYPE version found${NC}"
    exit 1
fi

# Legacy compatibility
PLUGIN_VERSION="$VERSION_NUMBER"

# Show version immediately like the original script
echo -e "${PURPLE}+  Local ${TYPE} version:${NC} ${WHITE}$VERSION_NUMBER${NC}"

# Check if versions match and auto-increment if enabled
if [[ "$AUTO_INCREMENT_VERSION" == "true" ]]; then
    # Get remote version by connecting to server
    REMOTE_VERSION=$(ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "
        export LC_ALL=C LANG=C LANGUAGE=C TERM=xterm
        if [ -d '$REMOTE_TARGET_DIR/$FOLDER_NAME' ]; then
            if [ '$TYPE' = 'theme' ]; then
                grep -i version '$REMOTE_TARGET_DIR/$FOLDER_NAME/style.css' | head -1 | grep -o '[0-9]\+\.[0-9]\+\.*[0-9]*' | head -1
            else
                grep -i version '$REMOTE_TARGET_DIR/$FOLDER_NAME/$FOLDER_NAME.php' | head -1 | grep -o '[0-9]\+\.[0-9]\+\.*[0-9]*' | head -1
            fi
        else
            echo 'not_found'
        fi
    " 2>/dev/null)
    
    if [[ -z "$REMOTE_VERSION" || "$REMOTE_VERSION" == "not_found" ]]; then
        REMOTE_VERSION="not found"
    fi
    
    if [[ "$REMOTE_VERSION" != "not found" ]]; then
        # Update the line to show both versions
        echo -e "\r\033[1A\033[K${PURPLE}+  Local ${TYPE} version:${NC} ${WHITE}$VERSION_NUMBER${NC}  ${GREY}|${NC}  ${PURPLE2}Remote Version:${NC} ${WHITE}$REMOTE_VERSION${NC}"
        
        if [[ "$VERSION_NUMBER" == "$REMOTE_VERSION" ]]; then
            echo -e "${GREY}+  Checking remote version...${NC}"
            
            # Implement version increment logic directly in bash
            # Determine target file based on type
            if [[ "$TYPE" == "theme" ]]; then
                TARGET_FILE="$LOCAL_TARGET_DIR/style.css"
            else
                TARGET_FILE="$LOCAL_TARGET_DIR/$FOLDER_NAME.php"
            fi
            
            # Find current version and increment it
            CURRENT_VER="$VERSION_NUMBER"
            
            # Increment patch version
            IFS='.' read -r major minor patch <<< "$CURRENT_VER"
            major=${major:-1}
            minor=${minor:-0}
            patch=${patch:-0}
            patch=$((patch + 1))
            NEW_VER="$major.$minor.$patch"
            
            # Update the file
            sed -i "s/\( \* Version: \)$CURRENT_VER/\1$NEW_VER/" "$TARGET_FILE"
            
            # Update readme.txt if it exists
            README_FILE="$LOCAL_TARGET_DIR/readme.txt"
            if [[ -f "$README_FILE" ]]; then
                sed -i "s/^Stable tag: $CURRENT_VER/Stable tag: $NEW_VER/" "$README_FILE"
            fi
            
            # For plugins, also update define version if it exists
            if [[ "$TYPE" == "plugin" ]]; then
                sed -i "s/'$CURRENT_VER'/'$NEW_VER'/" "$TARGET_FILE"
            fi
            
            UPDATE_RESULT=0
            
            # Re-extract the updated version
            if [[ "$TYPE" == "theme" ]]; then
                NEW_VERSION_NUMBER=$(grep -m1 "Version:" "$LOCAL_TARGET_DIR/style.css" | sed 's/.*Version:[[:space:]]*\([0-9.]*\).*/\1/' | tr -d "\"' ")
            else
                NEW_VERSION_NUMBER=$(grep -m1 "Version:" "$LOCAL_TARGET_DIR/$FOLDER_NAME.php" | sed 's/.*Version:[[:space:]]*\([0-9.]*\).*/\1/' | tr -d "\"' ")
            fi
            
            # Verify the version actually changed
            if [[ "$NEW_VERSION_NUMBER" == "$VERSION_NUMBER" ]]; then
                # Version increment failed, show error
                echo -e "\r\033[1A\033[K${RED}+  Version increment failed!${NC} (stayed at $VERSION_NUMBER)"
            else
                # Version increment succeeded
                echo -e "\r\033[1A\033[K${PURPLE3}+  Local ${TYPE} auto-incremented to:${NC} ${WHITE}$NEW_VERSION_NUMBER${NC}"
                VERSION_NUMBER="$NEW_VERSION_NUMBER"
            fi
        fi
    fi
fi
echo ""

# Create backup directories
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%H%M%S)

# Only create tar.gz backup locally (no folder copy)
echo -e "${PURPLE}+  Creating local backup...${NC}"
{
    cd "$(dirname "$LOCAL_TARGET_DIR")"
    
    # Create tar.gz backup only locally
    TARGZ_NAME="$FOLDER_NAME.$VERSION_NUMBER-$TIMESTAMP.tar.gz"
    if [[ "$COMPRESSION_TOOL" == "pigz" && "$PIGZ_AVAILABLE" == "true" ]]; then
        # Use pigz
        tar --use-compress-program="pigz -$COMPRESSION_LEVEL" -cf "$BACKUP_DIR/$TARGZ_NAME" "$(basename "$LOCAL_TARGET_DIR")" &
    else
        # Use gzip (either configured or fallback)
        tar -cf "$BACKUP_DIR/$TARGZ_NAME" "$(basename "$LOCAL_TARGET_DIR")" --use-compress-program="gzip -$COMPRESSION_LEVEL" &
    fi
    TARGZ_PID=$!
    
    # Create upload archive (background)
    TEMP_TAR="/tmp/$FOLDER_NAME-upload-$TIMESTAMP.tar.gz"
    if [[ "$COMPRESSION_TOOL" == "pigz" && "$PIGZ_AVAILABLE" == "true" ]]; then
        # Use pigz
        tar --use-compress-program="pigz -$COMPRESSION_LEVEL" -cf "$TEMP_TAR" "$(basename "$LOCAL_TARGET_DIR")" &
    else
        # Use gzip (either configured or fallback)
        tar -cf "$TEMP_TAR" "$(basename "$LOCAL_TARGET_DIR")" --use-compress-program="gzip -$COMPRESSION_LEVEL" &
    fi
    UPLOAD_PID=$!
}

# Wait for upload archive to be ready
# echo -e "${GREY}+  Preparing upload...${NC}"
wait $UPLOAD_PID

# Wait for SSH connection to be ready (should be done by now)
wait $SSH_CONNECT_PID

# Optional Git integration
if [ "$GIT_ENABLED" = "true" ] && [ "$GIT_AUTO_COMMIT" = "true" ]; then
    echo -e "${CYAN}+  Git integration...${NC}"
    
    # Configure Git user (one-time per session)
    git config user.name "$GIT_USER_NAME" 2>/dev/null || true
    git config user.email "$GIT_USER_EMAIL" 2>/dev/null || true
    
    # Check if we're in a Git repository
    if [ ! -d ".git" ]; then
        echo -e "${GREY}    Initializing Git repository...${NC}"
        git init >/dev/null 2>&1
        if [ -n "$GIT_REPO_URL" ]; then
            git remote add origin "$GIT_REPO_URL" >/dev/null 2>&1 || true
        fi
    fi
    
    # Check for changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        # Stage all changes
        git add . >/dev/null 2>&1
        
        # Create commit with deployment info
        COMMIT_MSG="Auto-deploy: $FOLDER_NAME v$VERSION_NUMBER - $(date '+%Y-%m-%d %H:%M:%S')"
        git commit -m "$COMMIT_MSG" >/dev/null 2>&1
        
        # Push to remote repository
        if [ -n "$GIT_TOKEN" ] && [ -n "$GIT_REPO_URL" ]; then
            # Extract username/repo from URL for token authentication
            if [[ "$GIT_REPO_URL" == *"github.com"* ]]; then
                REPO_PATH=$(echo "$GIT_REPO_URL" | sed 's|https://github.com/||' | sed 's|\.git$||')
                git push "https://$GIT_TOKEN@github.com/$REPO_PATH.git" "$GIT_BRANCH" >/dev/null 2>&1
                
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}    ✅ Changes saved to Git repository${NC}"
                else
                    echo -e "${YELLOW}    ⚠️  Git push failed (continuing with deployment)${NC}"
                fi
            else
                echo -e "${YELLOW}    ⚠️  Non-GitHub repository detected, skipping push${NC}"
            fi
        else
            echo -e "${YELLOW}    ⚠️  Git token or repository URL not configured${NC}"
        fi
    else
        echo -e "${GREY}    No changes to commit${NC}"
    fi
fi

# Optional database backup during deployment
if [ "$DB_BACKUP_MODE" = "auto" ]; then
    echo -e "${PURPLE}+  Creating database backup...${NC}"
    
    # Determine backup directory
    if [ "$DB_PATH_ENABLED" = "true" ] && [ -n "$DB_PATH" ]; then
        DB_BACKUP_DIR="$DB_PATH"
    else
        DB_BACKUP_DIR="~/db_backups/$FOLDER_NAME"
    fi
    
    # Create database backup with version number by reading wp-config.php or using manual overrides
    DB_BACKUP_RESULT=$(ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "
        export LC_ALL=C LANG=C LANGUAGE=C TERM=xterm
        
        # Check for manual database overrides first
        if [ '$DB_OVERRIDE_ENABLED' = 'true' ] && [ -n '$DB_NAME' ] && [ -n '$DB_USER' ] && [ -n '$DB_PASS' ]; then
            DB_NAME='$DB_NAME'
            DB_USER='$DB_USER'
            DB_PASS='$DB_PASS'
            DB_HOST='${DB_HOST:-localhost}'
            DB_PORT='${DB_PORT:-3306}'
        else
            # Read database configuration from wp-config.php
            WP_CONFIG_PATH='$WP_PATH/wp-config.php'
            
            if [ ! -f \"\$WP_CONFIG_PATH\" ]; then
                echo 'wp_config_not_found'
                exit 1
            fi
            
            # Extract database configuration from wp-config.php
            DB_NAME=\$(grep -E \"define\\(.*'DB_NAME'\" \"\$WP_CONFIG_PATH\" | sed -E \"s/.*'DB_NAME'[^']*'([^']*)'.*/ /\" | tr -d \" \")
            DB_USER=\$(grep -E \"define\\(.*'DB_USER'\" \"\$WP_CONFIG_PATH\" | sed -E \"s/.*'DB_USER'[^']*'([^']*)'.*/ /\" | tr -d \" \")
            DB_PASS=\$(grep -E \"define\\(.*'DB_PASSWORD'\" \"\$WP_CONFIG_PATH\" | sed -E \"s/.*'DB_PASSWORD'[^']*'([^']*)'.*/ /\" | tr -d \" \")
            DB_HOST=\$(grep -E \"define\\(.*'DB_HOST'\" \"\$WP_CONFIG_PATH\" | sed -E \"s/.*'DB_HOST'[^']*'([^']*)'.*/ /\" | tr -d \" \")
            
            # Set default host if not found
            if [ -z \"\$DB_HOST\" ]; then
                DB_HOST='localhost'
            fi
            
            # Extract port if specified in DB_HOST (format: host:port)
            if [[ \"\$DB_HOST\" == *':'* ]]; then
                DB_PORT=\$(echo \"\$DB_HOST\" | cut -d':' -f2)
                DB_HOST=\$(echo \"\$DB_HOST\" | cut -d':' -f1)
            else
                DB_PORT='3306'
            fi
            
            # Validate that we got the database configuration
            if [ -z \"\$DB_NAME\" ] || [ -z \"\$DB_USER\" ] || [ -z \"\$DB_PASS\" ]; then
                echo 'wp_config_parse_failed'
                exit 1
            fi
        fi
        
        # Create backup directory
        mkdir -p '$DB_BACKUP_DIR'
        
        # Create backup with version info (skip connection test - some users have dump-only privileges)
        BACKUP_NAME='$FOLDER_NAME-$VERSION_NUMBER-$TIMESTAMP.sql'
        if mysqldump -h\"\$DB_HOST\" -P\"\$DB_PORT\" -u\"\$DB_USER\" -p\"\$DB_PASS\" \\
            --single-transaction \\
            --no-tablespaces \\
            --routines \\
            --triggers \\
            --lock-tables=false \\
            \"\$DB_NAME\" > '$DB_BACKUP_DIR/\$BACKUP_NAME' 2>/dev/null; then
            
            if [ -s '$DB_BACKUP_DIR/\$BACKUP_NAME' ]; then
                echo 'db_backup_success'
            else
                echo 'db_backup_empty'
                rm -f '$DB_BACKUP_DIR/\$BACKUP_NAME'
                exit 1
            fi
        else
            echo 'db_backup_failed'
            exit 1
        fi
    " 2>/dev/null)
    
    if [[ "$DB_BACKUP_RESULT" == "db_backup_success" ]]; then
        echo -e "${GREEN}    ✅ Database backup created successfully${NC}"
    elif [[ "$DB_BACKUP_RESULT" == "wp_config_not_found" ]]; then
        echo -e "${YELLOW}    ⚠️  Database auto-backup skipped (wp-config.php not found)${NC}"
    elif [[ "$DB_BACKUP_RESULT" == "wp_config_parse_failed" ]]; then
        echo -e "${YELLOW}    ⚠️  Database auto-backup skipped (could not parse wp-config.php)${NC}"
    elif [[ "$DB_BACKUP_RESULT" == "db_connection_failed" ]]; then
        echo -e "${YELLOW}    ⚠️  Database auto-backup failed (connection error, continuing with deployment)${NC}"
    else
        echo -e "${YELLOW}    ⚠️  Database auto-backup failed (continuing with deployment)${NC}"
    fi
fi

# Upload success message, replaces previous line
echo -e "\r\033[1A\033[K${PURPLE}+  Creating local backup...  ${PURPLE3}SUCCESS!${NC}"
echo -e ""

# Now connect to remote (SSH connection should be established)
echo -e "${GREY}+  Preparing remote ${TYPE} upload...${NC}"

# Establish master connection and do all remote prep
WP_CLI_CHECK=$(ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "
    export LC_ALL=C LANG=C LANGUAGE=C TERM=xterm
    COMPRESSION_LEVEL='$COMPRESSION_LEVEL'
    
    # Check remote pigz availability (no installation attempts)
    if [ '$COMPRESSION_TOOL' = 'pigz' ] && command -v pigz >/dev/null 2>&1; then
        REMOTE_PIGZ=true
        echo 'remote_pigz_available'
    elif [ '$COMPRESSION_TOOL' = 'pigz' ]; then
        REMOTE_PIGZ=false
        echo 'remote_pigz_not_available'
    else
        REMOTE_PIGZ=false
    fi
    
    # Prepare directories
    mkdir -p '$REMOTE_TARGET_DIR'
    mkdir -p '$REMOTE_BACKUP_DIR'
    
    # Check WP-CLI and handle deactivation based on type
    if [ '$SKIP_WP_CLI' != 'true' ] && which wp >/dev/null 2>&1; then
        echo 'wp_available'
        # For themes, we don't deactivate (can't deactivate active theme)
        # For plugins, deactivate before deployment
        if [ '$TYPE' = 'plugin' ]; then
            cd '$WP_PATH' && wp plugin deactivate '$FOLDER_NAME' --allow-root >/dev/null 2>&1 || true
        fi
    else
        echo 'wp_not_found'
    fi
    
    # Handle existing remote folder
    if [ -d '$REMOTE_TARGET_DIR/$FOLDER_NAME' ]; then
        # Get current remote version based on type
        if [ '$TYPE' = 'theme' ]; then
            REMOTE_VERSION=\$(grep -i version '$REMOTE_TARGET_DIR/$FOLDER_NAME/style.css' | head -1 | grep -o '[0-9]\+\.[0-9]\+\.*[0-9]*' | head -1)
        else
            REMOTE_VERSION=\$(grep -i version '$REMOTE_TARGET_DIR/$FOLDER_NAME/$FOLDER_NAME.php' | head -1 | grep -o '[0-9]\+\.[0-9]\+\.*[0-9]*' | head -1)
        fi
        if [ -z "\$REMOTE_VERSION" ]; then
            REMOTE_VERSION=old
        fi
        
        # Create remote tar.gz backup BEFORE renaming folder
        if [ '$SKIP_REMOTE_TAR_BACKUP' != 'true' ]; then
            if [ \"\$REMOTE_PIGZ\" = 'true' ]; then
                tar -cf '$REMOTE_BACKUP_DIR/$FOLDER_NAME.'\$REMOTE_VERSION'-$TIMESTAMP.tar' -C '$REMOTE_TARGET_DIR' '$FOLDER_NAME' &
                PIGZ_PID=\$!
                wait \$PIGZ_PID
                pigz -f '$REMOTE_BACKUP_DIR/$FOLDER_NAME.'\$REMOTE_VERSION'-$TIMESTAMP.tar'
            else
                tar -czf '$REMOTE_BACKUP_DIR/$FOLDER_NAME.'\$REMOTE_VERSION'-$TIMESTAMP.tar.gz' -C '$REMOTE_TARGET_DIR' '$FOLDER_NAME' &
            fi
            TAR_PID=\$!
            # Wait for tar to complete before moving folder
            wait \$TAR_PID
        fi
        
        # Then rename folder
        if [ '$SKIP_REMOTE_FOLDER_RENAME' != 'true' ]; then
            if [ -d '$REMOTE_TARGET_DIR/$FOLDER_NAME.'\$REMOTE_VERSION ]; then
                mv '$REMOTE_TARGET_DIR/$FOLDER_NAME' '$REMOTE_TARGET_DIR/$FOLDER_NAME.'\$REMOTE_VERSION'-$TIMESTAMP'
                echo 'backed_up_and_renamed:'\$REMOTE_VERSION':with_timestamp'
            else
                mv '$REMOTE_TARGET_DIR/$FOLDER_NAME' '$REMOTE_TARGET_DIR/$FOLDER_NAME.'\$REMOTE_VERSION
                echo 'backed_up_and_renamed:'\$REMOTE_VERSION':no_timestamp'
            fi
        else
            rm -rf '$REMOTE_TARGET_DIR/$FOLDER_NAME'
            echo 'backed_up_and_renamed:'\$REMOTE_VERSION':deleted'
        fi
    else
        echo 'no_existing'
    fi
" 2>/dev/null)

USE_WP_CLI=false
if [[ "$WP_CLI_CHECK" == *"wp_available"* ]]; then
    USE_WP_CLI=true
fi

# Extract remote version if available (only if auto-increment is disabled)
if [[ "$WP_CLI_CHECK" == *"backed_up_and_renamed:"* && "$AUTO_INCREMENT_VERSION" != "true" ]]; then
    REMOTE_VERSION=$(echo "$WP_CLI_CHECK" | grep -o "backed_up_and_renamed:[^[:space:]]*" | cut -d':' -f2)
fi

#echo ""
echo -e "${CYAN}+  Uploading ${TYPE}...${NC}"
scp -i "$SSH_KEY" -P "$SSH_PORT" "$TEMP_TAR" "$SSH_USER@$SSH_HOST:/tmp/$FOLDER_NAME-upload.tar.gz" 2>/dev/null && \
ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "cd '$REMOTE_TARGET_DIR' && tar -xzf /tmp/$FOLDER_NAME-upload.tar.gz && rm /tmp/$FOLDER_NAME-upload.tar.gz" 2>/dev/null

if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ Upload and extract failed${NC}"
    rm -f "$TEMP_TAR"
    exit 1
fi

# Function to deploy to a specific server
deploy_to_server() {
    local server_name="$1"
    local target_ssh_host="$2"
    local target_ssh_user="$3"
    local target_remote_base="$4"
    local target_wp_path="$5"
    
    echo -e "${CYAN}+  Deploying to ${GOLD}$server_name${CYAN} server...${NC}"
    
    # Override server settings temporarily
    local original_ssh_host="$SSH_HOST"
    local original_ssh_user="$SSH_USER"
    local original_remote_base="$REMOTE_BASE"
    local original_wp_path="$WP_PATH"
    local original_remote_target_dir="$REMOTE_TARGET_DIR"
    local original_remote_backup_dir="$REMOTE_BACKUP_DIR"
    
    SSH_HOST="$target_ssh_host"
    SSH_USER="$target_ssh_user"
    REMOTE_BASE="$target_remote_base"
    WP_PATH="$target_wp_path"
    REMOTE_TARGET_DIR="$target_remote_base/${REMOTE_TARGET_FOLDER}"
    REMOTE_BACKUP_DIR="$target_remote_base/${REMOTE_BACKUP_FOLDER}/backups_${FOLDER_NAME}"
    
    # Upload to target server
    echo -e "${BLUE}    Uploading to $server_name...${NC}"
    scp -i "$SSH_KEY" -P "$SSH_PORT" "$TEMP_TAR" "$SSH_USER@$SSH_HOST:/tmp/$FOLDER_NAME-upload.tar.gz" 2>/dev/null
    
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}    ❌ Upload to $server_name failed${NC}"
        # Restore original settings
        SSH_HOST="$original_ssh_host"
        SSH_USER="$original_ssh_user"
        REMOTE_BASE="$original_remote_base"
        WP_PATH="$original_wp_path"
        REMOTE_TARGET_DIR="$original_remote_target_dir"
        REMOTE_BACKUP_DIR="$original_remote_backup_dir"
        return 1
    fi
    
    # Deploy on target server
    SERVER_DEPLOY_RESULT=$(ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "
        export LC_ALL=C LANG=C LANGUAGE=C TERM=xterm
        
        # Prepare directories
        mkdir -p '$REMOTE_TARGET_DIR'
        mkdir -p '$REMOTE_BACKUP_DIR'
        
        # Check WP-CLI and handle deactivation
        USE_WP_CLI=false
        if [ '$SKIP_WP_CLI' != 'true' ] && which wp >/dev/null 2>&1; then
            USE_WP_CLI=true
            if [ '$TYPE' = 'plugin' ]; then
                cd '$WP_PATH' && wp plugin deactivate '$FOLDER_NAME' --allow-root >/dev/null 2>&1 || true
            fi
        fi
        
        # Handle existing folder
        if [ -d '$REMOTE_TARGET_DIR/$FOLDER_NAME' ]; then
            if [ '$TYPE' = 'theme' ]; then
                REMOTE_VERSION=\$(grep -i version '$REMOTE_TARGET_DIR/$FOLDER_NAME/style.css' | head -1 | grep -o '[0-9]\+\.[0-9]\+\.*[0-9]*' | head -1)
            else
                REMOTE_VERSION=\$(grep -i version '$REMOTE_TARGET_DIR/$FOLDER_NAME/$FOLDER_NAME.php' | head -1 | grep -o '[0-9]\+\.[0-9]\+\.*[0-9]*' | head -1)
            fi
            if [ -z \"\$REMOTE_VERSION\" ]; then
                REMOTE_VERSION=old
            fi
            
            # Create backup and rename
            if [ '$SKIP_REMOTE_TAR_BACKUP' != 'true' ]; then
                tar -czf '$REMOTE_BACKUP_DIR/$FOLDER_NAME.'\$REMOTE_VERSION'-$TIMESTAMP.tar.gz' -C '$REMOTE_TARGET_DIR' '$FOLDER_NAME' &
                wait
            fi
            
            if [ '$SKIP_REMOTE_FOLDER_RENAME' != 'true' ]; then
                mv '$REMOTE_TARGET_DIR/$FOLDER_NAME' '$REMOTE_TARGET_DIR/$FOLDER_NAME.'\$REMOTE_VERSION
            else
                rm -rf '$REMOTE_TARGET_DIR/$FOLDER_NAME'
            fi
        fi
        
        # Extract new version
        cd '$REMOTE_TARGET_DIR' && tar -xzf /tmp/$FOLDER_NAME-upload.tar.gz && rm /tmp/$FOLDER_NAME-upload.tar.gz
        
        # Reactivate if plugin and WP-CLI available
        if [ \"\$USE_WP_CLI\" = \"true\" ] && [ '$TYPE' = 'plugin' ]; then
            cd '$WP_PATH' && wp plugin activate '$FOLDER_NAME' --allow-root >/dev/null 2>&1
            if [ \$? -eq 0 ]; then
                echo 'plugin_reactivated'
            else
                echo 'plugin_activation_failed'
            fi
        elif [ '$TYPE' = 'theme' ]; then
            echo 'theme_deployed'
        else
            echo 'manual_activation_required'
        fi
        
        echo 'deployment_successful'
    " 2>/dev/null)
    
    # Restore original settings
    SSH_HOST="$original_ssh_host"
    SSH_USER="$original_ssh_user"
    REMOTE_BASE="$original_remote_base"
    WP_PATH="$original_wp_path"
    REMOTE_TARGET_DIR="$original_remote_target_dir"
    REMOTE_BACKUP_DIR="$original_remote_backup_dir"
    
    if [[ "$SERVER_DEPLOY_RESULT" == *"deployment_successful"* ]]; then
        echo -e "${GREEN}    ✅ $server_name deployment successful${NC}"
        if [[ "$SERVER_DEPLOY_RESULT" == *"plugin_reactivated"* ]]; then
            echo -e "${GREEN}    ✅ Plugin reactivated on $server_name${NC}"
        elif [[ "$SERVER_DEPLOY_RESULT" == *"theme_deployed"* ]]; then
            echo -e "${YELLOW}    ⚠️  Theme ready for activation on $server_name${NC}"
        elif [[ "$SERVER_DEPLOY_RESULT" == *"manual_activation_required"* ]]; then
            echo -e "${YELLOW}    ⚠️  Manual activation required on $server_name${NC}"
        fi
        return 0
    else
        echo -e "${RED}    ❌ $server_name deployment failed${NC}"
        return 1
    fi
}

# Multi-server deployment logic
if [ "$MULTI_SERVER_ENABLED" = "true" ]; then
    
    # Deploy to staging first
    if [ "$DEPLOY_TO_STAGING" = "true" ] && [ -n "$STAGING_SSH_HOST" ]; then
        echo ""
        deploy_to_server "STAGING" "$STAGING_SSH_HOST" "$STAGING_SSH_USER" "$STAGING_SSH_PATH" "$STAGING_WP_PATH"
        STAGING_SUCCESS=$?
        
        if [ $STAGING_SUCCESS -ne 0 ]; then
            echo -e "${RED}❌ Staging deployment failed - stopping deployment process${NC}"
            rm -f "$TEMP_TAR"
            exit 1
        fi
    fi
    
    # Ask for production deployment
    if [ "$DEPLOY_TO_PRODUCTION" = "true" ] && [ -n "$PRODUCTION_SSH_HOST" ]; then
        echo ""
        echo -e "${YELLOW}Deploy to ${GOLD}PRODUCTION${YELLOW} server?${NC}"
        echo -e "${GREY}Production: $PRODUCTION_SSH_HOST${NC}"
        read -p "Continue with production deployment? (y/N): " confirm
        
        if [[ $confirm =~ ^[Yy]$ ]]; then
            deploy_to_server "PRODUCTION" "$PRODUCTION_SSH_HOST" "$PRODUCTION_SSH_USER" "$PRODUCTION_SSH_PATH" "$PRODUCTION_WP_PATH"
            PRODUCTION_SUCCESS=$?
            
            if [ $PRODUCTION_SUCCESS -eq 0 ]; then
                echo -e "${GREEN}+  Production deployment complete!${NC}"
            else
                echo -e "${RED}+  Production deployment failed${NC}"
            fi
        else
            echo -e "${GREY}Production deployment skipped.${NC}"
        fi
    fi
    
    # Skip the normal single-server deployment
    SKIP_NORMAL_DEPLOYMENT=true
else
    SKIP_NORMAL_DEPLOYMENT=false
fi

# Normal single-server deployment (if not multi-server mode)
if [ "$SKIP_NORMAL_DEPLOYMENT" = "false" ]; then
    # Reactivate based on type if WP-CLI available
    echo ""
    if [[ "$SKIP_WP_CLI" != true && "$USE_WP_CLI" == true ]]; then
        if [[ "$TYPE" == "theme" ]]; then
            echo -e "${GREEN}+  Theme deployment complete!${NC}"
            echo -e "${GREY2}+  Theme ready for activation in WP Admin → Appearance → Themes ${GREY}(if different theme name)${NC}"
        else
            echo -e "${PINK}+  Reactivating plugin...${NC}"
            ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "export LC_ALL=C LANG=C LANGUAGE=C TERM=xterm; cd '$WP_PATH' && wp plugin activate '$FOLDER_NAME' --allow-root" >/dev/null 2>&1
            echo -e "${GREEN}+  Plugin reactivated automatically${NC}"
        fi
    elif [[ "$SKIP_WP_CLI" == true ]]; then
        echo -e "${YELLOW}+  ${TYPE^}: ${WHITE}WP-CLI operations skipped${NC}"
    else
        if [[ "$TYPE" == "theme" ]]; then
            echo -e "${YELLOW}+  Theme: ${WHITE}Ready for activation in WP Admin${NC}"
        else
            echo -e "${YELLOW}+  Plugin: ${WHITE}Manual activation required${NC}"
        fi
    fi
fi

# Wait for local backup to complete
wait $TARGZ_PID

# Cleanup
rm -f "$TEMP_TAR"

# Verify the deployment based on type
echo ""
echo -e "${PURPLE}+  Verifying deployment...${NC}"
if [[ "$TYPE" == "theme" ]]; then
    VERIFY_FILE=$(ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "[ -f '$REMOTE_TARGET_DIR/$FOLDER_NAME/style.css' ] && echo 'found' || echo 'not_found'" 2>/dev/null)
else
    VERIFY_FILE=$(ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "[ -f '$REMOTE_TARGET_DIR/$FOLDER_NAME/$FOLDER_NAME.php' ] && echo 'found' || echo 'not_found'" 2>/dev/null)
fi

if [[ "$VERIFY_FILE" != "found" ]]; then
    echo -e "${RED}ERROR: Deployment verification failed${NC}"
    exit 1
fi

# Optional slow file count verification
if [[ "$SKIP_FILE_COUNT_VERIFICATION" != true ]]; then
    VERIFY=$(ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "find '$REMOTE_TARGET_DIR/$FOLDER_NAME' -type f | wc -l" 2>/dev/null)
    LOCAL_COUNT=$(find "$LOCAL_TARGET_DIR" -type f | wc -l)
    FILE_COUNT_INFO="${WHITE}$VERIFY/$LOCAL_COUNT${NC}"
else
    LOCAL_COUNT=$(find "$LOCAL_TARGET_DIR" -type f | wc -l)
    FILE_COUNT_INFO="${WHITE}$LOCAL_COUNT${NC} ${GREY}files (remote count skipped)${NC}"
fi

echo ""
if [ "$MULTI_SERVER_ENABLED" = "true" ]; then
    echo -e "${GREEN}---------------------------------------------------${NC}"
    echo -e "${GREEN}+  Multi-Server Deployment Complete!${NC}"
    echo -e "${GREEN}---------------------------------------------------${NC}"
    echo ""
    echo -e "${CYAN}+  ${TYPE^}:${NC} ${GOLD}$FOLDER_NAME${NC}"
    echo -e "${CYAN}+  Version:${NC} ${WHITE}$VERSION_NUMBER${NC}"
    
    if [ "$DEPLOY_TO_STAGING" = "true" ] && [ -n "$STAGING_SSH_HOST" ]; then
        echo -e "${CYAN}+  Staging:${NC} ${GREEN}✅ Deployed to $STAGING_SSH_HOST${NC}"
    fi
    
    if [ "$DEPLOY_TO_PRODUCTION" = "true" ] && [ -n "$PRODUCTION_SSH_HOST" ]; then
        if [ "$PRODUCTION_SUCCESS" = "0" ]; then
            echo -e "${CYAN}+  Production:${NC} ${GREEN}✅ Deployed to $PRODUCTION_SSH_HOST${NC}"
        else
            echo -e "${CYAN}+  Production:${NC} ${YELLOW}⚠️  Skipped or failed${NC}"
        fi
    fi
    
    echo -e "${PURPLE2}+  Files:${NC} $FILE_COUNT_INFO"
else


	# Upload success message, replaces previous line
    echo -e "${GREEN}---------------------------------------------------${NC}"
    echo -e "${GREEN}+  Deployment successful!${NC}"
    echo -e "${GREEN}---------------------------------------------------${NC}"
    echo ""
    if [[ "$AUTO_INCREMENT_VERSION" == "true" && -n "$REMOTE_VERSION" && "$REMOTE_VERSION" != "not found" ]]; then
        echo -e "${CYAN}+  Previous ${TYPE^} Version:${NC} ${WHITE}$REMOTE_VERSION${NC}"
        echo -e "${CYAN}+  New ${TYPE^} Version:${NC} ${WHITE}$VERSION_NUMBER${NC}"
    elif [[ -n "$REMOTE_VERSION" ]]; then
        echo -e "${CYAN}+  Previous ${TYPE^} Version:${NC} ${WHITE}$REMOTE_VERSION${NC}"
        echo -e "${CYAN}+  New ${TYPE^} Version:${NC} ${WHITE}$VERSION_NUMBER${NC}"
    else
        echo -e "${CYAN}+  ${TYPE^} Version:${NC} ${WHITE}$VERSION_NUMBER${NC}"
    fi
    echo -e "${PURPLE}+  Files:${NC} $FILE_COUNT_INFO"
fi
echo ""
echo -e "${GOLD}+  Local Backup:${NC}"
echo -e "${GREY}   +  tar.gz: $BACKUP_DIR/$TARGZ_NAME${NC}"

if [[ "$WP_CLI_CHECK" == *"backed_up_and_renamed"* ]]; then
    echo ""
    echo -e "${GOLD}+  Remote Backups:${NC}"
    if [[ "$SKIP_REMOTE_TAR_BACKUP" != true ]]; then
        echo -e "${GREY}   +  tar.gz: $REMOTE_BACKUP_DIR/$FOLDER_NAME.$REMOTE_VERSION-$TIMESTAMP.tar.gz${NC}"
    fi
    if [[ "$SKIP_REMOTE_FOLDER_RENAME" != true ]]; then
        # Show the actual folder name that was created
        if [[ "$WP_CLI_CHECK" == *"with_timestamp"* ]]; then
            echo -e "${GREY}   +  Remote folder renamed to: $REMOTE_TARGET_DIR/$FOLDER_NAME.$REMOTE_VERSION-$TIMESTAMP${NC}"
        elif [[ "$WP_CLI_CHECK" == *"no_timestamp"* ]]; then
            echo -e "${GREY}   +  Remote folder renamed to: $REMOTE_TARGET_DIR/$FOLDER_NAME.$REMOTE_VERSION${NC}"
        fi
    fi
    if [[ "$SKIP_REMOTE_TAR_BACKUP" == true && "$SKIP_REMOTE_FOLDER_RENAME" == true ]]; then
        echo -e "${GREY}   (remote backups skipped)${NC}"
    fi
fi

echo ""
echo -e "${GREY}---------------------------------------------------${NC}"
if [[ "$AUTO_CLOSE" != true ]]; then
    echo "Press any key to continue..."
    read -n 1 -s
fi

exit 0
