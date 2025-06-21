@echo off
REM Install Auto-Detecting Folder Switcher Context Menu
REM Run this as Administrator

echo Installing Auto-Detecting Folder Switcher context menu...
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
set SCRIPT_PATH=%WINDIR%\auto-detect-folder-switcher.ps1
set ICON_SOURCE=%~dp0icon\wp-deploy.ico
set ICON_DEST=%WINDIR%\wp-deploy.ico

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
echo # Auto-detect type by checking for Theme Name in style.css
echo $styleCssPath = Join-Path $FolderPath "style.css"
echo $detectedType = "plugin"
echo if ^(Test-Path $styleCssPath^) {
echo     $styleContent = Get-Content $styleCssPath -Raw
echo     if ^($styleContent -match "Theme Name:"^) {
echo         $detectedType = "theme"
echo     }
echo }
echo.
echo $debugInfo += "`nFolder name: '$folderName'`nParent path: '$parentPath'`nDetected type: '$detectedType'`nLooking for config at: '$configPath'"
echo.
echo if ^(-not ^(Test-Path $configPath^)^) {
echo     [System.Windows.Forms.MessageBox]::Show^("config.sh not found!`n`n$debugInfo", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error^)
echo     exit 1
echo }
echo.
echo try {
echo     $content = Get-Content $configPath -Raw
echo     $newContent = $content -replace 'FOLDER_NAME="[^"]*"', "FOLDER_NAME=`"$folderName`""
echo     $newContent = $newContent -replace 'TYPE="[^"]*"', "TYPE=`"$detectedType`""
echo     Set-Content $configPath $newContent -NoNewline
echo.
echo     $deployFiles = @^(Get-ChildItem $parentPath -Name "deploy*.bat"^) + @^(Get-ChildItem $parentPath -Name "DEPLOY*.bat"^)
echo     if ^($deployFiles^) {
echo         $oldPath = Join-Path $parentPath $deployFiles[0]
echo         $newPath = Join-Path $parentPath "DEPLOY__${folderName}__${detectedType}.bat"
echo         if ^(Test-Path $oldPath^) {
echo             Move-Item $oldPath $newPath -Force
echo         }
echo     }
echo.
echo     $typeInfo = if ^($detectedType -eq "theme"^) { "Auto-detected as '$detectedType'" } else { "Auto-detected as '$detectedType'" }
echo     [System.Windows.Forms.MessageBox]::Show^("Successfully updated configuration:`n`nFOLDER_NAME: '$folderName'`nTYPE: $typeInfo`n`nFile: $configPath`nDeploy file renamed to: DEPLOY__${folderName}__${detectedType}.bat`n`n$debugInfo", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information^)
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

REM Copy icon file if it exists
echo Copying icon file...
if exist "%ICON_SOURCE%" (
    copy "%ICON_SOURCE%" "%ICON_DEST%" >nul
    if %errorLevel% equ 0 (
        echo Icon copied successfully to %ICON_DEST%
    ) else (
        echo WARNING: Failed to copy icon file
        echo Icon source: %ICON_SOURCE%
        echo Icon destination: %ICON_DEST%
    )
) else (
    echo WARNING: Icon file not found at %ICON_SOURCE%
    echo Context menu will work but without custom icon
)
echo.

REM Register the context menu entry in the registry
echo Registering context menu entry...

REM Add the main registry key for folder context menu
echo Adding folder context menu...
reg add "HKEY_CLASSES_ROOT\Directory\shell\AutoDetectFolderSwitcher" /ve /d "Switch to This Folder (Fast Deploy)" /f
if %errorLevel% neq 0 (
    echo ERROR: Failed to add folder context menu registry key!
    pause
    exit /b 1
)

REM Add icon if it was copied successfully
if exist "%ICON_DEST%" (
    reg add "HKEY_CLASSES_ROOT\Directory\shell\AutoDetectFolderSwitcher" /v "Icon" /d "%ICON_DEST%" /f
    if %errorLevel% equ 0 (
        echo Icon registered for folder context menu
    ) else (
        echo WARNING: Failed to register icon for folder context menu
    )
)

REM Add the command to execute - Using same format as working version
reg add "HKEY_CLASSES_ROOT\Directory\shell\AutoDetectFolderSwitcher\command" /ve /d "powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File \"%WINDIR%\auto-detect-folder-switcher.ps1\" \"%%1\"" /f
if %errorLevel% neq 0 (
    echo ERROR: Failed to add folder context menu command!
    pause
    exit /b 1
)

echo Folder context menu added successfully.

REM Also add it for background context menu (right-click in empty space)
echo Adding background context menu...
reg add "HKEY_CLASSES_ROOT\Directory\Background\shell\AutoDetectFolderSwitcher" /ve /d "Switch to This Folder (Fast Deploy)" /f
if %errorLevel% neq 0 (
    echo ERROR: Failed to add background context menu registry key!
    pause
    exit /b 1
)

REM Add icon for background context menu too
if exist "%ICON_DEST%" (
    reg add "HKEY_CLASSES_ROOT\Directory\Background\shell\AutoDetectFolderSwitcher" /v "Icon" /d "%ICON_DEST%" /f
    if %errorLevel% equ 0 (
        echo Icon registered for background context menu
    ) else (
        echo WARNING: Failed to register icon for background context menu
    )
)

reg add "HKEY_CLASSES_ROOT\Directory\Background\shell\AutoDetectFolderSwitcher\command" /ve /d "powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File \"%WINDIR%\auto-detect-folder-switcher.ps1\" \"%%V\"" /f
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
echo The "Switch to This Folder (Fast Deploy)" option should now appear when you:
echo 1. Right-click on any plugin or theme folder
echo 2. Right-click in the background of any folder window
echo.
echo Auto-Detection Logic:
echo - If style.css contains "Theme Name:" = THEME
echo - Otherwise = PLUGIN (foolproof detection)
echo.
echo The script will:
echo 1. Update FOLDER_NAME to match the folder name
echo 2. Auto-detect TYPE (plugin/theme) based on "Theme Name:" in style.css
echo 3. Rename deploy file to include folder name and type
echo.
echo Files created:
echo - PowerShell script: %SCRIPT_PATH%
echo - Icon file: %ICON_DEST% (if available)
echo - Registry entries added for context menus
echo.
echo To test: Try right-clicking on a plugin or theme folder
echo To uninstall: Run the uninstall script as Administrator
echo.
echo Press any key to exit...
pause > nul
