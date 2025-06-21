@echo off
REM WordPress Fast Deploy - Fix Line Endings Utility
REM Converts Windows line endings (CRLF) to Unix line endings (LF)
REM Created by: lso2 (https://github.com/lso2)

cd /d "%~dp0"
cd ..\..\..
echo.
echo ====================================
echo   Fix Line Endings - WSL Compatibility
echo ====================================
echo.

echo Converting Windows line endings to Unix line endings...
echo.

REM Fix config.sh line endings
if exist "config.sh" (
    echo Fixing config.sh...
    powershell -Command "(Get-Content 'config.sh' -Raw) -replace '`r`n', '`n' | Set-Content 'config.sh' -NoNewline"
    echo ✅ config.sh fixed
) else (
    echo ❌ config.sh not found
)

REM Fix all shell scripts in .run directory
if exist ".run" (
    echo.
    echo Fixing shell scripts in .run directory...
    
    for %%f in (.run\*.sh) do (
        echo Fixing %%f...
        powershell -Command "(Get-Content '%%f' -Raw) -replace '`r`n', '`n' | Set-Content '%%f' -NoNewline"
        echo ✅ %%f fixed
    )
) else (
    echo ❌ .run directory not found
)

echo.
echo ====================================
echo   Line ending conversion complete!
echo ====================================
echo.
echo All files now have Unix line endings (LF) and should work with WSL.
echo.
echo Alternative: You can also use this WSL command:
echo sed -i 's/\r$//' config.sh
echo.
echo You can now run:
echo - deploy.bat
echo - _scripts/db-backup.bat
echo - _scripts/db-restore.bat
echo - _scripts/rollback.bat
echo.
pause
