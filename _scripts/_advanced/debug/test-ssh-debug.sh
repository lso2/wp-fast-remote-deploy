#!/bin/bash

# Test SSH and mysqldump separately
echo "Testing SSH connection..."
ssh -i ~/.ssh/id_rsa -p 22 username@server3.hostrabbits.com "echo 'SSH connection successful'"

echo ""
echo "Testing mysqldump directly..."
ssh -i ~/.ssh/id_rsa -p 22 username@server3.hostrabbits.com "
    mysqldump -u techread_test9393203 -p'your_actual_password' \
        --single-transaction \
        --no-tablespaces \
        techread_test9393202 | head -5
"

echo ""
echo "Testing with full SSH options..."
ssh -i ~/.ssh/id_rsa -p 22 -o ControlMaster=auto -o ControlPath=/tmp/ssh-%r@%h:%p -o ControlPersist=30s -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no username@server3.hostrabbits.com "echo 'SSH with full options successful'"
