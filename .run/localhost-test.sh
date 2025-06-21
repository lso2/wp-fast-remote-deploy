#!/bin/bash

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config.sh"
source "$CONFIG_FILE"

# SSH connection settings
SSH_OPTS="-i $SSH_KEY -p $SSH_PORT -o ConnectTimeout=10 -o StrictHostKeyChecking=no"

echo "Testing without host parameter (like manual command)..."

# Test exactly like the working manual command
ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "
export LC_ALL=C
echo 'Testing without host parameter (localhost default):'
mysqldump -u '$DB_USER' -p'$DB_PASS' --single-transaction --no-tablespaces '$DB_NAME' > /tmp/test_backup.sql 2>&1
echo \"Exit code: \$?\"
echo \"File size: \$(ls -la /tmp/test_backup.sql 2>/dev/null || echo 'File not created')\"
if [ -f /tmp/test_backup.sql ]; then
    echo \"First 3 lines of output:\"
    head -3 /tmp/test_backup.sql
    echo \"Last 3 lines of output:\"
    tail -3 /tmp/test_backup.sql
    echo \"SQL dump looks good? Check for actual SQL:\"
    grep -E '^(CREATE|INSERT|DROP)' /tmp/test_backup.sql | head -3
fi
rm -f /tmp/test_backup.sql
"

echo "Test complete"
