@echo off
REM WordPress Plugin Fast Deployment Script - Windows Launcher
REM Created by: lso2 (https://github.com/lso2)
REM Repository: https://github.com/lso2/wp-fast-remote-deploy
REM License: MIT

cd /d "%~dp0"
echo Starting plugin deployment from %CD%...
echo.

REM Get the current directory path
set "CURRENT_DIR=%~dp0"

REM Extract the drive letter
set "DRIVE_LETTER=%CURRENT_DIR:~0,1%"

REM Convert to lowercase manually
if /I "%DRIVE_LETTER%"=="A" set "DRIVE_LETTER=a"
if /I "%DRIVE_LETTER%"=="B" set "DRIVE_LETTER=b"
if /I "%DRIVE_LETTER%"=="C" set "DRIVE_LETTER=c"
if /I "%DRIVE_LETTER%"=="D" set "DRIVE_LETTER=d"
if /I "%DRIVE_LETTER%"=="E" set "DRIVE_LETTER=e"
if /I "%DRIVE_LETTER%"=="F" set "DRIVE_LETTER=f"
if /I "%DRIVE_LETTER%"=="G" set "DRIVE_LETTER=g"
if /I "%DRIVE_LETTER%"=="H" set "DRIVE_LETTER=h"
if /I "%DRIVE_LETTER%"=="I" set "DRIVE_LETTER=i"
if /I "%DRIVE_LETTER%"=="J" set "DRIVE_LETTER=j"
if /I "%DRIVE_LETTER%"=="K" set "DRIVE_LETTER=k"
if /I "%DRIVE_LETTER%"=="L" set "DRIVE_LETTER=l"
if /I "%DRIVE_LETTER%"=="M" set "DRIVE_LETTER=m"
if /I "%DRIVE_LETTER%"=="N" set "DRIVE_LETTER=n"
if /I "%DRIVE_LETTER%"=="O" set "DRIVE_LETTER=o"
if /I "%DRIVE_LETTER%"=="P" set "DRIVE_LETTER=p"
if /I "%DRIVE_LETTER%"=="Q" set "DRIVE_LETTER=q"
if /I "%DRIVE_LETTER%"=="R" set "DRIVE_LETTER=r"
if /I "%DRIVE_LETTER%"=="S" set "DRIVE_LETTER=s"
if /I "%DRIVE_LETTER%"=="T" set "DRIVE_LETTER=t"
if /I "%DRIVE_LETTER%"=="U" set "DRIVE_LETTER=u"
if /I "%DRIVE_LETTER%"=="V" set "DRIVE_LETTER=v"
if /I "%DRIVE_LETTER%"=="W" set "DRIVE_LETTER=w"
if /I "%DRIVE_LETTER%"=="X" set "DRIVE_LETTER=x"
if /I "%DRIVE_LETTER%"=="Y" set "DRIVE_LETTER=y"
if /I "%DRIVE_LETTER%"=="Z" set "DRIVE_LETTER=z"

REM Remove the drive letter and colon (C:)
set "PATH_NO_DRIVE=%CURRENT_DIR:~2%"

REM Convert backslashes to forward slashes
set "WSL_PATH=%PATH_NO_DRIVE:\=/%"

REM Create the full WSL path with detected drive
set "WSL_DIR=/mnt/%DRIVE_LETTER%%WSL_PATH%"

REM Suppress Perl locale warnings
set "PERL_BADLANG=0"

echo Converted path: %WSL_DIR%

wsl -e bash -c "export PERL_BADLANG=0 && cd '%WSL_DIR%' && chmod +x ./.run/deploy-wsl.sh && ./.run/deploy-wsl.sh"

set "EXIT_CODE=%errorlevel%"

if %EXIT_CODE% equ 0 (
    echo.
    echo ================================
    echo Deployment completed successfully!
    echo ================================
) else (
    echo.
    echo ================================
    echo Deployment failed!
    echo ================================
    echo Exit code: %EXIT_CODE%
    echo.
    echo Press any key to close...
    pause >nul
)