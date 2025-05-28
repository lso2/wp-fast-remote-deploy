#!/bin/bash

# WordPress Plugin Fast Deployment Script
# Created by: lso2 (https://github.com/lso2)
# Repository: https://github.com/lso2/wp-fast-remote-deploy
# License: MIT
# Version: 1.0.1

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
SSH_OPTS="-i $SSH_KEY -p $SSH_PORT -o ControlMaster=auto -o ControlPath=/tmp/ssh-%r@%h:%p -o ControlPersist=10s -o ConnectTimeout=5 -o BatchMode=yes"

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
echo -e "${PINK}⚡  Deploy:${NC} ${GOLD}$PLUGIN_NAME${NC} ${GREY}v$VERSION${NC}"
echo -e "${GREY}Folder: $PLUGIN_FOLDER${NC}"

# Extract version quickly (single grep)
PLUGIN_VERSION=$(grep -m1 "Version:" "$LOCAL_PLUGIN_DIR/$PLUGIN_FOLDER.php" | sed 's/.*Version:[[:space:]]*\([0-9.]*\).*/\1/' | tr -d "\"' ")

if [[ -z "$PLUGIN_VERSION" ]]; then
    echo -e "${RED}❌ No plugin version found${NC}"
    exit 1
fi

echo -e "${PINK}📦 Plugin Version:${NC} ${WHITE}$PLUGIN_VERSION${NC}"
echo ""

# Create backup directories
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%H%M%S)

# Only create tar.gz backup locally (no folder copy)
echo -e "${PURPLE}💾 Creating local backup...${NC}"
{
    cd "$(dirname "$LOCAL_PLUGIN_DIR")"
    
    # Create tar.gz backup only locally
    TARGZ_NAME="$PLUGIN_NAME.$PLUGIN_VERSION-$TIMESTAMP.tar.gz"
    tar -czf "$BACKUP_DIR/$TARGZ_NAME" "$(basename "$LOCAL_PLUGIN_DIR")" &
    TARGZ_PID=$!
    
    # Create upload archive (background)
    TEMP_TAR="/tmp/plugin-upload-$TIMESTAMP.tar.gz"
    tar -czf "$TEMP_TAR" "$(basename "$LOCAL_PLUGIN_DIR")" &
    UPLOAD_PID=$!
}

# Check WP-CLI and prepare remote (single SSH call for speed)
echo -e "${BLUE}🔧 Preparing remote...${NC}"

