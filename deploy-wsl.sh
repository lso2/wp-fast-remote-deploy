#!/bin/bash

# Fast Deployment - Optimized for Speed
PLUGIN_NAME="your-plugin-name"
LOCAL_PLUGIN_DIR="/mnt/c/path/to/your/folder/$PLUGIN_NAME"
BACKUP_DIR="/mnt/c/path/to/your/backups"
AUTO_CLOSE=false

# SSH Configuration
SSH_HOST="your-server-ip"
SSH_PORT="22"
SSH_USER="username"
SSH_KEY="~/.ssh/id_rsa"
REMOTE_PLUGINS_DIR="/path/to/wp-content/plugins"
WP_PATH="/path/to/wordpress/root"

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
echo -e "${PINK}⚡  Deploy:${NC} ${GOLD}$PLUGIN_NAME${NC}"

# Extract version quickly (single grep)
VERSION=$(grep -m1 "Version:" "$LOCAL_PLUGIN_DIR/$PLUGIN_NAME.php" | sed 's/.*Version:[[:space:]]*\([0-9.]*\).*/\1/' | tr -d "\"' ")

if [[ -z "$VERSION" ]]; then
    echo -e "${RED}❌ No version found${NC}"
    exit 1
fi

echo -e "${PINK}📦 Version:${NC} ${WHITE}$VERSION${NC}"
echo ""

# Fast parallel backup operations
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%H%M%S)

{
    # Local folder backup (background)
    cd "$(dirname "$LOCAL_PLUGIN_DIR")"
    BACKUP_FOLDER_NAME="$PLUGIN_NAME.$VERSION-$TIMESTAMP"
    cp -r "$LOCAL_PLUGIN_DIR" "$BACKUP_DIR/$BACKUP_FOLDER_NAME" &
    BACKUP_PID=$!
    
    # Create tar.gz backup (background)
    TARGZ_NAME="$PLUGIN_NAME.$VERSION-$TIMESTAMP.tar.gz"
    tar -czf "$BACKUP_DIR/$TARGZ_NAME" "$(basename "$LOCAL_PLUGIN_DIR")" &
    TARGZ_PID=$!
    
    # Create upload archive (background)
    TEMP_TAR="/tmp/plugin-upload-$TIMESTAMP.tar.gz"
    tar -czf "$TEMP_TAR" "$(basename "$LOCAL_PLUGIN_DIR")" &
    UPLOAD_PID=$!
}

echo -e "${PURPLE}💾 Creating backups...${NC}"

# Check WP-CLI and prepare remote (single SSH call for speed)
echo -e "${BLUE}🔧 Preparing remote...${NC}"

# Establish master connection and do all remote prep
WP_CLI_CHECK=$(ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "
    export LC_ALL=C LANG=C LANGUAGE=C TERM=xterm
    
    # Prepare directory first
    mkdir -p '$REMOTE_PLUGINS_DIR'
    
    # Check WP-CLI
    if which wp >/dev/null 2>&1; then
        echo 'wp_available'
        # Deactivate plugin
        cd '$WP_PATH' && wp plugin deactivate '$PLUGIN_NAME' --allow-root >/dev/null 2>&1 || true
    else
        echo 'wp_not_found'
    fi
    
    # Rename existing folder if it exists
    if [ -d '$REMOTE_PLUGINS_DIR/$PLUGIN_NAME' ]; then
        if [ -d '$REMOTE_PLUGINS_DIR/$PLUGIN_NAME.$VERSION' ]; then
            mv '$REMOTE_PLUGINS_DIR/$PLUGIN_NAME' '$REMOTE_PLUGINS_DIR/$PLUGIN_NAME.$VERSION-$TIMESTAMP'
        else
            mv '$REMOTE_PLUGINS_DIR/$PLUGIN_NAME' '$REMOTE_PLUGINS_DIR/$PLUGIN_NAME.$VERSION'
        fi
        echo 'renamed'
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
    ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "export LC_ALL=C LANG=C LANGUAGE=C TERM=xterm; cd '$WP_PATH' && wp plugin activate '$PLUGIN_NAME' --allow-root" >/dev/null 2>&1
fi
if [[ "$USE_WP_CLI" == true ]]; then
    echo -e "${GREEN}🔌 Plugin reactivated automatically${NC}"
else
    echo -e "${YELLOW}🔌 Plugin: ${WHITE}Manual activation required${NC}"
fi

# Wait for local backups to complete
wait $BACKUP_PID $TARGZ_PID

# Cleanup
rm -f "$TEMP_TAR"

# Verify the deployment
echo ""
echo -e "${PURPLE}🔌 Verifying deployment...${NC}"
VERIFY_FILE=$(ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "test -f '$REMOTE_PLUGINS_DIR/$PLUGIN_NAME/$PLUGIN_NAME.php' && echo 'found' || echo 'not_found'" 2>/dev/null)

if [[ "$VERIFY_FILE" != "found" ]]; then
    echo -e "${RED}ERROR: Deployment verification failed${NC}"
    exit 1
fi

# Final verification
VERIFY=$(ssh -i "$SSH_KEY" -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "find '$REMOTE_PLUGINS_DIR/$PLUGIN_NAME' -type f | wc -l" 2>/dev/null)

LOCAL_COUNT=$(find "$LOCAL_PLUGIN_DIR" -type f | wc -l)

echo ""
echo -e "${GREEN}---------------------------------------------------${NC}"
echo -e "${GREEN}🚀 Deployment successful!${NC}"
echo -e "${GREEN}---------------------------------------------------${NC}"
echo ""
echo -e "${CYAN}📦 Version:${NC} ${WHITE}$VERSION${NC}"
echo -e "${PURPLE}📁 Files:${NC} ${WHITE}$VERIFY/$LOCAL_COUNT${NC}"
echo ""
echo -e "${GOLD}💾 Backups:${NC}"
echo -e "${GREY}   📁 folder: $BACKUP_DIR/$BACKUP_FOLDER_NAME${NC}"
echo -e "${GREY}   📦 tar.gz: $BACKUP_DIR/$TARGZ_NAME${NC}"
echo ""

echo -e "${GREY}---------------------------------------------------${NC}"
if [[ "$AUTO_CLOSE" != true ]]; then
    echo "Press any key to continue..."
    read -n 1 -s
fi

exit 0