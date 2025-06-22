@echo off
REM WordPress Fast Deploy - Rollback Utility
REM Created by: lso2 (https://github.com/lso2)
REM Repository: https://github.com/lso2/wp-fast-remote-deploy
REM License: GPLv3

cd /d "%~dp0\.."
REM echo ====================================
REM echo   WordPress Fast Deploy - Rollback
REM echo ====================================

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

wsl -e bash -c "cd '%WSL_DIR%' && chmod +x ./.run/rollback.sh && ./.run/rollback.sh list"
echo.
set /p VERSION="Enter version number to rollback to (or 'exit' to cancel): "

if /i "%VERSION%"=="exit" (
    echo Rollback cancelled.
    pause
    exit /b 0
)

echo.
echo Rolling back to version %VERSION%...
wsl -e bash -c "cd '%WSL_DIR%' && ./.run/rollback.sh deploy %VERSION%"

set "EXIT_CODE=%errorlevel%"

if %EXIT_CODE% equ 0 (
REM     echo.
REM     echo ===================================
REM     echo   Rollback completed successfully!
REM     echo ===================================
) else (
    echo.
    echo ================================
    echo   Rollback failed!
    echo ================================
    echo Exit code: %EXIT_CODE%
)

echo.
echo Press any key to continue...
pause >nul
