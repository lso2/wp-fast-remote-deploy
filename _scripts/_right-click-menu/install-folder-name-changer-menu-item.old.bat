@echo off
REM Install Folder Name Changer Context Menu
REM Run this as Administrator

echo Installing Folder Name Changer context menu...
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

REM Create the PowerShell script in Windows directory
set SCRIPT_PATH=%WINDIR%\change-folder-name.ps1

echo Creating PowerShell script at %SCRIPT_PATH%...

(
echo Add-Type -AssemblyName System.Windows.Forms
echo.
echo $FolderPath = $args[0]
echo $debugInfo = "Received path: '$FolderPath'"
echo.
echo if ^([string]::IsNullOrEmpty^($FolderPath^)^) {
echo     [System.Windows.Forms.MessageBox]::Show^("Error: No folder path received.`n`nThis usually means the context menu registration failed.`n`nDebug info: $debugInfo", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error^)
echo     exit 1
echo }
echo.
echo $folderName = Split-Path -Leaf $FolderPath
echo $parentPath = Split-Path -Parent $FolderPath
echo $configPath = Join-Path $parentPath "config.sh"
echo.
echo $debugInfo += "`nFolder name: '$folderName'`nParent path: '$parentPath'`nLooking for config at: '$configPath'"
echo.
echo if ^(-not ^(Test-Path $configPath^)^) {
echo     [System.Windows.Forms.MessageBox]::Show^("config.sh not found!`n`n$debugInfo", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error^)
echo     exit 1
echo }
echo.
echo try {
echo     $content = Get-Content $configPath -Raw
echo     $newContent = $content -replace 'FOLDER_NAME="[^"]*"', "FOLDER_NAME=`"$folderName`""
echo     Set-Content $configPath $newContent -NoNewline
echo.
echo     $type = "unknown"
echo     if ^($newContent -match 'TYPE="plugin"'^) { $type = "plugin" }
echo     if ^($newContent -match 'TYPE="theme"'^) { $type = "theme" }
echo.
echo     $deployFiles = @^(Get-ChildItem $parentPath -Name "deploy*.bat"^) + @^(Get-ChildItem $parentPath -Name "DEPLOY*.bat"^)
echo     if ^($deployFiles^) {
echo         $oldPath = Join-Path $parentPath $deployFiles[0]
echo         $newPath = Join-Path $parentPath "DEPLOY__${folderName}__${type}.bat"
echo         if ^(Test-Path $oldPath^) {
echo             Move-Item $oldPath $newPath -Force
echo         }
echo     }
echo.
echo     [System.Windows.Forms.MessageBox]::Show^("Successfully changed folder name to: '$folderName'`n`nFile: $configPath`nDeploy file renamed to: DEPLOY__${folderName}__${type}.bat`n`n$debugInfo", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information^)
echo } catch {
echo     [System.Windows.Forms.MessageBox]::Show^("Error: $^($_.Exception.Message^)", "Error"^)
echo }
) > "%SCRIPT_PATH%"

if %errorLevel% neq 0 (
    echo ERROR: Failed to create PowerShell script!
    pause
    exit /b 1
)

echo PowerShell script created successfully.
echo.

REM Register the context menu entry in the registry
echo Registering context menu entry...

REM Add the main registry key for folder context menu
echo Adding folder context menu...
reg add "HKEY_CLASSES_ROOT\Directory\shell\ChangeFolderName" /ve /d "Change Folder Name" /f
if %errorLevel% neq 0 (
    echo ERROR: Failed to add folder context menu registry key!
    pause
    exit /b 1
)

REM Add the command to execute - Using $args[0] instead of param()
reg add "HKEY_CLASSES_ROOT\Directory\shell\ChangeFolderName\command" /ve /d "powershell.exe -ExecutionPolicy Bypass -File \"%WINDIR%\change-folder-name.ps1\" \"%%1\"" /f
if %errorLevel% neq 0 (
    echo ERROR: Failed to add folder context menu command!
    pause
    exit /b 1
)

echo Folder context menu added successfully.

REM Also add it for background context menu (right-click in empty space)
echo Adding background context menu...
reg add "HKEY_CLASSES_ROOT\Directory\Background\shell\ChangeFolderName" /ve /d "Change Folder Name" /f
if %errorLevel% neq 0 (
    echo ERROR: Failed to add background context menu registry key!
    pause
    exit /b 1
)

reg add "HKEY_CLASSES_ROOT\Directory\Background\shell\ChangeFolderName\command" /ve /d "powershell.exe -ExecutionPolicy Bypass -File \"%WINDIR%\change-folder-name.ps1\" \"%%V\"" /f
if %errorLevel% neq 0 (
    echo ERROR: Failed to add background context menu command!
    pause
    exit /b 1
)

echo Background context menu added successfully.
echo.

REM Test if the PowerShell script exists and is readable
if exist "%SCRIPT_PATH%" (
    echo PowerShell script verification: OK
) else (
    echo ERROR: PowerShell script was not created properly!
    pause
    exit /b 1
)

echo.
echo ========================================
echo Installation complete!
echo ========================================
echo.
echo The "Change Folder Name" option should now appear when you:
echo 1. Right-click on any folder
echo 2. Right-click in the background of any folder window
echo.
echo The script will look for config.sh in the directory you right-clicked
echo and update the FOLDER_NAME value to match the folder name.
echo.
echo Files created:
echo - PowerShell script: %SCRIPT_PATH%
echo - Registry entries added for context menus
echo.
echo To test: Try right-clicking on a folder and look for "Change Folder Name"
echo To uninstall: Run the uninstall-folder-name-changer.bat file as Administrator
echo.
echo Press any key to exit...
pause > nul