# Establish master connection and do all remote prep
WP_CLI_CHECK=$(ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "
    export LC_ALL=C LANG=C LANGUAGE=C TERM=xterm
    
    # Prepare directories
    mkdir -p '$REMOTE_PLUGINS_DIR'
    mkdir -p '$REMOTE_BACKUP_DIR'
    
    # Check WP-CLI
    if which wp >/dev/null 2>&1; then
        echo 'wp_available'
        # Deactivate plugin
        cd '$WP_PATH' && wp plugin deactivate '$PLUGIN_FOLDER' --allow-root >/dev/null 2>&1 || true
    else
        echo 'wp_not_found'
    fi
    
    # Handle existing remote folder
    if [ -d '$REMOTE_PLUGINS_DIR/$PLUGIN_FOLDER' ]; then
        # Create remote tar.gz backup first
        cd '$REMOTE_PLUGINS_DIR'
        tar -czf '$REMOTE_BACKUP_DIR/$PLUGIN_FOLDER.$PLUGIN_VERSION-$TIMESTAMP.tar.gz' '$PLUGIN_FOLDER'
        
        # Rename existing folder 
        if [ -d '$REMOTE_PLUGINS_DIR/$PLUGIN_FOLDER.$PLUGIN_VERSION' ]; then
            mv '$PLUGIN_FOLDER' '$PLUGIN_FOLDER.$PLUGIN_VERSION-$TIMESTAMP'
        else
            mv '$PLUGIN_FOLDER' '$PLUGIN_FOLDER.$PLUGIN_VERSION'
        fi
        echo 'backed_up_and_renamed'
    else
        echo 'no_existing'
    fi
" 2>/dev/null)

USE_WP_CLI=false
if [[ "$WP_CLI_CHECK" == *"wp_available"* ]]; then
    USE_WP_CLI=true
fi

# Wait for upload archive to be ready
wait $UPLOAD_PID
echo ""
echo -e "${CYAN}📤 Uploading...${NC}"
scp -i "$SSH_KEY" -P "$SSH_PORT" "$TEMP_TAR" "$SSH_USER@$SSH_HOST:/tmp/plugin-upload.tar.gz" 2>/dev/null && \
ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "cd '$REMOTE_PLUGINS_DIR' && tar -xzf /tmp/plugin-upload.tar.gz && rm /tmp/plugin-upload.tar.gz" 2>/dev/null

if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ Upload and extract failed${NC}"
    rm -f "$TEMP_TAR"
    exit 1
fi

# Reactivate plugin if WP-CLI available
echo ""
if [[ "$USE_WP_CLI" == true ]]; then
    echo -e "${PINK}🔌 Reactivating plugin...${NC}"
    ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "export LC_ALL=C LANG=C LANGUAGE=C TERM=xterm; cd '$WP_PATH' && wp plugin activate '$PLUGIN_FOLDER' --allow-root" >/dev/null 2>&1
fi
if [[ "$USE_WP_CLI" == true ]]; then
    echo -e "${GREEN}🔌 Plugin reactivated automatically${NC}"
else
    echo -e "${YELLOW}🔌 Plugin: ${WHITE}Manual activation required${NC}"
fi

# Wait for local backup to complete
wait $TARGZ_PID

# Cleanup
rm -f "$TEMP_TAR"

# Verify the deployment
echo ""
echo -e "${PURPLE}🔌 Verifying deployment...${NC}"
VERIFY_FILE=$(ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "test -f '$REMOTE_PLUGINS_DIR/$PLUGIN_FOLDER/$PLUGIN_FOLDER.php' && echo 'found' || echo 'not_found'" 2>/dev/null)

if [[ "$VERIFY_FILE" != "found" ]]; then
    echo -e "${RED}ERROR: Deployment verification failed${NC}"
    exit 1
fi

# Final verification
VERIFY=$(ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "find '$REMOTE_PLUGINS_DIR/$PLUGIN_FOLDER' -type f | wc -l" 2>/dev/null)
LOCAL_COUNT=$(find "$LOCAL_PLUGIN_DIR" -type f | wc -l)

echo ""
echo -e "${GREEN}---------------------------------------------------${NC}"
echo -e "${GREEN}🚀 Deployment successful!${NC}"
echo -e "${GREEN}---------------------------------------------------${NC}"
echo ""
echo -e "${CYAN}📦 Plugin Version:${NC} ${WHITE}$PLUGIN_VERSION${NC}"
echo -e "${PURPLE}📁 Files:${NC} ${WHITE}$VERIFY/$LOCAL_COUNT${NC}"
echo ""
echo -e "${GOLD}💾 Local Backup:${NC}"
echo -e "${GREY}   📦 tar.gz: $BACKUP_DIR/$TARGZ_NAME${NC}"

if [[ "$WP_CLI_CHECK" == *"backed_up_and_renamed"* ]]; then
    echo ""
    echo -e "${GOLD}💾 Remote Backups:${NC}"
    echo -e "${GREY}   📦 tar.gz: $REMOTE_BACKUP_DIR/$PLUGIN_FOLDER.$PLUGIN_VERSION-$TIMESTAMP.tar.gz${NC}"
    echo -e "${GREY}   📁 folder: $REMOTE_PLUGINS_DIR/$PLUGIN_FOLDER.$PLUGIN_VERSION*${NC}"
fi

echo ""
echo -e "${GREY}---------------------------------------------------${NC}"
if [[ "$AUTO_CLOSE" != true ]]; then
    echo "Press any key to continue..."
    read -n 1 -s
fi

exit 0
