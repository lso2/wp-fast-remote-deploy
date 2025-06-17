#!/bin/bash

# WordPress Plugin Fast Deployment Script
# Created by: lso2 (https://github.com/lso2)
# Repository: https://github.com/lso2/wp-fast-remote-deploy
# License: MIT

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config.sh"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Configuration file not found: $CONFIG_FILE"
    echo "Please create config.sh in the root directory."
    exit 1
fi

source "$CONFIG_FILE"

# SSH connection reuse for speed
SSH_OPTS="-i $SSH_KEY -p $SSH_PORT -o ControlMaster=auto -o ControlPath=/tmp/ssh-%r@%h:%p -o ControlPersist=30s -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no"

# Colors for output - cleaner scheme
RED='\033[38;2;239;68;68m'      # Clean red
GREEN='\033[38;2;34;197;94m'    # Clean green
YELLOW='\033[1;33m'				# Yellow
GOLD='\033[38;2;251;191;36m'	# Gold
BLUE='\033[38;2;59;130;246m'    # Clean blue
PURPLE='\033[38;2;147;51;234m'  # Clean purple
CYAN='\033[38;2;6;182;212m'     # Clean cyan
PINK='\033[38;2;236;72;153m'    # Clean pink
GREY='\033[38;2;107;114;128m'   # Muted grey
WHITE='\033[38;2;255;255;255m'  # Pure white
NC='\033[0m' 					# No Color

echo ""
echo -e "${GREY} Deployment script v$VERSION${NC}"
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

echo -e "${PINK}+  ${TYPE^} Version:${NC} ${WHITE}$VERSION_NUMBER${NC}"
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

# Now connect to remote (SSH connection should be established)
echo -e "${BLUE}+  Preparing remote...${NC}"

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
REMOTE_VERSION="unknown"
if [[ "$WP_CLI_CHECK" == *"wp_available"* ]]; then
    USE_WP_CLI=true
fi

# Extract remote version if available
if [[ "$WP_CLI_CHECK" == *"backed_up_and_renamed:"* ]]; then
    REMOTE_VERSION=$(echo "$WP_CLI_CHECK" | grep -o "backed_up_and_renamed:[^[:space:]]*" | cut -d':' -f2)
fi

echo ""
echo -e "${CYAN}+  Uploading...${NC}"
scp -i "$SSH_KEY" -P "$SSH_PORT" "$TEMP_TAR" "$SSH_USER@$SSH_HOST:/tmp/$FOLDER_NAME-upload.tar.gz" 2>/dev/null && \
ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "cd '$REMOTE_TARGET_DIR' && tar -xzf /tmp/$FOLDER_NAME-upload.tar.gz && rm /tmp/$FOLDER_NAME-upload.tar.gz" 2>/dev/null

if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ Upload and extract failed${NC}"
    rm -f "$TEMP_TAR"
    exit 1
fi

# Reactivate based on type if WP-CLI available
echo ""
if [[ "$SKIP_WP_CLI" != true && "$USE_WP_CLI" == true ]]; then
    if [[ "$TYPE" == "theme" ]]; then
        echo -e "${PINK}+  Theme deployment complete${NC}"
        echo -e "${YELLOW}+  Theme: ${WHITE}Ready for activation in WP Admin → Appearance → Themes${NC}"
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
echo -e "${GREEN}---------------------------------------------------${NC}"
echo -e "${GREEN}+  Deployment successful!${NC}"
echo -e "${GREEN}---------------------------------------------------${NC}"
echo ""
echo -e "${CYAN}+  Previous ${TYPE^} Version:${NC} ${WHITE}$REMOTE_VERSION${NC}"
echo -e "${CYAN}+  New ${TYPE^} Version:${NC} ${WHITE}$VERSION_NUMBER${NC}"
echo -e "${PURPLE}+  Files:${NC} $FILE_COUNT_INFO"
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
