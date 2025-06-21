@echo off
REM WordPress Fast Deploy - Multi-Server Setup Helper
REM Created by: lso2 (https://github.com/lso2)
REM Repository: https://github.com/lso2/wp-fast-remote-deploy
REM License: MIT

cd /d "%~dp0\..\.."
echo.
echo ====================================
echo  Multi-Server Deployment Setup
echo ====================================
echo.
echo This will help you configure multi-server deployment.
echo You can deploy to staging first, then optionally to production.
echo.

set /p ENABLE_MULTI="Enable multi-server deployment? (y/N): "

if /i not "%ENABLE_MULTI%"=="y" (
    echo Multi-server deployment setup cancelled.
    pause
    exit /b 0
)

echo.
echo === STAGING SERVER CONFIGURATION ===
set /p STAGING_HOST="Staging server hostname/IP: "
set /p STAGING_USER="Staging SSH username: "
set /p STAGING_PATH="Staging WordPress root path: "

echo.
echo === PRODUCTION SERVER CONFIGURATION ===
set /p ENABLE_PROD="Configure production server? (y/N): "

if /i "%ENABLE_PROD%"=="y" (
    set /p PRODUCTION_HOST="Production server hostname/IP: "
    set /p PRODUCTION_USER="Production SSH username: "
    set /p PRODUCTION_PATH="Production WordPress root path: "
    set "PROD_CONFIG=true"
) else (
    set "PROD_CONFIG=false"
)

echo.
echo === DEPLOYMENT OPTIONS ===
set /p AUTO_STAGING="Always deploy to staging first? (Y/n): "
set /p CONFIRM_PROD="Require confirmation for production? (Y/n): "

if /i "%AUTO_STAGING%"=="n" (
    set "AUTO_STAGING_VALUE=false"
) else (
    set "AUTO_STAGING_VALUE=true"
)

if /i "%CONFIRM_PROD%"=="n" (
    set "CONFIRM_PROD_VALUE=false"
) else (
    set "CONFIRM_PROD_VALUE=true"
)

echo.
echo Updating config.sh...

REM Update multi-server configuration using PowerShell
powershell -Command "
$content = Get-Content 'config.sh' -Raw;
$content = $content -replace 'MULTI_SERVER_ENABLED=\"false\"', 'MULTI_SERVER_ENABLED=\"true\"';
$content = $content -replace 'DEPLOY_TO_STAGING=\"true\"', 'DEPLOY_TO_STAGING=\"%AUTO_STAGING_VALUE%\"';
$content = $content -replace 'DEPLOY_TO_PRODUCTION=\"false\"', 'DEPLOY_TO_PRODUCTION=\"%CONFIRM_PROD_VALUE%\"';
$content = $content -replace 'STAGING_SSH_HOST=\"\"', 'STAGING_SSH_HOST=\"%STAGING_HOST%\"';
$content = $content -replace 'STAGING_SSH_USER=\"\"', 'STAGING_SSH_USER=\"%STAGING_USER%\"';
$content = $content -replace 'STAGING_SSH_PATH=\"\"', 'STAGING_SSH_PATH=\"%STAGING_PATH%\"';
$content = $content -replace 'STAGING_WP_PATH=\"\"', 'STAGING_WP_PATH=\"%STAGING_PATH%\"';
if ('%PROD_CONFIG%' -eq 'true') {
    $content = $content -replace 'PRODUCTION_SSH_HOST=\"\"', 'PRODUCTION_SSH_HOST=\"%PRODUCTION_HOST%\"';
    $content = $content -replace 'PRODUCTION_SSH_USER=\"\"', 'PRODUCTION_SSH_USER=\"%PRODUCTION_USER%\"';
    $content = $content -replace 'PRODUCTION_SSH_PATH=\"\"', 'PRODUCTION_SSH_PATH=\"%PRODUCTION_PATH%\"';
    $content = $content -replace 'PRODUCTION_WP_PATH=\"\"', 'PRODUCTION_WP_PATH=\"%PRODUCTION_PATH%\"';
}
Set-Content 'config.sh' -Value $content -NoNewline
"

if %errorlevel% equ 0 (
    echo.
    echo ================================
    echo  Multi-server setup complete!
    echo ================================
    echo.
    echo Configuration:
    echo - Multi-server deployment: ENABLED
    echo - Staging server: %STAGING_HOST%
    echo - Auto-deploy to staging: %AUTO_STAGING_VALUE%
    if "%PROD_CONFIG%"=="true" (
        echo - Production server: %PRODUCTION_HOST%
        echo - Production confirmation: %CONFIRM_PROD_VALUE%
    ) else (
        echo - Production server: Not configured
    )
    echo.
    echo Your deployments will now:
    if "%AUTO_STAGING_VALUE%"=="true" (
        echo 1. Deploy to staging automatically
    ) else (
        echo 1. Ask before deploying to staging
    )
    if "%PROD_CONFIG%"=="true" (
        if "%CONFIRM_PROD_VALUE%"=="true" (
            echo 2. Ask for confirmation before production deployment
        ) else (
            echo 2. Deploy to production automatically after staging
        )
    ) else (
        echo 2. Skip production (not configured)
    )
) else (
    echo.
    echo ================================
    echo   Configuration failed!
    echo ================================
    echo Please check the error above and try again.
)

echo.
echo Press any key to continue...
pause >nul
