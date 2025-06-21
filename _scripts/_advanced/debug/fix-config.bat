@echo off
REM Quick fix for config.sh line endings
cd /d "%~dp0"
cd ..\..\..

echo Fixing config.sh line endings for WSL compatibility...
echo.

REM Method 1: PowerShell fix
if exist "config.sh" (
    echo Using PowerShell to fix line endings...
    powershell -Command "(Get-Content 'config.sh' -Raw) -replace '`r`n', '`n' | Set-Content 'config.sh' -NoNewline"
    echo ✅ config.sh line endings fixed with PowerShell!
) else (
    echo ❌ config.sh not found
)

echo.
echo Alternative: You can also use this command in WSL:
echo sed -i 's/\r$//' config.sh
echo.
echo You can now run database backup tools without line ending errors.
pause
