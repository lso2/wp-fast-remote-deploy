#!/bin/bash

# WordPress Fast Deploy - Database Backup Script
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

# Colors for output
RED='\033[38;2;239;68;68m'
GREEN='\033[38;2;34;197;94m'
YELLOW='\033[1;33m'
GOLD='\033[38;2;251;191;36m'
BLUE='\033[38;2;59;130;246m'
PURPLE='\033[38;2;147;51;234m'
CYAN='\033[38;2;6;182;212m'
GREY='\033[38;2;107;114;128m'
WHITE='\033[38;2;255;255;255m'
NC='\033[0m'

# SSH connection settings
SSH_OPTS="-i $SSH_KEY -p $SSH_PORT -o ConnectTimeout=10 -o StrictHostKeyChecking=no"

echo ""
echo -e "${PURPLE}WordPress Database Backup${NC}"
echo -e "${GREY}Script v$VERSION${NC}"
echo ""

# Check if database backup is enabled
if [ "$DB_BACKUP_MODE" = "off" ]; then
    echo -e "${YELLOW}Database backup is disabled in config.sh${NC}"
    echo -e "${GREY}Set DB_BACKUP_MODE=\"manual\" or \"auto\" to enable database backups${NC}"
    echo ""
    echo -e "${BLUE}Available modes:${NC}"
    echo -e "${GREY}  \"off\"    = No database backups${NC}"
    echo -e "${GREY}  \"manual\" = Manual backup tools only${NC}"
    echo -e "${GREY}  \"auto\"   = Automatic backup during deployment${NC}"
    echo ""
    echo -e "${BLUE}Note: Database credentials will be read automatically from wp-config.php${NC}"
    echo -e "${GREY}Or use manual overrides in EXPERT SETTINGS section${NC}"
    exit 1
fi

echo -e "${CYAN}+ Project:${NC} ${WHITE}$FOLDER_NAME${NC}"

# Check if manual database overrides are configured
if [[ "$DB_OVERRIDE_ENABLED" = "true" && -n "$DB_NAME" && -n "$DB_USER" && -n "$DB_PASS" ]]; then
    echo -e "${CYAN}+ Database Source:${NC} ${YELLOW}Manual overrides (EXPERT mode)${NC}"
    echo -e "${CYAN}+ Database:${NC} ${GOLD}$DB_NAME${NC}"
    echo -e "${CYAN}+ Host:${NC} ${WHITE}${DB_HOST:-localhost}:${DB_PORT:-3306}${NC}"
else
    echo -e "${CYAN}+ Database Source:${NC} ${BLUE}wp-config.php (automatic)${NC}"
fi

echo ""

# Create timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="$FOLDER_NAME-manual-$TIMESTAMP.sql"

# Determine backup directory
if [ "$DB_PATH_ENABLED" = "true" ] && [ -n "$DB_PATH" ]; then
    DB_BACKUP_DIR="$DB_PATH"
    echo -e "${CYAN}+ Backup Location:${NC} ${WHITE}Custom path: $DB_BACKUP_DIR${NC}"
else
    DB_BACKUP_DIR="~/db_backups/$FOLDER_NAME"
    echo -e "${CYAN}+ Backup Location:${NC} ${WHITE}WordPress directory: $DB_BACKUP_DIR${NC}"
fi

echo ""
echo -e "${PURPLE}Creating database backup with mysqldump...${NC}"
echo "Note: Skipping connection test - some users have dump-only privileges"

