@echo off
setlocal enabledelayedexpansion

:: Title
title WordPress Fast Deploy - Sample Data Installer

:: Get the script's directory and calculate paths
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

:: Go up one level to get to wp-fast-remote-deploy root
for %%i in ("%SCRIPT_DIR%") do set "PROJECT_ROOT=%%~dpi"
set "PROJECT_ROOT=%PROJECT_ROOT:~0,-1%"

:: Go up one more level to get the target installation directory
for %%i in ("%PROJECT_ROOT%") do set "TARGET_DIR=%%~dpi"
set "TARGET_DIR=%TARGET_DIR:~0,-1%"

:: Set paths
set "SAMPLE_DATA=%SCRIPT_DIR%\_advanced\.sample-data\sample-data.tar.gz"

:: Convert Windows paths to WSL format
set "DRIVE_LETTER=%SCRIPT_DIR:~0,1%"
set "SCRIPT_PATH=%SCRIPT_DIR:~3%"
set "TARGET_PATH=%TARGET_DIR:~3%"

:: Convert to lowercase drive letter for WSL
for %%i in (a b c d e f g h i j k l m n o p q r s t u v w x y z) do (
    if /i "%DRIVE_LETTER%"=="%%i" set "DRIVE_LETTER_LOWER=%%i"
)

:: Replace backslashes with forward slashes
set "WSL_SCRIPT_PATH=%SCRIPT_PATH:\=/%"
set "WSL_TARGET_PATH=%TARGET_PATH:\=/%"

:: Build full WSL paths
set "WSL_SAMPLE_DATA=/mnt/%DRIVE_LETTER_LOWER%/%WSL_SCRIPT_PATH%/_advanced/.sample-data/sample-data.tar.gz"
set "WSL_TARGET_DIR=/mnt/%DRIVE_LETTER_LOWER%/%WSL_TARGET_PATH%"
set "WSL_SCRIPT=/mnt/%DRIVE_LETTER_LOWER%/%WSL_SCRIPT_PATH%/../.run/sample-data-wsl.sh"

:: Check if sample data exists
if not exist "%SAMPLE_DATA%" (
    echo.
    echo [ERROR] Sample data not found at:
    echo %SAMPLE_DATA%
    echo.
    echo Please ensure the sample-data.tar.gz file exists.
    echo.
    pause
    exit /b 1
)

:: Make the script executable and run it
wsl bash -c "chmod +x '%WSL_SCRIPT%' && '%WSL_SCRIPT%' '%WSL_SAMPLE_DATA%' '%WSL_TARGET_DIR%'"

set "EXIT_CODE=%errorlevel%"

if %EXIT_CODE% equ 0 (
    echo.
    echo Press any key to close...
    pause >nul
) else (
    echo.
    echo Installation failed!
    echo.
    echo Press any key to close...
    pause >nul
)

exit /b %EXIT_CODE%
