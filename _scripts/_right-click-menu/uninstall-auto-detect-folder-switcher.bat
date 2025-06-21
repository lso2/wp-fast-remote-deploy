@echo off
REM Uninstall Auto-Detecting Folder Switcher Context Menu
REM Run this as Administrator

echo Uninstalling Auto-Detecting Folder Switcher context menu...
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script must be run as Administrator!
    echo Right-click this file and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

echo Running as Administrator - OK
echo.

REM Remove registry entries
echo Removing registry entries...

echo Removing folder context menu...
reg delete "HKEY_CLASSES_ROOT\Directory\shell\AutoDetectFolderSwitcher" /f 2>nul
if %errorLevel% equ 0 (
    echo Folder context menu removed successfully.
) else (
    echo Folder context menu was not found or already removed.
)

echo Removing background context menu...
reg delete "HKEY_CLASSES_ROOT\Directory\Background\shell\AutoDetectFolderSwitcher" /f 2>nul
if %errorLevel% equ 0 (
    echo Background context menu removed successfully.
) else (
    echo Background context menu was not found or already removed.
)

REM Remove PowerShell script and icon
set SCRIPT_PATH=%WINDIR%\auto-detect-folder-switcher.ps1
set ICON_PATH=%WINDIR%\wp-deploy.ico

echo Removing PowerShell script...
if exist "%SCRIPT_PATH%" (
    del "%SCRIPT_PATH%" 2>nul
    if %errorLevel% equ 0 (
        echo PowerShell script removed successfully.
    ) else (
        echo WARNING: Could not remove PowerShell script at %SCRIPT_PATH%
        echo You may need to delete it manually.
    )
) else (
    echo PowerShell script was not found or already removed.
)

echo Removing icon file...
if exist "%ICON_PATH%" (
    del "%ICON_PATH%" 2>nul
    if %errorLevel% equ 0 (
        echo Icon file removed successfully.
    ) else (
        echo WARNING: Could not remove icon file at %ICON_PATH%
        echo You may need to delete it manually.
    )
) else (
    echo Icon file was not found or already removed.
)

echo.
echo ========================================
echo Uninstallation complete!
echo ========================================
echo.
echo The "Switch to This Folder (Fast Deploy)" option has been removed from:
echo 1. Right-click context menus on folders
echo 2. Right-click background context menus
echo.
echo Files removed:
echo - Registry entries for context menus
echo - PowerShell script: %SCRIPT_PATH%
echo - Icon file: %ICON_PATH%
echo.
echo Press any key to exit...
pause > nul
