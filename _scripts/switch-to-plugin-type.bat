@echo off
REM Quick Theme/Plugin Type Switcher
REM This script switches the config.sh TYPE variable between theme and plugin

echo Current TYPE setting:
powershell -Command "Select-String -Path 'config.sh' -Pattern '^TYPE=' | ForEach-Object { $_.Line }"
echo.

echo Switching to PLUGIN deployment mode...

REM Use PowerShell to update the TYPE variable in config.sh
powershell -Command "(Get-Content 'config.sh') -replace '^TYPE=\"theme\"', 'TYPE=\"plugin\"' | Set-Content 'config.sh'"

echo.
echo Updated TYPE setting:
powershell -Command "Select-String -Path 'config.sh' -Pattern '^TYPE=' | ForEach-Object { $_.Line }"
echo.
echo Plugin deployment mode activated!
echo.
echo Remember to also update:
echo   - FOLDER_NAME to your plugin folder name
echo   - LOCAL_PATH should point to your plugins parent directory
echo.
pause
