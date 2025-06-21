@echo off
REM WordPress Fast Deploy - Database Backup Debug
REM Created by: lso2 (https://github.com/lso2)
REM Repository: https://github.com/lso2/wp-fast-remote-deploy
REM License: MIT

cd /d "%~dp0\.."
echo.
echo ====================================
echo   DEBUG: Database Backup
echo ====================================
echo.

if not exist "config.sh" (
    echo ERROR: config.sh not found!
    pause
    exit /b 1
)

REM Get the current directory path for WSL (after cd to root)
set "CURRENT_DIR=%cd%"
set "PATH_NO_DRIVE=%CURRENT_DIR:~2%"
set "WSL_PATH=%PATH_NO_DRIVE:\=/%"
set "WSL_DIR=/mnt/c%WSL_PATH%"

echo Creating manual database backup with full debug output...
echo.
echo WSL Directory: %WSL_DIR%
echo.

REM Run with full output and no error suppression
wsl -e bash -c "cd '%WSL_DIR%' && chmod +x ./.run/db-backup.sh && ./.run/db-backup.sh"

echo.
echo Debug complete. Check output above for any errors.
pause
