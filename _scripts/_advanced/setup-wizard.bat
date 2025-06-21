@echo off
REM WordPress Fast Deploy v3.0.0 - Advanced Features Setup Wizard
REM Created by: lso2 (https://github.com/lso2)
REM Repository: https://github.com/lso2/wp-fast-remote-deploy
REM License: MIT

cd /d "%~dp0\..\.."
echo.
echo ========================================
echo  WordPress Fast Deploy v3.0.0
echo  Advanced Features Setup Wizard
echo ========================================
echo.
echo This wizard will help you configure the new advanced features:
echo.
echo 1. Rollback Capabilities (Always Available)
echo 2. Database Backup Integration
echo 3. Git Integration
echo 4. Multi-Server Deployment
echo.
echo Note: All features are OPTIONAL and won't affect your basic deployment workflow.
echo.
pause

if not exist "config.sh" (
    echo ERROR: config.sh not found!
    echo Please run this from the same directory as your deployment script.
    pause
    exit /b 1
)

echo.
echo ========================================
echo  1. ROLLBACK CAPABILITIES
echo ========================================
echo.
echo Rollback capabilities are now available using your existing backups!
echo.
echo New utilities:
echo - rollback.bat : Interactive rollback to any previous version
echo - rollback.sh  : Command-line rollback script
echo.
echo No configuration needed - works with your existing backup system.
echo.
pause

echo.
echo ========================================
echo  2. DATABASE BACKUP INTEGRATION
echo ========================================
echo.
set /p DB_ENABLE="Enable automatic database backups during deployment? (y/N): "

if /i "%DB_ENABLE%"=="y" (
    echo.
    echo Enter your database connection details:
    set /p DB_NAME="Database name: "
    set /p DB_USER="Database username: "
    set /p DB_PASS="Database password: "
    set /p DB_HOST="Database host (default: localhost): "
    set /p DB_PORT="Database port (default: 3306): "
    
    if "%DB_HOST%"=="" set "DB_HOST=localhost"
    if "%DB_PORT%"=="" set "DB_PORT=3306"
    
    echo.
    set /p DB_CUSTOM_PATH="Use custom backup path? (y/N): "
    
    if /i "%DB_CUSTOM_PATH%"=="y" (
        set /p DB_PATH="Custom backup directory path: "
        set "DB_PATH_ENABLED=true"
    ) else (
        set "DB_PATH_ENABLED=false"
        set "DB_PATH="
    )
    
    set "DB_CONFIG=true"
    echo.
    echo Database backup will be configured.
) else (
    set "DB_CONFIG=false"
    echo.
    echo Database backup will remain disabled.
)

echo.
pause

echo.
echo ========================================
echo  3. GIT INTEGRATION
echo ========================================
echo.
set /p GIT_ENABLE="Enable Git integration? (y/N): "

if /i "%GIT_ENABLE%"=="y" (
    echo.
    echo Git integration allows automatic commits and pushes during deployment.
    echo.
    set /p GIT_REPO="GitHub repository URL (https://github.com/user/repo.git): "
    set /p GIT_TOKEN="GitHub Personal Access Token: "
    set /p GIT_AUTO="Enable auto-commit before deployment? (y/N): "
    
    if /i "%GIT_AUTO%"=="y" (
        set "GIT_AUTO_COMMIT=true"
    ) else (
        set "GIT_AUTO_COMMIT=false"
    )
    
    set "GIT_CONFIG=true"
    echo.
    echo Git integration will be configured.
) else (
    set "GIT_CONFIG=false"
    echo.
    echo Git integration will remain disabled.
)

echo.
pause

echo.
echo ========================================
echo  4. MULTI-SERVER DEPLOYMENT
echo ========================================
echo.
set /p MULTI_ENABLE="Enable multi-server deployment? (y/N): "

if /i "%MULTI_ENABLE%"=="y" (
    echo.
    echo Multi-server deployment allows you to deploy to staging and production servers.
    echo.
    echo === STAGING SERVER CONFIGURATION ===
    set /p STAGING_HOST="Staging server hostname/IP: "
    set /p STAGING_USER="Staging SSH username: "
    set /p STAGING_PATH="Staging WordPress root path: "
    
    echo.
    set /p ENABLE_PROD="Also configure production server? (y/N): "
    
    if /i "%ENABLE_PROD%"=="y" (
        echo.
        echo === PRODUCTION SERVER CONFIGURATION ===
        set /p PRODUCTION_HOST="Production server hostname/IP: "
        set /p PRODUCTION_USER="Production SSH username: "
        set /p PRODUCTION_PATH="Production WordPress root path: "
        set "PROD_CONFIG=true"
    ) else (
        set "PROD_CONFIG=false"
    )
    
    set "MULTI_CONFIG=true"
    echo.
    echo Multi-server deployment will be configured.
) else (
    set "MULTI_CONFIG=false"
    echo.
    echo Multi-server deployment will remain disabled.
)

echo.
echo ========================================
echo  APPLYING CONFIGURATION
echo ========================================
echo.
echo Updating config.sh with your settings...

REM Apply all configurations using PowerShell
powershell -Command "
$content = Get-Content 'config.sh' -Raw;

# Database configuration
if ('%DB_CONFIG%' -eq 'true') {
    $content = $content -replace 'DB_BACKUP_ENABLED=\"false\"', 'DB_BACKUP_ENABLED=\"true\"';
    $content = $content -replace 'DB_NAME=\"wp_database\"', 'DB_NAME=\"%DB_NAME%\"';
    $content = $content -replace 'DB_USER=\"wp_username\"', 'DB_USER=\"%DB_USER%\"';
    $content = $content -replace 'DB_PASS=\"wp_password\"', 'DB_PASS=\"%DB_PASS%\"';
    if ('%DB_HOST%' -ne 'localhost') {
        $content = $content -replace '#DB_HOST=\"localhost\"', 'DB_HOST=\"%DB_HOST%\"';
    }
    if ('%DB_PORT%' -ne '3306') {
        $content = $content -replace '#DB_PORT=\"port\"', 'DB_PORT=\"%DB_PORT%\"';
    }
    if ('%DB_PATH_ENABLED%' -eq 'true') {
        $content = $content -replace 'DB_PATH_ENABLED=\"false\"', 'DB_PATH_ENABLED=\"true\"';
        $content = $content -replace 'DB_PATH=\"/path/to/db/backup/folder\"', 'DB_PATH=\"%DB_PATH%\"';
    }
}

# Git configuration
if ('%GIT_CONFIG%' -eq 'true') {
    $content = $content -replace 'GIT_ENABLED=\"false\"', 'GIT_ENABLED=\"true\"';
    $content = $content -replace 'GIT_AUTO_COMMIT=\"false\"', 'GIT_AUTO_COMMIT=\"%GIT_AUTO_COMMIT%\"';
    $content = $content -replace 'GIT_REPO_URL=\"\"', 'GIT_REPO_URL=\"%GIT_REPO%\"';
    $content = $content -replace 'GIT_TOKEN=\"\"', 'GIT_TOKEN=\"%GIT_TOKEN%\"';
}

# Multi-server configuration
if ('%MULTI_CONFIG%' -eq 'true') {
    $content = $content -replace 'MULTI_SERVER_ENABLED=\"false\"', 'MULTI_SERVER_ENABLED=\"true\"';
    $content = $content -replace 'STAGING_SSH_HOST=\"\"', 'STAGING_SSH_HOST=\"%STAGING_HOST%\"';
    $content = $content -replace 'STAGING_SSH_USER=\"\"', 'STAGING_SSH_USER=\"%STAGING_USER%\"';
    $content = $content -replace 'STAGING_SSH_PATH=\"\"', 'STAGING_SSH_PATH=\"%STAGING_PATH%\"';
    $content = $content -replace 'STAGING_WP_PATH=\"\"', 'STAGING_WP_PATH=\"%STAGING_PATH%\"';
    
    if ('%PROD_CONFIG%' -eq 'true') {
        $content = $content -replace 'DEPLOY_TO_PRODUCTION=\"false\"', 'DEPLOY_TO_PRODUCTION=\"true\"';
        $content = $content -replace 'PRODUCTION_SSH_HOST=\"\"', 'PRODUCTION_SSH_HOST=\"%PRODUCTION_HOST%\"';
        $content = $content -replace 'PRODUCTION_SSH_USER=\"\"', 'PRODUCTION_SSH_USER=\"%PRODUCTION_USER%\"';
        $content = $content -replace 'PRODUCTION_SSH_PATH=\"\"', 'PRODUCTION_SSH_PATH=\"%PRODUCTION_PATH%\"';
        $content = $content -replace 'PRODUCTION_WP_PATH=\"\"', 'PRODUCTION_WP_PATH=\"%PRODUCTION_PATH%\"';
    }
}

Set-Content 'config.sh' -Value $content -NoNewline
"

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo  SETUP COMPLETE!
    echo ========================================
    echo.
    echo WordPress Fast Deploy v3.0.0 is now configured with:
    echo.
    echo ✅ Rollback Capabilities: Always available
    if "%DB_CONFIG%"=="true" (
        echo ✅ Database Backup: ENABLED
    ) else (
        echo ❌ Database Backup: Disabled
    )
    if "%GIT_CONFIG%"=="true" (
        echo ✅ Git Integration: ENABLED
        if "%GIT_AUTO_COMMIT%"=="true" (
            echo    - Auto-commit: ENABLED
        ) else (
            echo    - Auto-commit: Disabled
        )
    ) else (
        echo ❌ Git Integration: Disabled
    )
    if "%MULTI_CONFIG%"=="true" (
        echo ✅ Multi-Server: ENABLED
        echo    - Staging: %STAGING_HOST%
        if "%PROD_CONFIG%"=="true" (
            echo    - Production: %PRODUCTION_HOST%
        ) else (
            echo    - Production: Not configured
        )
    ) else (
        echo ❌ Multi-Server: Disabled
    )
    echo.
    echo NEW UTILITIES AVAILABLE:
    echo - rollback.bat       : Rollback to previous versions
    echo - db-backup.bat      : Manual database backup
    echo - db-restore.bat     : Database restore utility
    echo - git-setup.bat      : Git configuration helper
    echo - multi-server-setup.bat : Multi-server setup helper
    echo.
    echo Your basic deployment workflow remains unchanged!
    echo Just run deploy.bat as usual - new features work automatically.
) else (
    echo.
    echo ========================================
    echo  SETUP FAILED!
    echo ========================================
    echo Please check the error above and try again.
)

echo.
echo Press any key to continue...
pause >nul
