@echo off
REM Quick Theme/Plugin Type Switcher
REM This script switches the config.sh TYPE variable between plugin and theme

echo Current TYPE setting:
powershell -Command "Select-String -Path 'config.sh' -Pattern '^TYPE=' | ForEach-Object { $_.Line }"
echo.

echo Switching to THEME deployment mode...

REM Use PowerShell to update the TYPE variable in config.sh
powershell -Command "(Get-Content 'config.sh') -replace '^TYPE=\"plugin\"', 'TYPE=\"theme\"' | Set-Content 'config.sh'"

echo.
echo Updated TYPE setting:
powershell -Command "Select-String -Path 'config.sh' -Pattern '^TYPE=' | ForEach-Object { $_.Line }"
echo.
echo Theme deployment mode activated!
echo.
echo Remember to also update:
echo   - FOLDER_NAME to your theme folder name
echo   - LOCAL_PATH should point to your themes parent directory
echo.
pause
