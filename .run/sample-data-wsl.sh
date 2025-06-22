#!/bin/bash

# WordPress Fast Deploy - Sample Data Installer
# Created by: lso2 (https://github.com/lso2)
# Repository: https://github.com/lso2/wp-fast-remote-deploy
# License: GPLv3

# Colors for output - matching deploy-wsl.sh
RED='\033[38;2;239;68;68m'      # Clean red
GREEN='\033[38;2;34;197;94m'    # Clean green
YELLOW='\033[1;33m'             # Yellow
GOLD='\033[38;2;251;191;36m'    # Gold
BLUE='\033[38;2;59;130;246m'    # Clean blue
PURPLE='\033[38;2;147;51;234m'  # Clean purple
CYAN='\033[38;2;6;182;212m'     # Clean cyan
PINK='\033[38;2;236;72;153m'    # Clean pink
GREY='\033[38;2;107;114;128m'   # Muted grey
WHITE='\033[38;2;255;255;255m'  # Pure white
NC='\033[0m'                    # No Color

# Get arguments
SAMPLE_DATA_PATH="$1"
TARGET_DIR="$2"

echo ""
echo -e "${GREY}========================================${NC}"
echo -e "${WHITE}  WordPress Fast Deploy Sample Data${NC}"
echo -e "${GREY}========================================${NC}"
echo ""
echo -e "${PURPLE}This will install a sample WordPress project structure with:${NC}"
echo -e "${GREY}  - ${CYAN}my-project${GREY} folder${NC}"
echo -e "${GREY}  - ${CYAN}/plugins${GREY} directory with ${CYAN}my-plugin${NC}"
echo -e "${GREY}  - ${CYAN}/themes${GREY} directory with ${CYAN}my-theme${NC}"
echo -e "${GREY}  - Pre-configured ${PURPLE}wp-fast-remote-deploy${NC}"
echo -e "${GREY}  - Sample backups for testing rollback${NC}"
echo ""
echo -e "${CYAN}Installation directory:${NC} ${GOLD}$TARGET_DIR${NC}"
echo ""

# Check if sample data exists
if [ ! -f "$SAMPLE_DATA_PATH" ]; then
    echo -e "${RED}❌ Sample data not found at:${NC}"
    echo -e "${GREY}   $SAMPLE_DATA_PATH${NC}"
    exit 1
fi

# Check if my-project already exists
if [ -d "$TARGET_DIR/my-project" ]; then
    echo -e "${YELLOW}⚠️  Directory already exists:${NC} ${WHITE}$TARGET_DIR/my-project${NC}"
    echo ""
    echo -e "${YELLOW}Do you want to overwrite it? This will DELETE the existing directory!${NC}"
    echo -n "Continue? (y/N): "
    read -r confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${GREY}Installation cancelled.${NC}"
        exit 0
    fi
    
    echo ""
    echo -e "${BLUE}+  Removing existing directory...${NC}"
    rm -rf "$TARGET_DIR/my-project" 2>/dev/null || {
        echo -e "${RED}❌ Failed to remove existing directory${NC}"
        exit 1
    }
fi

# Extract sample data
echo ""
echo -e "${PURPLE}+  Extracting sample data...${NC}"

# Change to target directory
cd "$TARGET_DIR" || {
    echo -e "${RED}❌ Failed to change to target directory${NC}"
    exit 1
}

# Simple extraction - tar.gz file
echo -e "${BLUE}+  Unpacking files...${NC}"

# Create a temporary directory for extraction
TEMP_EXTRACT="$TARGET_DIR/.temp_extract_$"
mkdir -p "$TEMP_EXTRACT"

# Extract to temp directory first
cd "$TEMP_EXTRACT"
tar -xzf "$SAMPLE_DATA_PATH"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to extract sample data${NC}"
    rm -rf "$TEMP_EXTRACT"
    exit 1
fi

# Now check what we have and move appropriately
if [ -d "$TEMP_EXTRACT/my-project" ]; then
    # Perfect - it has my-project folder
    mv "$TEMP_EXTRACT/my-project" "$TARGET_DIR/"
elif [ -d "$TEMP_EXTRACT/my-projects" ]; then
    # It's my-projects with an 's' - rename it
    mv "$TEMP_EXTRACT/my-projects" "$TARGET_DIR/my-project"
else
    # Files were extracted directly - create my-project and move everything
    mkdir -p "$TARGET_DIR/my-project"
    mv "$TEMP_EXTRACT"/* "$TARGET_DIR/my-project/" 2>/dev/null || true
fi

# Clean up temp directory
rm -rf "$TEMP_EXTRACT"

# Go back to target directory
cd "$TARGET_DIR"

# Verify installation
if [ -d "$TARGET_DIR/my-project" ]; then
    MY_PROJECT_PATH="$TARGET_DIR/my-project"
    echo ""
    echo -e "${WHITE}========================================${NC}"
    echo -e "${GREEN}  Installation Successful!${NC}"
    echo -e "${WHITE}========================================${NC}"
    echo ""
    echo -e "${CYAN}Sample project installed at:${NC}"
    echo -e "${GOLD}$MY_PROJECT_PATH${NC}"
    echo ""
    echo -e "${PURPLE}Next steps:${NC}"
    echo -e "${WHITE}1. Navigate to:${NC} ${GOLD}$MY_PROJECT_PATH${NC}"
    echo -e "${WHITE}2. Edit${NC} ${PURPLE}config.sh${NC} ${WHITE}with your server details${NC}"
    echo -e "${WHITE}3. Set up SSH keys (see README)${NC}"
    echo -e "${WHITE}4. Install right-click menu (optional):${NC}"
    echo -e "${CYAN}   _scripts\_right-click-menu\install-auto-detect-folder-switcher.bat${NC}"
    echo -e "${WHITE}5. Right-click the folder to set it, in this case, ${GOLD}/plugins/my-plugin/ ${GREY}or ${GOLD}/themes/my-theme/${NC}"
    echo -e "${WHITE}6. Deploy using${NC} ${GREEN}deploy.bat${NC}"
    echo ""
    echo -e "${CYAN}The sample includes:${NC}"
    echo -e "${GREY}- ${GOLD}my-plugin${NC} ${GREY}(empty plugin structure)${NC}"
    echo -e "${GREY}- ${GOLD}my-theme${NC} ${GREY}(empty theme structure)${NC}"
    echo -e "${GREY}- Pre-configured deployment scripts${NC}"
    echo -e "${GREY}- Sample backups for testing rollback${NC}"
    echo ""
else
    echo ""
    echo -e "${RED}❌ Installation verification failed${NC}"
    echo -e "${GREY}Expected directory not found: $TARGET_DIR/my-project${NC}"
    exit 1
fi

echo -e "${GREY}========================================${NC}"
exit 0
