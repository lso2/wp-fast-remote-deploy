#!/bin/bash

# WordPress Fast Deploy - Rollback Script
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

# Build backup directory path using the same method as deployment
# This ensures both plugins and themes work exactly the same way
PROJECT_ROOT="$SCRIPT_DIR/.."
BACKUP_SUBFOLDER="${PREFIX}${TYPE}_${LOCAL_BAK_SUFFIX}"
LOCAL_BACKUP_DIR="$PROJECT_ROOT/$BACKUP_SUBFOLDER/backups_$FOLDER_NAME"

# Set variables that depend on config
TEMP_MAPPING="/tmp/rollback_mapping_${FOLDER_NAME}"
LOCAL_PROJECT_DIR="$PROJECT_ROOT/$FOLDER_NAME"

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

get_local_version() {
    local version=""
    if [[ "$TYPE" == "theme" ]]; then
        if [[ -f "$LOCAL_PROJECT_DIR/style.css" ]]; then
            version=$(grep -i "Version:" "$LOCAL_PROJECT_DIR/style.css" | head -1 | grep -o '[0-9]\+\.[0-9]\+\.*[0-9]*' | head -1)
        fi
    else
        if [[ -f "$LOCAL_PROJECT_DIR/$FOLDER_NAME.php" ]]; then
            version=$(grep -i "Version:" "$LOCAL_PROJECT_DIR/$FOLDER_NAME.php" | head -1 | grep -o '[0-9]\+\.[0-9]\+\.*[0-9]*' | head -1)
        fi
    fi
    
    if [[ -z "$version" ]]; then
        version="unknown"
    fi
    echo "$version"
}

create_local_safety_backup() {
    local current_version="$1"
    local timestamp=$(date +%H%M%S)
    local safety_backup="$FOLDER_NAME.$current_version-safety-local-$timestamp.tar.gz"
    
    if [[ -d "$LOCAL_PROJECT_DIR" ]]; then
        cd "$PROJECT_ROOT"
        mkdir -p "$LOCAL_BACKUP_DIR"
        
        if tar -czf "$LOCAL_BACKUP_DIR/$safety_backup" "$FOLDER_NAME" 2>/dev/null; then
            echo "$safety_backup"
        else
            echo ""
        fi
    else
        echo ""
    fi
}

