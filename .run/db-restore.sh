#!/bin/bash

# WordPress Fast Deploy - Database Restore Script
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
SSH_OPTS="-i $SSH_KEY -p $SSH_PORT -o ControlMaster=auto -o ControlPath=/tmp/ssh-%r@%h:%p -o ControlPersist=30s -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no"

list_backups() {
    echo -e "${PURPLE}Available database backups for ${GOLD}$FOLDER_NAME${NC}:"
    echo -e "${GREY}====================================${NC}"
    
    # Check if database backup is enabled
    if [ "$DB_BACKUP_ENABLED" != "true" ]; then
        echo -e "${RED}Database backup is disabled in config.sh${NC}"
        echo -e "${GREY}Set DB_BACKUP_ENABLED=\"true\" to enable database operations${NC}"
        return 1
    fi
    
    # Determine backup directory
    if [ "$DB_PATH_ENABLED" = "true" ] && [ -n "$DB_PATH" ]; then
        DB_BACKUP_DIR="$DB_PATH"
    else
        DB_BACKUP_DIR="~/db_backups/$FOLDER_NAME"
    fi
    
    # List backups on remote server
    BACKUP_LIST=$(ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "
        export LC_ALL=C LANG=C LANGUAGE=C TERM=xterm
        
        if [ ! -d '$DB_BACKUP_DIR' ]; then
            echo 'no_backup_directory'
            exit 1
        fi
        
        cd '$DB_BACKUP_DIR'
        if ls *.sql >/dev/null 2>&1; then
            ls -la *.sql | awk '
            BEGIN { 
                print \"\\033[38;2;6;182;212mFilename                          | Date Created        | Size\\033[0m\"
                print \"\\033[38;2;107;114;128m--------------------------------- | ------------------- | --------\\033[0m\"
            }
            {
                if (\$9 ~ /\\.sql\$/) {
                    printf \"\\033[38;2;255;255;255m%-33s\\033[0m | \\033[38;2;107;114;128m%s %s %s\\033[0m | \\033[38;2;251;191;36m%s\\033[0m\\n\", 
                           \$9, \$6, \$7, \$8, \$5
                }
            }' | sort -k3 -r
        else
            echo 'no_sql_files'
        fi
    " 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Failed to connect to server${NC}"
        return 1
    elif [[ "$BACKUP_LIST" == "no_backup_directory" ]]; then
        echo -e "${RED}No backup directory found${NC}"
        echo -e "${GREY}Expected location: $DB_BACKUP_DIR${NC}"
        return 1
    elif [[ "$BACKUP_LIST" == "no_sql_files" ]]; then
        echo -e "${RED}No SQL backup files found${NC}"
        echo -e "${GREY}Location: $DB_BACKUP_DIR${NC}"
        return 1
    else
        echo "$BACKUP_LIST"
        echo ""
        echo -e "${GREY}Location: $DB_BACKUP_DIR${NC}"
        echo -e "${BLUE}✨ Database configuration will be read automatically from wp-config.php${NC}"
    fi
}

restore_database() {
    local backup_filename="$1"
    
    if [[ -z "$backup_filename" ]]; then
        echo -e "${RED}ERROR: No backup filename specified${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${PURPLE}WordPress Database Restore${NC}"
    echo -e "${GREY}Script v$VERSION${NC}"
    echo ""
    
    # Check if database backup is enabled
    if [ "$DB_BACKUP_ENABLED" != "true" ]; then
        echo -e "${RED}❌ Database backup is disabled in config.sh${NC}"
        echo -e "${YELLOW}Set DB_BACKUP_ENABLED=\"true\" to enable database operations${NC}"
        exit 1
    fi
    
    # Determine backup directory
    if [ "$DB_PATH_ENABLED" = "true" ] && [ -n "$DB_PATH" ]; then
        DB_BACKUP_DIR="$DB_PATH"
    else
        DB_BACKUP_DIR="~/db_backups/$FOLDER_NAME"
    fi
    
    echo -e "${CYAN}+ Project:${NC} ${WHITE}$FOLDER_NAME${NC}"
    echo -e "${CYAN}+ Backup File:${NC} ${WHITE}$backup_filename${NC}"
    echo -e "${CYAN}+ Reading database config from wp-config.php...${NC}"
    echo ""
    
    # Create a safety backup before restore
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    SAFETY_BACKUP="$FOLDER_NAME-pre-restore-$TIMESTAMP.sql"
    
    echo -e "${PURPLE}Reading wp-config.php and creating safety backup before restore...${NC}"
    
    RESTORE_RESULT=$(ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "
        export LC_ALL=C LANG=C LANGUAGE=C TERM=xterm
        
        # Check if backup file exists
        if [ ! -f '$DB_BACKUP_DIR/$backup_filename' ]; then
            echo 'backup_file_not_found'
            exit 1
        fi
        
        # Read database configuration from wp-config.php
        WP_CONFIG_PATH='$WP_PATH/wp-config.php'
        
        if [ ! -f \"\$WP_CONFIG_PATH\" ]; then
            echo 'wp_config_not_found'
            exit 1
        fi
        
        # Extract database configuration from wp-config.php
        DB_NAME=\$(grep -E \"define\\(.*'DB_NAME'\" \"\$WP_CONFIG_PATH\" | sed -E \"s/.*'DB_NAME'[^']*'([^']*)'.*/ /\" | tr -d ' ')
        DB_USER=\$(grep -E \"define\\(.*'DB_USER'\" \"\$WP_CONFIG_PATH\" | sed -E \"s/.*'DB_USER'[^']*'([^']*)'.*/ /\" | tr -d ' ')
        DB_PASS=\$(grep -E \"define\\(.*'DB_PASSWORD'\" \"\$WP_CONFIG_PATH\" | sed -E \"s/.*'DB_PASSWORD'[^']*'([^']*)'.*/ /\" | tr -d ' ')
        DB_HOST=\$(grep -E \"define\\(.*'DB_HOST'\" \"\$WP_CONFIG_PATH\" | sed -E \"s/.*'DB_HOST'[^']*'([^']*)'.*/ /\" | tr -d ' ')
        
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
        
        echo \"db_config_found:\$DB_NAME:\$DB_USER:\$DB_HOST:\$DB_PORT\"
        
        # Test database connection
        if ! mysql -h\"\$DB_HOST\" -P\"\$DB_PORT\" -u\"\$DB_USER\" -p\"\$DB_PASS\" -e 'SELECT 1;' \"\$DB_NAME\" >/dev/null 2>&1; then
            echo 'database_connection_failed'
            exit 1
        fi
        
        # Create safety backup
        if mysqldump -h\"\$DB_HOST\" -P\"\$DB_PORT\" -u\"\$DB_USER\" -p\"\$DB_PASS\" \\
            --single-transaction \\
            --routines \\
            --triggers \\
            --lock-tables=false \\
            \"\$DB_NAME\" > '$DB_BACKUP_DIR/$SAFETY_BACKUP' 2>/dev/null; then
            echo 'safety_backup_created'
        else
            echo 'safety_backup_failed'
            exit 1
        fi
        
        # Restore the database
        if mysql -h\"\$DB_HOST\" -P\"\$DB_PORT\" -u\"\$DB_USER\" -p\"\$DB_PASS\" \"\$DB_NAME\" < '$DB_BACKUP_DIR/$backup_filename' 2>/dev/null; then
            echo 'database_restore_successful'
        else
            echo 'database_restore_failed'
            exit 1
        fi
    " 2>/dev/null)
    
    # Parse the result
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Database restore failed - SSH connection error${NC}"
        exit 1
    elif [[ "$RESTORE_RESULT" == "backup_file_not_found" ]]; then
        echo -e "${RED}❌ Backup file not found: $backup_filename${NC}"
        echo -e "${GREY}Expected location: $DB_BACKUP_DIR/$backup_filename${NC}"
        echo ""
        echo -e "${YELLOW}Available backups:${NC}"
        list_backups
        exit 1
    elif [[ "$RESTORE_RESULT" == "wp_config_not_found" ]]; then
        echo -e "${RED}❌ wp-config.php not found${NC}"
        echo -e "${GREY}Expected location: $WP_PATH/wp-config.php${NC}"
        echo -e "${YELLOW}Please check your REMOTE_BASE path in config.sh${NC}"
        exit 1
    elif [[ "$RESTORE_RESULT" == "wp_config_parse_failed" ]]; then
        echo -e "${RED}❌ Failed to parse database configuration from wp-config.php${NC}"
        echo -e "${YELLOW}Please ensure wp-config.php contains valid DB_NAME, DB_USER, and DB_PASSWORD definitions${NC}"
        exit 1
    elif [[ "$RESTORE_RESULT" == "database_connection_failed" ]]; then
        # Extract database info for display
        if [[ "$RESTORE_RESULT" == *"db_config_found:"* ]]; then
            DB_INFO=$(echo "$RESTORE_RESULT" | grep "db_config_found:" | cut -d':' -f2-)
            DB_NAME_FOUND=$(echo "$DB_INFO" | cut -d':' -f1)
            DB_USER_FOUND=$(echo "$DB_INFO" | cut -d':' -f2)
            DB_HOST_FOUND=$(echo "$DB_INFO" | cut -d':' -f3)
            DB_PORT_FOUND=$(echo "$DB_INFO" | cut -d':' -f4)
            
            echo -e "${RED}❌ Database restore failed - Cannot connect to database${NC}"
            echo -e "${YELLOW}Database configuration read from wp-config.php:${NC}"
            echo -e "${GREY}  Database: $DB_NAME_FOUND${NC}"
            echo -e "${GREY}  User: $DB_USER_FOUND${NC}"
            echo -e "${GREY}  Host: $DB_HOST_FOUND:$DB_PORT_FOUND${NC}"
        else
            echo -e "${RED}❌ Database restore failed - Cannot connect to database${NC}"
        fi
        echo -e "${YELLOW}Please check database server status and credentials in wp-config.php${NC}"
        exit 1
    elif [[ "$RESTORE_RESULT" == "safety_backup_failed" ]]; then
        echo -e "${RED}❌ Database restore failed - Cannot create safety backup${NC}"
        echo -e "${YELLOW}Restore cancelled to prevent data loss${NC}"
        exit 1
    elif [[ "$RESTORE_RESULT" == "database_restore_failed" ]]; then
        echo -e "${RED}❌ Database restore failed - Error importing SQL file${NC}"
        echo -e "${YELLOW}Your original database is safe (safety backup created)${NC}"
        echo -e "${GREY}Safety backup: $SAFETY_BACKUP${NC}"
        exit 1
    elif [[ "$RESTORE_RESULT" == *"database_restore_successful"* ]]; then
        # Extract database config
        if [[ "$RESTORE_RESULT" == *"db_config_found:"* ]]; then
            DB_INFO=$(echo "$RESTORE_RESULT" | grep "db_config_found:" | cut -d':' -f2-6)
            DB_NAME_FOUND=$(echo "$DB_INFO" | cut -d':' -f1)
            DB_USER_FOUND=$(echo "$DB_INFO" | cut -d':' -f2) 
            DB_HOST_FOUND=$(echo "$DB_INFO" | cut -d':' -f3)
            DB_PORT_FOUND=$(echo "$DB_INFO" | cut -d':' -f4)
        fi
        
        echo ""
        echo -e "${GREEN}---------------------------------------------------${NC}"
        echo -e "${GREEN}✅ Database restore completed successfully!${NC}"
        echo -e "${GREEN}---------------------------------------------------${NC}"
        echo ""
        echo -e "${CYAN}+ Database:${NC} ${GOLD}${DB_NAME_FOUND:-'Unknown'}${NC}"
        echo -e "${CYAN}+ Host:${NC} ${WHITE}${DB_HOST_FOUND:-'Unknown'}:${DB_PORT_FOUND:-'3306'}${NC}"
        echo -e "${CYAN}+ User:${NC} ${WHITE}${DB_USER_FOUND:-'Unknown'}${NC}"
        echo -e "${CYAN}+ Restored from:${NC} ${WHITE}$backup_filename${NC}"
        echo -e "${CYAN}+ Safety backup:${NC} ${WHITE}$SAFETY_BACKUP${NC}"
        echo -e "${CYAN}+ Location:${NC} ${WHITE}$DB_BACKUP_DIR${NC}"
        echo ""
        echo -e "${BLUE}✨ Database configuration was read automatically from wp-config.php${NC}"
        echo -e "${YELLOW}⚠️  Important: Clear any caching plugins and check your site${NC}"
        echo ""
        echo -e "${GREY}---------------------------------------------------${NC}"
    else
        echo -e "${RED}❌ Database restore failed - Unknown error${NC}"
        echo -e "${GREY}Result: $RESTORE_RESULT${NC}"
        exit 1
    fi
}

case "$1" in
    "list")
        list_backups
        ;;
    "restore")
        restore_database "$2"
        ;;
    *)
        echo "Usage: $0 {list|restore FILENAME}"
        echo ""
        echo "Examples:"
        echo "  $0 list                                    # Show available backups"
        echo "  $0 restore mysite-manual-20240101-123456.sql  # Restore specific backup"
        exit 1
        ;;
esac
