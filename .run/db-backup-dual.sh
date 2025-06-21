#!/bin/bash

# WordPress Fast Deploy - Database Backup Script (Dual Method)
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

# Parse command line arguments
BACKUP_METHOD="auto"  # Default: auto-detect best method
while [[ $# -gt 0 ]]; do
    case $1 in
        --method)
            BACKUP_METHOD="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

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

# Determine backup method
if [[ "$BACKUP_METHOD" == "auto" ]]; then
    # Auto-detect: Try mysqldump method first, fall back to PHP if needed
    echo -e "${CYAN}+ Backup Method:${NC} ${WHITE}Auto-detect (will try mysqldump first)${NC}"
elif [[ "$BACKUP_METHOD" == "mysqldump" ]]; then
    echo -e "${CYAN}+ Backup Method:${NC} ${WHITE}mysqldump command (forced)${NC}"
elif [[ "$BACKUP_METHOD" == "php" ]]; then
    echo -e "${CYAN}+ Backup Method:${NC} ${WHITE}PHP mysqli (forced)${NC}"
else
    echo -e "${RED}❌ Invalid backup method: $BACKUP_METHOD${NC}"
    echo -e "${GREY}Valid methods: auto, mysqldump, php${NC}"
    exit 1
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

# Function to run mysqldump method
run_mysqldump_method() {
    echo -e "${PURPLE}Creating database backup using mysqldump method...${NC}"
    
    # Create PHP script on remote server
    PHP_SCRIPT_PATH="/tmp/db_backup_mysqldump_$TIMESTAMP.php"
    PHP_TEMPLATE="$SCRIPT_DIR/php-mysqldump-template.php"
    
    if [[ ! -f "$PHP_TEMPLATE" ]]; then
        return 1  # Template not found
    fi
    
    # Upload PHP backup script to server
    ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "cat > '$PHP_SCRIPT_PATH'" < "$PHP_TEMPLATE" 2>/dev/null
    
    if [[ $? -ne 0 ]]; then
        return 1  # Upload failed
    fi
    
    # Build parameters for PHP script
    if [[ "$DB_OVERRIDE_ENABLED" = "true" && -n "$DB_NAME" && -n "$DB_USER" && -n "$DB_PASS" ]]; then
        PHP_PARAMS="db_name=$DB_NAME&db_user=$DB_USER&db_pass=$DB_PASS&db_host=${DB_HOST:-localhost}&backup_dir=$DB_BACKUP_DIR&backup_file=$BACKUP_NAME"
    else
        PHP_PARAMS="wp_config=$WP_PATH/wp-config.php&backup_dir=$DB_BACKUP_DIR&backup_file=$BACKUP_NAME"
    fi
    
    # Execute PHP backup script on server
    BACKUP_RESULT=$(ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "cd '$WP_PATH' && php '$PHP_SCRIPT_PATH' '$PHP_PARAMS' 2>&1; echo \"PHP_EXIT_CODE:\$?\"" 2>&1)
    local SSH_EXIT_CODE=$?
    
    # Clean up PHP script
    ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "rm -f '$PHP_SCRIPT_PATH'" 2>/dev/null
    
    # Parse PHP exit code from output
    local PHP_EXIT_CODE=0
    if [[ "$BACKUP_RESULT" == *"PHP_EXIT_CODE:"* ]]; then
        PHP_EXIT_CODE=$(echo "$BACKUP_RESULT" | grep "PHP_EXIT_CODE:" | tail -1 | cut -d':' -f2)
        BACKUP_RESULT=$(echo "$BACKUP_RESULT" | sed '/PHP_EXIT_CODE:/d')
    fi
    
    if [[ $SSH_EXIT_CODE -ne 0 || $PHP_EXIT_CODE -ne 0 ]]; then
        return 1
    fi
    
    echo "$BACKUP_RESULT"
    return 0
}

# Function to run PHP mysqli method
run_php_method() {
    echo -e "${PURPLE}Creating database backup using PHP mysqli method...${NC}"
    
    # Create PHP backup script on remote server
    PHP_SCRIPT_PATH="/tmp/db_backup_php_$TIMESTAMP.php"
    PHP_TEMPLATE="$SCRIPT_DIR/php-backup-template.php"
    
    if [[ ! -f "$PHP_TEMPLATE" ]]; then
        return 1  # Template not found
    fi
    
    # Upload PHP backup script to server
    ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "cat > '$PHP_SCRIPT_PATH'" < "$PHP_TEMPLATE" 2>/dev/null
    
    if [[ $? -ne 0 ]]; then
        return 1  # Upload failed
    fi
    
    # Build parameters for PHP script
    if [[ "$DB_OVERRIDE_ENABLED" = "true" && -n "$DB_NAME" && -n "$DB_USER" && -n "$DB_PASS" ]]; then
        PHP_PARAMS="db_name=$DB_NAME&db_user=$DB_USER&db_pass=$DB_PASS&db_host=${DB_HOST:-localhost}&backup_dir=$DB_BACKUP_DIR&backup_file=$BACKUP_NAME"
    else
        PHP_PARAMS="wp_config=$WP_PATH/wp-config.php&backup_dir=$DB_BACKUP_DIR&backup_file=$BACKUP_NAME"
    fi
    
    # Execute PHP backup script on server
    BACKUP_RESULT=$(ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "cd '$WP_PATH' && php '$PHP_SCRIPT_PATH' '$PHP_PARAMS' 2>&1; echo \"PHP_EXIT_CODE:\$?\"" 2>&1)
    local SSH_EXIT_CODE=$?
    
    # Clean up PHP script
    ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "rm -f '$PHP_SCRIPT_PATH'" 2>/dev/null
    
    # Parse PHP exit code from output
    local PHP_EXIT_CODE=0
    if [[ "$BACKUP_RESULT" == *"PHP_EXIT_CODE:"* ]]; then
        PHP_EXIT_CODE=$(echo "$BACKUP_RESULT" | grep "PHP_EXIT_CODE:" | tail -1 | cut -d':' -f2)
        BACKUP_RESULT=$(echo "$BACKUP_RESULT" | sed '/PHP_EXIT_CODE:/d')
    fi
    
    if [[ $SSH_EXIT_CODE -ne 0 || $PHP_EXIT_CODE -ne 0 ]]; then
        return 1
    fi
    
    echo "$BACKUP_RESULT"
    return 0
}

# Execute backup based on method
BACKUP_SUCCESS=false
BACKUP_RESULT=""

if [[ "$BACKUP_METHOD" == "auto" ]]; then
    # Try mysqldump first
    if BACKUP_RESULT=$(run_mysqldump_method); then
        BACKUP_SUCCESS=true
        USED_METHOD="mysqldump"
    else
        echo -e "${YELLOW}mysqldump method failed, trying PHP mysqli method...${NC}"
        echo ""
        if BACKUP_RESULT=$(run_php_method); then
            BACKUP_SUCCESS=true
            USED_METHOD="php"
        fi
    fi
elif [[ "$BACKUP_METHOD" == "mysqldump" ]]; then
    if BACKUP_RESULT=$(run_mysqldump_method); then
        BACKUP_SUCCESS=true
        USED_METHOD="mysqldump"
    fi
elif [[ "$BACKUP_METHOD" == "php" ]]; then
    if BACKUP_RESULT=$(run_php_method); then
        BACKUP_SUCCESS=true
        USED_METHOD="php"
    fi
fi

# Parse and display results
if [[ "$BACKUP_SUCCESS" != "true" ]]; then
    echo -e "${RED}❌ Database backup failed${NC}"
    if [[ -n "$BACKUP_RESULT" ]]; then
        echo -e "${GREY}Error output:${NC}"
        echo "$BACKUP_RESULT"
    fi
    exit 1
fi

# Process successful result
if [[ "$BACKUP_RESULT" == *"wp_config_not_found"* ]]; then
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
elif [[ "$BACKUP_RESULT" == *"database_connection_failed:"* ]]; then
    echo -e "${RED}❌ Database backup failed - Connection error${NC}"
    echo -e "${GREY}Error details:${NC}"
    echo "$BACKUP_RESULT" | grep -E "(Socket|Localhost|127.0.0.1|error):" | while read line; do
        echo -e "${GREY}  $line${NC}"
    done
    exit 1
elif [[ "$BACKUP_RESULT" == *"mysqldump_failed:"* ]]; then
    echo -e "${RED}❌ Database backup failed - mysqldump error${NC}"
    echo -e "${GREY}Error details:${NC}"
    echo "$BACKUP_RESULT" | grep -E "(mysqldump_|system_)" | while read line; do
        echo -e "${GREY}  $line${NC}"
    done
    exit 1
elif [[ "$BACKUP_RESULT" == *"php_backup_error:"* ]]; then
    PHP_ERROR=$(echo "$BACKUP_RESULT" | grep "php_backup_error:" | cut -d':' -f2-)
    echo -e "${RED}❌ Database backup failed - PHP error${NC}"
    echo -e "${GREY}PHP Error: $PHP_ERROR${NC}"
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
    
    # Extract connection method if available
    CONNECTION_METHOD=""
    if [[ "$BACKUP_RESULT" == *"Connection successful via:"* ]]; then
        CONNECTION_METHOD=$(echo "$BACKUP_RESULT" | grep "Connection successful via:" | cut -d':' -f2 | tr -d ' ')
    fi
    
    BACKUP_SIZE=$(echo "$BACKUP_RESULT" | grep "backup_created_successfully:" | cut -d':' -f2)
    
    echo ""
    echo -e "${GREEN}---------------------------------------------------${NC}"
    echo -e "${GREEN}✅ Database backup created successfully!${NC}"
    echo -e "${GREEN}---------------------------------------------------${NC}"
    echo ""
    echo -e "${CYAN}+ Database:${NC} ${GOLD}${DB_NAME_FOUND:-'Unknown'}${NC}"
    echo -e "${CYAN}+ Host:${NC} ${WHITE}${DB_HOST_FOUND:-'Unknown'}:${DB_PORT_FOUND:-'3306'}${NC}"
    if [[ -n "$CONNECTION_METHOD" ]]; then
        echo -e "${CYAN}+ Connection:${NC} ${WHITE}$CONNECTION_METHOD${NC}"
    fi
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
    
    if [[ "$USED_METHOD" == "mysqldump" ]]; then
        echo -e "${PURPLE}💡 Method: mysqldump command (native backup)${NC}"
    else
        echo -e "${PURPLE}💡 Method: PHP mysqli (table-by-table backup)${NC}"
    fi
    
    echo ""
    echo -e "${GREY}---------------------------------------------------${NC}"
else
    echo -e "${RED}❌ Database backup failed - Unknown error${NC}"
    echo -e "${GREY}Result: $BACKUP_RESULT${NC}"
    exit 1
fi

exit 0
