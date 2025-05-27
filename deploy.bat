@echo off
cd /d "%~dp0"
echo Starting deployment from %CD%...
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

wsl -e bash -c "export PERL_BADLANG=0 && cd '%WSL_DIR%' && chmod +x ./.run/deploy-wsl.sh && ./.run/deploy-wsl.sh"

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