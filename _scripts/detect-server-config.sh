#!/bin/bash

# WordPress Root Auto-Detector
# Drop this script into your WordPress root directory and run it
# It will automatically detect the WordPress root path and generate
# the configuration information you need for wp-fast-remote-deploy

echo "WordPress Fast Deploy - Server Auto-Detection"
echo "=============================================="
echo

# Get the current directory (where this script is located)
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Current directory: $CURRENT_DIR"

# Check if this looks like a WordPress root directory
WP_INDICATORS=(
    "wp-config.php"
    "wp-content"
    "wp-includes"
    "wp-admin"
    "index.php"
)

echo
echo "Checking for WordPress files..."
FOUND_COUNT=0
for indicator in "${WP_INDICATORS[@]}"; do
    if [[ -e "$CURRENT_DIR/$indicator" ]]; then
        echo "✓ Found: $indicator"
        ((FOUND_COUNT++))
    else
        echo "✗ Missing: $indicator"
    fi
done

echo
if [[ $FOUND_COUNT -ge 4 ]]; then
    echo "✓ This appears to be a WordPress root directory!"
    WORDPRESS_ROOT="$CURRENT_DIR"
else
    echo "⚠ This doesn't look like a WordPress root directory."
    echo "  Please run this script from your WordPress root directory."
    echo
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 1
    fi
    WORDPRESS_ROOT="$CURRENT_DIR"
fi

echo
echo "WordPress root detected: $WORDPRESS_ROOT"

# Detect server information
echo
echo "Detecting server information..."
SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "unknown")
HOSTNAME=$(hostname 2>/dev/null || echo "unknown")
USER=$(whoami 2>/dev/null || echo "unknown")

echo "Server IP: $SERVER_IP"
echo "Hostname: $HOSTNAME"
echo "Current user: $USER"

# Check if WP-CLI is available
echo
echo "Checking for WP-CLI..."
if command -v wp >/dev/null 2>&1; then
    WP_CLI_VERSION=$(wp --version 2>/dev/null | head -n1)
    echo "✓ WP-CLI found: $WP_CLI_VERSION"
    WP_CLI_STATUS="available"
else
    echo "✗ WP-CLI not found (optional - install for automatic plugin activation)"
    WP_CLI_STATUS="not available"
fi

# Check SSH server status and port
echo
echo "Checking SSH server..."
SSH_PORT="22"  # Default port
if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
    echo "✓ SSH server is running"
    # Try to detect actual SSH port from config
    if [[ -f /etc/ssh/sshd_config ]]; then
        DETECTED_PORT=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -n1)
        if [[ -n "$DETECTED_PORT" && "$DETECTED_PORT" != "22" ]]; then
            SSH_PORT="$DETECTED_PORT"
            echo "✓ Detected custom SSH port: $SSH_PORT"
        else
            echo "✓ Using default SSH port: $SSH_PORT"
        fi
    fi
    SSH_STATUS="running"
else
    echo "? SSH server status unknown (may still be working)"
    SSH_STATUS="unknown"
fi

# Generate configuration
echo
echo "=============================================="
echo "CONFIGURATION FOR WP-FAST-REMOTE-DEPLOY"
echo "=============================================="
echo
echo "Copy these values to your config.sh file:"
echo
echo "# Remote Environment"
echo "REMOTE_BASE=\"$WORDPRESS_ROOT\""
echo
echo "# SSH Configuration"
echo "SSH_HOST=\"$SERVER_IP\"  # or use: \"$HOSTNAME\""
echo "SSH_PORT=\"$SSH_PORT\""
echo "SSH_USER=\"$USER\""
echo "SSH_KEY=\"~/.ssh/id_rsa\""
echo
echo "=============================================="
echo "NEXT STEPS:"
echo "=============================================="
echo
echo "1. Copy the configuration above to your local config.sh file"
echo "2. Make sure you have SSH key authentication set up"
echo "3. Test SSH connection from your local machine:"
echo "   ssh $USER@$SERVER_IP -p 22"
if [[ "$WP_CLI_STATUS" == "not available" ]]; then
    echo "4. (Optional) Install WP-CLI for automatic plugin activation:"
    echo "   curl -O https://raw.githubusercontent.com/wp-cli/wp-cli/v2.8.1/utils/wp-cli.phar"
    echo "   chmod +x wp-cli.phar"
    echo "   sudo mv wp-cli.phar /usr/local/bin/wp"
fi
echo
echo "Server Information Summary:"
echo "- WordPress Root: $WORDPRESS_ROOT"
echo "- Server IP: $SERVER_IP"
echo "- Hostname: $HOSTNAME"
echo "- SSH User: $USER"
echo "- WP-CLI: $WP_CLI_STATUS"
echo "- SSH Server: $SSH_STATUS"
echo

# Offer to save to file
read -p "Save this configuration to a file? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    CONFIG_FILE="wp-fast-deploy-config.txt"
    {
        echo "# WordPress Fast Deploy Configuration"
        echo "# Generated on $(date)"
        echo "# Server: $HOSTNAME ($SERVER_IP)"
        echo
        echo "# Copy these values to your local config.sh file:"
        echo
        echo "REMOTE_BASE=\"$WORDPRESS_ROOT\""
        echo "SSH_HOST=\"$SERVER_IP\""
        echo "SSH_PORT=\"$SSH_PORT\""
        echo "SSH_USER=\"$USER\""
        echo "SSH_KEY=\"~/.ssh/id_rsa\""
        echo
        echo "# Additional Information:"
        echo "# - Hostname: $HOSTNAME"
        echo "# - WP-CLI: $WP_CLI_STATUS"
        echo "# - SSH Server: $SSH_STATUS"
        echo "# - Detection Date: $(date)"
    } > "$CONFIG_FILE"
    
    echo "✓ Configuration saved to: $CONFIG_FILE"
    echo "  You can download this file or copy the values manually."
fi

echo
echo "Done! You can now configure your local wp-fast-remote-deploy script."