# Execute mysqldump directly on remote server
BACKUP_RESULT=$(ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "
    export LC_ALL=C
    
    # Check for manual database overrides first
    if [ '$DB_OVERRIDE_ENABLED' = 'true' ] && [ -n '$DB_NAME' ] && [ -n '$DB_USER' ] && [ -n '$DB_PASS' ]; then
        DB_NAME='$DB_NAME'
        DB_USER='$DB_USER'
        DB_PASS='$DB_PASS'
        DB_HOST='$DB_HOST'
        DB_PORT='$DB_PORT'
        CONFIG_SOURCE='manual'
    else
        # Read database configuration from wp-config.php
        WP_CONFIG_PATH='$WP_PATH/wp-config.php'
        
        if [ ! -f \"\$WP_CONFIG_PATH\" ]; then
            echo 'wp_config_not_found'
            exit 1
        fi
        
        # Extract database configuration from wp-config.php
        DB_NAME=\$(grep \"define('DB_NAME'\" \"\$WP_CONFIG_PATH\" | cut -d\"'\" -f4)
        DB_USER=\$(grep \"define('DB_USER'\" \"\$WP_CONFIG_PATH\" | cut -d\"'\" -f4)
        DB_PASS=\$(grep \"define('DB_PASSWORD'\" \"\$WP_CONFIG_PATH\" | cut -d\"'\" -f4)
        DB_HOST=\$(grep \"define('DB_HOST'\" \"\$WP_CONFIG_PATH\" | cut -d\"'\" -f4)
        
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
        
        CONFIG_SOURCE='auto'
    fi
    
    echo \"db_config_found:\$DB_NAME:\$DB_USER:\$DB_HOST:\$DB_PORT:\$CONFIG_SOURCE\"
    
    # Create backup directory
    mkdir -p '$DB_BACKUP_DIR'
    
    # Check if directory was created successfully
    if [ ! -d '$DB_BACKUP_DIR' ]; then
        echo 'backup_dir_creation_failed'
        exit 1
    fi
    
    # Use exactly the same mysqldump format as your working manual command
    if mysqldump -u\"\$DB_USER\" -p\"\$DB_PASS\" --single-transaction --no-tablespaces \"\$DB_NAME\" > '$DB_BACKUP_DIR/$BACKUP_NAME' 2>/dev/null; then
        
        # Check if backup file was created and has content
        if [ -s '$DB_BACKUP_DIR/$BACKUP_NAME' ]; then
            # Get file size
            BACKUP_SIZE=\$(du -h '$DB_BACKUP_DIR/$BACKUP_NAME' | cut -f1)
            echo \"backup_created_successfully:\$BACKUP_SIZE\"
        else
            echo 'backup_file_empty'
            rm -f '$DB_BACKUP_DIR/$BACKUP_NAME'
            exit 1
        fi
    else
        echo 'mysqldump_failed'
        rm -f '$DB_BACKUP_DIR/$BACKUP_NAME'
        exit 1
    fi
" 2>&1)

SSH_EXIT_CODE=$?

# Parse the result
if [[ $SSH_EXIT_CODE -ne 0 ]]; then
    echo -e "${RED}❌ Database backup failed - SSH connection error${NC}"
    echo -e "${GREY}SSH Exit Code: $SSH_EXIT_CODE${NC}"
    if [[ -n "$BACKUP_RESULT" ]]; then
        echo -e "${GREY}Output: $BACKUP_RESULT${NC}"
    fi
    exit 1
elif [[ "$BACKUP_RESULT" == *"wp_config_not_found"* ]]; then
    echo -e "${RED}❌ wp-config.php not found${NC}"
    echo -e "${GREY}Expected location: $WP_PATH/wp-config.php${NC}"
    echo -e "${YELLOW}Please check your REMOTE_BASE path in config.sh${NC}"
    exit 1
elif [[ "$BACKUP_RESULT" == *"wp_config_parse_failed"* ]]; then
    echo -e "${RED}❌ Failed to parse database configuration from wp-config.php${NC}"
    echo -e "${YELLOW}Please ensure wp-config.php contains valid DB_NAME, DB_USER, and DB_PASSWORD definitions${NC}"
    exit 1
elif [[ "$BACKUP_RESULT" == *"backup_dir_creation_failed"* ]]; then
    echo -e "${RED}❌ Database backup failed - Cannot create backup directory${NC}"
    echo -e "${GREY}Attempted directory: $DB_BACKUP_DIR${NC}"
    exit 1
elif [[ "$BACKUP_RESULT" == *"mysqldump_failed"* ]]; then
    echo -e "${RED}❌ Database backup failed - mysqldump error${NC}"
    echo -e "${YELLOW}This server may not allow mysqldump access for this user${NC}"
    echo -e "${GREY}The user has backup privileges but mysqldump access may be restricted${NC}"
    exit 1
elif [[ "$BACKUP_RESULT" == *"backup_file_empty"* ]]; then
    echo -e "${RED}❌ Database backup failed - Backup file is empty${NC}"
    exit 1
elif [[ "$BACKUP_RESULT" == *"backup_created_successfully:"* ]]; then
    # Extract database config and backup size
    if [[ "$BACKUP_RESULT" == *"db_config_found:"* ]]; then
        DB_INFO=$(echo "$BACKUP_RESULT" | grep "db_config_found:" | cut -d':' -f2-6)
        DB_NAME_FOUND=$(echo "$DB_INFO" | cut -d':' -f1)
        DB_USER_FOUND=$(echo "$DB_INFO" | cut -d':' -f2) 
        DB_HOST_FOUND=$(echo "$DB_INFO" | cut -d':' -f3)
        DB_PORT_FOUND=$(echo "$DB_INFO" | cut -d':' -f4)
        CONFIG_SOURCE=$(echo "$DB_INFO" | cut -d':' -f5)
    fi
    
    BACKUP_SIZE=$(echo "$BACKUP_RESULT" | grep "backup_created_successfully:" | cut -d':' -f2)
    
    echo ""
    echo -e "${GREEN}---------------------------------------------------${NC}"
    echo -e "${GREEN}✅ Database backup created successfully!${NC}"
    echo -e "${GREEN}---------------------------------------------------${NC}"
    echo ""
    echo -e "${CYAN}+ Database:${NC} ${GOLD}${DB_NAME_FOUND:-'Unknown'}${NC}"
    echo -e "${CYAN}+ Host:${NC} ${WHITE}${DB_HOST_FOUND:-'Unknown'}:${DB_PORT_FOUND:-'3306'}${NC}"
    echo -e "${CYAN}+ User:${NC} ${WHITE}${DB_USER_FOUND:-'Unknown'}${NC}"
    echo -e "${CYAN}+ Backup File:${NC} ${WHITE}$BACKUP_NAME${NC}"
    echo -e "${CYAN}+ File Size:${NC} ${WHITE}$BACKUP_SIZE${NC}"
    echo -e "${CYAN}+ Location:${NC} ${WHITE}$DB_BACKUP_DIR${NC}"
    echo ""
    echo -e "${GREY}Full path: $DB_BACKUP_DIR/$BACKUP_NAME${NC}"
    
    if [[ "$CONFIG_SOURCE" == "manual" ]]; then
        echo -e "${YELLOW}🔧 Database configuration: Manual overrides (EXPERT mode)${NC}"
    else
        echo -e "${BLUE}✨ Database configuration: Read automatically from wp-config.php${NC}"
    fi
    
    echo ""
    echo -e "${GREY}---------------------------------------------------${NC}"
else
    echo -e "${RED}❌ Database backup failed - Unknown error${NC}"
    echo -e "${GREY}Result: $BACKUP_RESULT${NC}"
    exit 1
fi

exit 0
