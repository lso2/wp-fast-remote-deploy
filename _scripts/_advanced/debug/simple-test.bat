@echo off
cd /d "%~dp0\.."

set "CURRENT_DIR=%cd%"
set "PATH_NO_DRIVE=%CURRENT_DIR:~2%"
set "WSL_PATH=%PATH_NO_DRIVE:\=/%"
set "WSL_DIR=/mnt/c%WSL_PATH%"

echo Simple mysqldump test...
wsl -e bash -c "cd '%WSL_DIR%' && chmod +x ./.run/simple-test.sh && ./.run/simple-test.sh"

echo.
echo Press any key to continue...
pause >nul
