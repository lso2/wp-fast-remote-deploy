@echo off
REM WordPress Fast Deploy - Git Integration Setup Helper
REM Created by: lso2 (https://github.com/lso2)
REM Repository: https://github.com/lso2/wp-fast-remote-deploy
REM License: MIT

cd /d "%~dp0\..\.."
echo.
echo ====================================
echo   Git Integration Setup Helper
echo ====================================
echo.
echo This will help you configure Git integration for your WordPress deployment.
echo.
echo Step 1: Create a GitHub repository for your project
echo Step 2: Generate a Personal Access Token on GitHub
echo         (Go to GitHub Settings ^> Developer Settings ^> Personal Access Tokens)
echo Step 3: Enter the information below
echo.

set /p REPO_URL="Enter your GitHub repository URL: "
set /p TOKEN="Enter your GitHub Personal Access Token: "
set /p AUTO_COMMIT="Enable auto-commit before deployment? (y/N): "

if /i "%AUTO_COMMIT%"=="y" (
    set "AUTO_COMMIT_VALUE=true"
) else (
    set "AUTO_COMMIT_VALUE=false"
)

echo.
echo Updating config.sh...

REM Update Git configuration using PowerShell
powershell -Command "
$content = Get-Content 'config.sh' -Raw;
$content = $content -replace 'GIT_ENABLED=\"false\"', 'GIT_ENABLED=\"true\"';
$content = $content -replace 'GIT_AUTO_COMMIT=\"false\"', 'GIT_AUTO_COMMIT=\"%AUTO_COMMIT_VALUE%\"';
$content = $content -replace 'GIT_REPO_URL=\"\"', 'GIT_REPO_URL=\"%REPO_URL%\"';
$content = $content -replace 'GIT_TOKEN=\"\"', 'GIT_TOKEN=\"%TOKEN%\"';
Set-Content 'config.sh' -Value $content -NoNewline
"

if %errorlevel% equ 0 (
    echo.
    echo ================================
    echo   Git integration configured!
    echo ================================
    echo.
    echo Your deployments will now automatically:
    echo - Commit changes to Git with version info
    echo - Push to your GitHub repository  
    echo - Create full audit trail of deployments
    echo.
    if /i "%AUTO_COMMIT_VALUE%"=="true" (
        echo Auto-commit is ENABLED - changes will be committed before each deployment
    ) else (
        echo Auto-commit is DISABLED - you can manually commit when needed
    )
) else (
    echo.
    echo ================================
    echo   Configuration failed!
    echo ================================
    echo Please check the error above and try again.
)

echo.
echo Press any key to continue...
pause >nul
