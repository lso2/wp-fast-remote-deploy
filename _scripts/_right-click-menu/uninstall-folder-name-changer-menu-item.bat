@echo off
REM Uninstall Folder Name Changer Context Menu
REM Run this as Administrator

echo Uninstalling Folder Name Changer context menu...
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

set SCRIPT_PATH=%WINDIR%\change-folder-name.ps1

echo Removing registry entries...

REM Remove folder context menu
echo Removing folder context menu...
reg delete "HKEY_CLASSES_ROOT\Directory\shell\ChangeFolderName" /f 2>nul
if %errorLevel% equ 0 (
    echo Folder context menu removed successfully.
) else (
    echo Folder context menu was not found ^(may already be removed^).
)

REM Remove background context menu
echo Removing background context menu...
reg delete "HKEY_CLASSES_ROOT\Directory\Background\shell\ChangeFolderName" /f 2>nul
if %errorLevel% equ 0 (
    echo Background context menu removed successfully.
) else (
    echo Background context menu was not found ^(may already be removed^).
)

REM Remove PowerShell script
echo Removing PowerShell script...
if exist "%SCRIPT_PATH%" (
    del "%SCRIPT_PATH%"
    if exist "%SCRIPT_PATH%" (
        echo ERROR: Failed to delete PowerShell script at %SCRIPT_PATH%
        echo You may need to delete it manually.
    ) else (
        echo PowerShell script removed successfully.
    )
) else (
    echo PowerShell script was not found ^(may already be removed^).
)

echo.
echo ========================================
echo Uninstallation complete!
echo ========================================
echo.
echo The "Change Folder Name" context menu option has been removed.
echo.
echo Files removed:
echo - PowerShell script: %SCRIPT_PATH%
echo - Registry entries for context menus
echo.
echo You may need to restart Explorer.exe or reboot for changes to take full effect.
echo.
echo Press any key to exit...
pause > nul
