@echo off
REM WordPress Fast Deploy - Database Restore Utility
REM Created by: lso2 (https://github.com/lso2)
REM Repository: https://github.com/lso2/wp-fast-remote-deploy
REM License: MIT

cd /d "%~dp0\.."
echo.
echo ====================================
echo   WordPress Fast Deploy - DB Restore
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

echo Available database backups:
wsl -e bash -c "cd '%WSL_DIR%' && chmod +x ./.run/db-restore.sh && ./.run/db-restore.sh list"
echo.
set /p BACKUP_FILE="Enter backup filename to restore (or 'exit' to cancel): "

if /i "%BACKUP_FILE%"=="exit" (
    echo Database restore cancelled.
    pause
    exit /b 0
)

echo.
echo WARNING: This will replace your current database!
echo Make sure you have a recent backup before proceeding.
echo.
set /p CONFIRM="Type 'YES' to confirm database restore: "

if not "%CONFIRM%"=="YES" (
    echo Database restore cancelled.
    pause
    exit /b 0
)

echo.
echo Restoring database from %BACKUP_FILE%...
wsl -e bash -c "cd '%WSL_DIR%' && ./.run/db-restore.sh restore '%BACKUP_FILE%'"

set "EXIT_CODE=%errorlevel%"

if %EXIT_CODE% equ 0 (
    echo.
    echo ================================
    echo   Database restore completed!
    echo ================================
) else (
    echo.
    echo ================================
    echo   Database restore failed!
    echo ================================
    echo Exit code: %EXIT_CODE%
)

echo.
echo Press any key to continue...
pause >nul
