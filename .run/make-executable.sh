#!/bin/bash

# Make all shell scripts executable
echo "Making scripts executable..."

chmod +x deploy-wsl.sh
chmod +x db-backup.sh  
chmod +x db-restore.sh
chmod +x rollback.sh
chmod +x sample-data-wsl.sh

echo "✅ All scripts are now executable!"
echo ""
echo "WordPress Fast Deploy v3.1.0 - Database System Improvements:"
echo "============================================================"
echo ""
echo "💫 MAJOR IMPROVEMENTS:"
echo "   - Database credentials read automatically from wp-config.php"
echo "   - No more manual database configuration required"
echo "   - Fixed SSH vs database credential issues"
echo "   - Updated all paths for new directory structure"
echo ""
echo "🚀 HOW TO USE:"
echo "   1. Set DB_BACKUP_ENABLED=\"true\" in config.sh"
echo "   2. Run deploy.bat as normal"
echo "   3. Database backup happens automatically!"
echo ""
echo "📊 UTILITIES AVAILABLE:"
echo "   - _scripts/db-backup.bat (manual backup)"
echo "   - _scripts/db-restore.bat (restore from backup)"
echo "   - _scripts/rollback.bat (rollback deployment)"
echo ""
echo "✨ All database operations now read wp-config.php automatically!"
echo "   No manual configuration needed - just enable and deploy!"
echo ""
