@echo off
REM WordPress Plugin Fast Deployment Script - Windows Launcher
REM Created by: lso2 (https://github.com/lso2)
REM Repository: https://github.com/lso2/wp-fast-remote-deploy
REM License: MIT
REM Version: 1.0.1

cd /d "%~dp0"
echo Starting plugin deployment from %CD%...
echo.

REM Get the current directory path
set "CURRENT_DIR=%~dp0"

REM Remove the drive letter and colon (C:)
set "PATH_NO_DRIVE=%CURRENT_DIR:~2%"

REM Convert backslashes to forward slashes
set "WSL_PATH=%PATH_NO_DRIVE:\=/%"

REM Create the full WSL path
set "WSL_DIR=/mnt/c%WSL_PATH%"

REM Suppress Perl locale warnings
set "PERL_BADLANG=0"

echo Converted path: %WSL_DIR%

REM Get script name from config
for /f "tokens=2 delims==" %%i in ('findstr "SCRIPT_NAME=" config.sh') do set "SCRIPT_NAME=%%i"
REM Remove quotes if present
set "SCRIPT_NAME=%SCRIPT_NAME:"=%"

wsl -e bash -c "export PERL_BADLANG=0 && cd '%WSL_DIR%' && chmod +x ./.run/%SCRIPT_NAME% && ./.run/%SCRIPT_NAME%"

set "EXIT_CODE=%errorlevel%"

if %EXIT_CODE% equ 0 (
    echo.
    echo ================================
    echo Deployment completed successfully!
    echo ================================
) else (
    echo.
    echo ================================
    echo Deployment failed!
    echo ================================
    echo Exit code: %EXIT_CODE%
    echo.
    echo Press any key to close...
    pause >nul
)