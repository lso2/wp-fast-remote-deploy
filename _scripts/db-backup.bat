@echo off
REM WordPress Fast Deploy - Database Backup Utility
REM Created by: lso2 (https://github.com/lso2)
REM Repository: https://github.com/lso2/wp-fast-remote-deploy
REM License: MIT

cd /d "%~dp0\.."
echo.
echo ====================================
echo   WordPress Fast Deploy - DB Backup
echo ====================================
echo.

if not exist "config.sh" (
    echo ERROR: config.sh not found!
    echo Please run this from the same directory as your deployment script.
    pause
    exit /b 1
)

REM Get the current directory path for WSL (after cd to root)
set "CURRENT_DIR=%cd%"
set "PATH_NO_DRIVE=%CURRENT_DIR:~2%"
set "WSL_PATH=%PATH_NO_DRIVE:\=/%"
set "WSL_DIR=/mnt/c%WSL_PATH%"

echo Creating manual database backup...
wsl -e bash -c "cd '%WSL_DIR%' && chmod +x ./.run/db-backup.sh && ./.run/db-backup.sh"

set "EXIT_CODE=%errorlevel%"

if %EXIT_CODE% equ 0 (
    echo.
    echo ================================
    echo   Database backup completed!
    echo ================================
) else (
    echo.
    echo ================================
    echo   Database backup failed!
    echo ================================
    echo Exit code: %EXIT_CODE%
)

echo.
echo Press any key to continue...
pause >nul