list_backups() {
    echo -e "${GREY}====================================${NC}"
    echo -e "${WHITE}  WordPress Fast Deploy - Rollback${NC}"
    echo -e "${GREY}====================================${NC}"
    echo ""
    echo -e "${PURPLE}Restores selected backup directly to your live WordPress site.${NC}"
    if [[ "$ROLLBACK_SYNC_LOCAL" == "true" ]]; then
        echo -e "${GREY}Safety backups of both local and remote versions will be created first.${NC}"
    else
        echo -e "${GREY}A safety backup of your remote version will be created first.${NC}"
        echo -e "${YELLOW}Note: Local files will NOT be changed (remote-only rollback mode).${NC}"
    fi
    
    # Show current versions in compact format
    LOCAL_CURRENT_VERSION=$(get_local_version)
    echo -ne "${CYAN}Current Versions:${NC} ${GREY}Local: ${WHITE}$LOCAL_CURRENT_VERSION${NC}  ${GREY}|  Remote: ${WHITE}Checking...${NC}"
    
    # Get current remote version with inline update
    REMOTE_CURRENT_VERSION="unknown"
    REMOTE_CHECK=$(ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "
        export LC_ALL=C LANG=C LANGUAGE=C TERM=xterm
        
        if [ -d '$REMOTE_TARGET_DIR/$FOLDER_NAME' ]; then
            if [ '$TYPE' = 'theme' ]; then
                REMOTE_VERSION=\$(grep -i version '$REMOTE_TARGET_DIR/$FOLDER_NAME/style.css' | head -1 | grep -o '[0-9]\+\.[0-9]\+\.*[0-9]*' | head -1)
            else
                REMOTE_VERSION=\$(grep -i version '$REMOTE_TARGET_DIR/$FOLDER_NAME/$FOLDER_NAME.php' | head -1 | grep -o '[0-9]\+\.[0-9]\+\.*[0-9]*' | head -1)
            fi
            if [ -z \"\$REMOTE_VERSION\" ]; then
                REMOTE_VERSION=unknown
            fi
            echo \"\$REMOTE_VERSION\"
        else
            echo \"not installed\"
        fi
    " 2>/dev/null)
    
    if [[ -n "$REMOTE_CHECK" ]]; then
        REMOTE_CURRENT_VERSION="$REMOTE_CHECK"
    fi
    
    # Clear the "Checking..." and replace with actual version
    echo -e "\r${CYAN}Current Versions:${NC} ${GREY}Local: ${WHITE}$LOCAL_CURRENT_VERSION${NC}  ${GREY}|  Remote: ${WHITE}$REMOTE_CURRENT_VERSION${NC}                    "
    
    echo ""
    echo -e "${PURPLE}   Available backup versions for ${GOLD}$FOLDER_NAME${NC} (${TYPE}s):"
    echo -e "${GREY}   ========================================${NC}"
    
    if [ ! -d "$LOCAL_BACKUP_DIR" ]; then
        echo -e "${RED}No backups found for $FOLDER_NAME${NC}"
        echo -e "${GREY}Backup directory: $LOCAL_BACKUP_DIR${NC}"
        return 1
    fi
    
    cd "$LOCAL_BACKUP_DIR"
    
    # List available backups with details
    if ls *.tar.gz >/dev/null 2>&1; then
        # Clear the mapping file
        > "$TEMP_MAPPING"
        
        # Print header first
        echo -e "${CYAN}   |  #  | Version      | Date Created        | Size     | Filename${NC}"
        echo -e "${GREY}   | --- | ------------ | ------------------- | -------- | ------------------${NC}"
        
        # Process and sort data only
        ls -la *.tar.gz 2>/dev/null | awk -v folder="$FOLDER_NAME" -v mapping="$TEMP_MAPPING" '
        function human_size(bytes) {
			if (bytes >= 1073741824) {
				return sprintf("%.1f\033[38;2;107;114;128m GB\033[0m    ", bytes/1073741824)
			} else if (bytes >= 1048576) {
				return sprintf("%.1f\033[38;2;107;114;128m MB\033[0m    ", bytes/1048576)
			} else if (bytes >= 1024) {
				return sprintf("%.1f\033[38;2;107;114;128m KB\033[0m    ", bytes/1024)
			} else {
				return sprintf("%d\033[38;2;107;114;128m B\033[0m   ", bytes)
			}
		}
        {
            if ($9 ~ /\.tar\.gz$/) {
                # Skip safety backups in the main list
                if ($9 ~ /-safety-(local|remote)-/) {
                    next
                }
                
                # Extract version from filename (folder.version-timestamp.tar.gz)
                filename = $9
                gsub(/\.tar\.gz$/, "", filename)
                
                # Split by dots and dashes to get version
                if (match(filename, folder "\\." "([0-9]+\\.[0-9]+\\.?[0-9]*)", version_match)) {
                    version = version_match[1]
                } else if (match(filename, folder "\\." "([0-9]+\\.[0-9]+)", version_match)) {
                    version = version_match[1]
                } else {
                    version = "unknown"
                }
                
                # Format date with fixed width
                date_created = sprintf("%-19s", $6 " " $7 " " $8)
                
                # Convert size to human readable with proper padding
                size_human = human_size($5)
                
                # Store for sorting with version as key for date sorting
                lines[NR] = sprintf("%s|%s|%s|%s", version, date_created, size_human, $9)
            }
        }
        END {
            # Sort by date (reverse chronological)
            n = asorti(lines, sorted_indices)
            for (i = n; i >= 1; i--) {
                split(lines[sorted_indices[i]], parts, "|")
                version = parts[1]
                date_created = parts[2] 
                size = parts[3]
                filename = parts[4]
                
                # Assign number (newest first)
                num = n - i + 1
                
                # Save mapping to file (number -> version)
                print num ":" version >> mapping
                
                # Format the output with proper alignment
                printf "   | \033[38;2;6;182;212m%2s\033[0m  | \033[38;2;255;255;255m%-12s\033[0m | \033[38;2;107;114;128m%s\033[0m | \033[38;2;251;191;36m%-8s\033[0m | \033[38;2;147;51;234m%s\033[0m\n",  
                       num, version, date_created, size, filename
            }
        }'
    else
        echo -e "${RED}No backup files found in $LOCAL_BACKUP_DIR${NC}"
        return 1
    fi
}

deploy_rollback() {
    local target_input="$1"
    local target_version=""
    
    if [[ -z "$target_input" ]]; then
        echo -e "${RED}ERROR: No version specified for rollback${NC}"
        return 1
    fi
    
    # Check if input is a number (from the list)
    if [[ "$target_input" =~ ^[0-9]+$ ]]; then
        # Always regenerate mapping to ensure it exists and is current
        echo -e "${GOLD}Generating backup list...${NC}"
        cd "$LOCAL_BACKUP_DIR" 2>/dev/null || {
            echo -e "${RED}ERROR: Local backup directory not found: $LOCAL_BACKUP_DIR${NC}"
            return 1
        }
        
        # Clear and regenerate mapping
        > "$TEMP_MAPPING"
        
        if ls *.tar.gz >/dev/null 2>&1; then
            ls -la *.tar.gz 2>/dev/null | awk -v folder="$FOLDER_NAME" -v mapping="$TEMP_MAPPING" '
            {
                if ($9 ~ /\.tar\.gz$/) {
                    # Skip safety backups
                    if ($9 ~ /-safety-(local|remote)-/) {
                        next
                    }
                    
                    filename = $9
                    gsub(/\.tar\.gz$/, "", filename)
                    
                    if (match(filename, folder "\\." "([0-9]+\\.[0-9]+\\.?[0-9]*)", version_match)) {
                        version = version_match[1]
                    } else if (match(filename, folder "\\." "([0-9]+\\.[0-9]+)", version_match)) {
                        version = version_match[1]
                    } else {
                        version = "unknown"
                    }
                    
                    lines[NR] = sprintf("%s|%s", version, $9)
                }
            }
            END {
                n = asorti(lines, sorted_indices)
                for (i = n; i >= 1; i--) {
                    split(lines[sorted_indices[i]], parts, "|")
                    version = parts[1]
                    num = n - i + 1
                    print num ":" version >> mapping
                }
            }'
        fi
        
        # Look up version from mapping file
        if [[ -f "$TEMP_MAPPING" ]]; then
            target_version=$(grep "^$target_input:" "$TEMP_MAPPING" | cut -d: -f2)
            if [[ -z "$target_version" ]]; then
                echo -e "${RED}ERROR: Invalid selection number: $target_input${NC}"
                echo ""
                echo -e "${YELLOW}Available versions:${NC}"
                list_backups
                return 1
            fi
        else
            echo -e "${RED}ERROR: Failed to generate backup list${NC}"
            return 1
        fi
    else
        # Input is a version number directly
        target_version="$target_input"
    fi
    
    # Find the backup file for this version
    local backup_file=""
    local full_backup_path=""
    if [ -d "$LOCAL_BACKUP_DIR" ]; then
        cd "$LOCAL_BACKUP_DIR"
        backup_file=$(ls "$FOLDER_NAME.$target_version"*.tar.gz 2>/dev/null | grep -v "safety" | head -1)
        if [[ -n "$backup_file" ]]; then
            full_backup_path="$LOCAL_BACKUP_DIR/$backup_file"
        fi
    fi
    
    if [[ -z "$backup_file" || ! -f "$full_backup_path" ]]; then
        echo -e "${RED}+  ERROR: Backup file not found for version $target_version${NC}"
        echo -e "${GREY}+  Looking for: $FOLDER_NAME.$target_version*.tar.gz in $LOCAL_BACKUP_DIR${NC}"
        echo ""
        echo -e "${YELLOW}+  Available versions:${NC}"
        list_backups
        return 1
    fi
    
	echo -e " "
    echo -e "${PURPLE}+  Rolling back $FOLDER_NAME to version $target_version...${NC}"
    echo -e "${GREY}+  Backup file: $backup_file${NC}"
    
    # Create local safety backup if sync is enabled
    LOCAL_CURRENT_VERSION=""
    LOCAL_SAFETY_BACKUP=""
    if [[ "$ROLLBACK_SYNC_LOCAL" == "true" ]]; then
        echo -e " "
        echo "+  Creating local safety backup..."
        LOCAL_CURRENT_VERSION=$(get_local_version)
        LOCAL_SAFETY_BACKUP=$(create_local_safety_backup "$LOCAL_CURRENT_VERSION")
        
        if [[ -n "$LOCAL_SAFETY_BACKUP" ]]; then
            echo -e "${GREEN}+  Local safety backup created: $LOCAL_SAFETY_BACKUP${NC}"
            echo -e "${GREY}+  Current local version: $LOCAL_CURRENT_VERSION${NC}"
        else
            echo -e "${YELLOW}+  Warning: Could not create local safety backup${NC}"
        fi
    fi
    
    # Get current remote version and create safety backup
	echo -e " "
    echo "+  Detecting current remote version and creating remote safety backup..."
    
    REMOTE_CHECK=$(ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "
        export LC_ALL=C LANG=C LANGUAGE=C TERM=xterm
        
        # Check if folder exists and get current version
        if [ -d '$REMOTE_TARGET_DIR/$FOLDER_NAME' ]; then
            # Get current remote version based on type
            if [ '$TYPE' = 'theme' ]; then
                REMOTE_VERSION=\$(grep -i version '$REMOTE_TARGET_DIR/$FOLDER_NAME/style.css' | head -1 | grep -o '[0-9]\+\.[0-9]\+\.*[0-9]*' | head -1)
            else
                REMOTE_VERSION=\$(grep -i version '$REMOTE_TARGET_DIR/$FOLDER_NAME/$FOLDER_NAME.php' | head -1 | grep -o '[0-9]\+\.[0-9]\+\.*[0-9]*' | head -1)
            fi
            if [ -z \"\$REMOTE_VERSION\" ]; then
                REMOTE_VERSION=unknown
            fi
            
            # Create safety backup with proper version naming
            SAFETY_BACKUP=\"$FOLDER_NAME.\$REMOTE_VERSION-safety-remote-$(date +%H%M%S).tar.gz\"
            mkdir -p '$REMOTE_BACKUP_DIR'
            tar -czf \"$REMOTE_BACKUP_DIR/\$SAFETY_BACKUP\" -C '$REMOTE_TARGET_DIR' '$FOLDER_NAME' 2>/dev/null
            
            if [ \$? -eq 0 ]; then
                echo \"safety_backup_created:\$REMOTE_VERSION:\$SAFETY_BACKUP\"
            else
                echo \"safety_backup_failed:\$REMOTE_VERSION:\"
            fi
        else
            echo \"no_existing_installation\"
        fi
    " 2>/dev/null)
    
    # Extract remote version info
    CURRENT_REMOTE_VERSION="unknown"
    REMOTE_SAFETY_BACKUP_STATUS="failed"
    if [[ "$REMOTE_CHECK" == *"safety_backup_created:"* ]]; then
        CURRENT_REMOTE_VERSION=$(echo "$REMOTE_CHECK" | grep -o "safety_backup_created:[^:]*" | cut -d':' -f2)
        REMOTE_SAFETY_BACKUP_NAME=$(echo "$REMOTE_CHECK" | grep -o "safety_backup_created:.*" | cut -d':' -f3)
        echo -e "${GREEN}+  Remote safety backup created: $REMOTE_SAFETY_BACKUP_NAME${NC}"
        echo -e "${GREY}+  Current remote version: $CURRENT_REMOTE_VERSION${NC}"
        REMOTE_SAFETY_BACKUP_STATUS="success"
    elif [[ "$REMOTE_CHECK" == *"safety_backup_failed:"* ]]; then
        CURRENT_REMOTE_VERSION=$(echo "$REMOTE_CHECK" | grep -o "safety_backup_failed:[^:]*" | cut -d':' -f2)
        echo -e "${YELLOW}+  Warning: Could not create remote safety backup${NC}"
        echo -e "${GREY}+  Current remote version: $CURRENT_REMOTE_VERSION${NC}"
    elif [[ "$REMOTE_CHECK" == *"no_existing_installation"* ]]; then
        echo -e "${YELLOW}+  No existing remote installation found${NC}"
        CURRENT_REMOTE_VERSION="none"
    fi
    
    # Confirmation with version details
    echo ""
    echo -e "${CYAN}Rollback Summary:${NC}"
    if [[ "$ROLLBACK_SYNC_LOCAL" == "true" ]]; then
        echo -e "${GREY}  Current local version:  $LOCAL_CURRENT_VERSION${NC}"
        echo -e "${GREY}  Current remote version: $CURRENT_REMOTE_VERSION${NC}"
        echo -e "${GREY}  Target version:         $target_version${NC}"
        # echo -e "${GREY}  Local safety backup:    $([ -n "$LOCAL_SAFETY_BACKUP" ] && echo "created" || echo "failed")${NC}"
        # echo -e "${GREY}  Remote safety backup:   $REMOTE_SAFETY_BACKUP_STATUS${NC}"
    else
        echo -e "${GREY}  Current remote version: $CURRENT_REMOTE_VERSION${NC}"
        echo -e "${GREY}  Target version:         $target_version${NC}"
        echo -e "${GREY}  Remote safety backup:   $REMOTE_SAFETY_BACKUP_STATUS${NC}"
        echo -e "${YELLOW}  Local files:           will NOT be changed${NC}"
    fi
    echo ""
    
    # Upload the rollback version
    echo -e "${BLUE}+  Uploading rollback version...${NC}"
    TEMP_ROLLBACK="/tmp/$FOLDER_NAME-rollback-$TIMESTAMP.tar.gz"
    
    scp -P $SSH_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$full_backup_path" "$SSH_USER@$SSH_HOST:$TEMP_ROLLBACK" 2>/dev/null
    upload_result=$?
    
    if [[ $upload_result -ne 0 ]]; then
        echo -e "${RED}+  ❌ Failed to upload rollback backup${NC}"
        return 1
    fi
    
    echo -e "${GREEN}+  Rollback backup uploaded successfully${NC}"
    
    # Deploy the rollback on remote
    echo -e " "
	echo -ne "${CYAN}+  Deploying rollback version to remote...${NC}"
    
    ROLLBACK_RESULT=$(ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "
        export LC_ALL=C LANG=C LANGUAGE=C TERM=dumb PERL_BADLANG=0
        
        # Check WP-CLI availability and deactivate if plugin
        USE_WP_CLI=false
        if [ '$SKIP_WP_CLI' != 'true' ] && which wp >/dev/null 2>&1; then
            USE_WP_CLI=true
            if [ '$TYPE' = 'plugin' ]; then
                cd '$WP_PATH' && wp plugin deactivate '$FOLDER_NAME' --allow-root >/dev/null 2>&1 || true
            fi
        fi
        
        # Remove current version and extract rollback
        cd '$REMOTE_TARGET_DIR' || exit 1
        
        if [ -d '$FOLDER_NAME' ]; then
            rm -rf '$FOLDER_NAME.rollback-temp' 2>/dev/null || true
            mv '$FOLDER_NAME' '$FOLDER_NAME.rollback-temp' || exit 1
        fi
        
        # Extract the rollback version
        tar -xzf '$TEMP_ROLLBACK' || exit 1
        
        # Clean up temp file and old folder
        rm -f '$TEMP_ROLLBACK'
        rm -rf '$FOLDER_NAME.rollback-temp' 2>/dev/null || true
        
        # Try to reactivate if plugin and WP-CLI available
        if [ \$USE_WP_CLI = true ] && [ '$TYPE' = 'plugin' ]; then
            cd '$WP_PATH' && wp plugin activate '$FOLDER_NAME' --allow-root >/dev/null 2>&1 || echo 'Manual activation required'
        fi
        
        echo 'Rollback deployed successfully'
    " 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}+  FAILED!${NC}"
        echo -e "${GREY}+  $ROLLBACK_RESULT${NC}"
        return 1
    fi
    
    echo -e "  ${GREEN}SUCCESS!${NC}"
    
    # Deploy rollback to local if sync is enabled
    if [[ "$ROLLBACK_SYNC_LOCAL" == "true" ]]; then
        echo -ne "${CYAN}+  Deploying rollback version to local...${NC}"
        
        # Extract rollback to local directory
        cd "$PROJECT_ROOT"
        
        # Remove current local version and extract rollback
        if [[ -d "$FOLDER_NAME" ]]; then
            rm -rf "$FOLDER_NAME.rollback-temp" 2>/dev/null || true
            mv "$FOLDER_NAME" "$FOLDER_NAME.rollback-temp" || {
                echo -e "${RED}+  ❌ Failed to backup current local version${NC}"
                return 1
            }
        fi
        
        # Extract the rollback version locally
        if tar -xzf "$full_backup_path" 2>/dev/null; then
            # Clean up old folder
            rm -rf "$FOLDER_NAME.rollback-temp" 2>/dev/null || true
            echo -e "   ${GREEN}SUCCESS!${NC}"
        else
            # Restore original if extraction failed
            if [[ -d "$FOLDER_NAME.rollback-temp" ]]; then
                mv "$FOLDER_NAME.rollback-temp" "$FOLDER_NAME"
            fi
            echo -e "   ${RED}FAILED!${NC}"
            return 1
        fi
    fi
    
    # Final success message    
    if [[ "$ROLLBACK_SYNC_LOCAL" == "true" ]]; then
        echo -e "${PURPLE}+  Both local and remote successfully rolled back from version $CURRENT_REMOTE_VERSION to $target_version${NC}"
		echo ""
        echo -e "${GOLD}+  Local and remote are now synchronized on version $target_version${NC}"
        if [[ -n "$LOCAL_SAFETY_BACKUP" ]]; then
            echo -e "${GREY}+  Local safety backup: $LOCAL_SAFETY_BACKUP${NC}"
        fi
        if [[ "$REMOTE_SAFETY_BACKUP_STATUS" == "success" ]]; then
            echo -e "${GREY}+  Remote safety backup: $REMOTE_SAFETY_BACKUP_NAME${NC}"
        fi
    else
        echo -e " "
        echo -e "${PURPLE}+  Remote rolled back from version $CURRENT_REMOTE_VERSION to $target_version${NC}"
        echo -e "${YELLOW}+  WARNING: Local files still contain version $LOCAL_CURRENT_VERSION while remote now runs version $target_version${NC}"
        echo -e "${YELLOW}+   Next deployment will overwrite the rollback unless you manually sync local files.${NC}"
        if [[ "$REMOTE_SAFETY_BACKUP_STATUS" == "success" ]]; then
            echo -e "${GREY}+  Remote safety backup: $REMOTE_SAFETY_BACKUP_NAME${NC}"
        fi
    fi
    
    if [[ "$TYPE" == "theme" ]]; then
		echo ""
        echo -e "${GREEN}+  Theme rollback complete! ${GREY}Activate manually in WP Admin → Appearance → Themes (if different theme name)${NC}"
    fi
    
    echo ""
    echo -e "${GREY}===================================${NC}"
    echo -e "${WHITE}  Rollback completed successfully!${NC}"
    echo -e "${GREY}===================================${NC}"
    echo ""
    
    # Clean up mapping file
    rm -f "$TEMP_MAPPING"
}

case "$1" in
    list)
        list_backups
        ;;
    deploy)
        if [[ -z "$2" ]]; then
            echo -e "${RED}+  ERROR: Please specify version number or list number${NC}"
            echo "  Usage: $0 deploy {VERSION|NUMBER}"
            echo "  Example: $0 deploy 1.2.3  or  $0 deploy 1"
            exit 1
        fi
        deploy_rollback "$2"
        ;;
    *)
        echo "  Usage: $0 {list|deploy VERSION|NUMBER}"
        echo ""
        echo "  Examples:"
        echo "    $0 list              # Show available backups"
        echo "    $0 deploy 1.2.3      # Rollback to version 1.2.3"
        echo "    $0 deploy 1          # Rollback to backup #1 from list"
        exit 1
        ;;
esac
