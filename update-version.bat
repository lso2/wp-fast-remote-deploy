@echo off
setlocal enabledelayedexpansion

:: Look for config.sh in current directory
if not exist "config.sh" (
    echo Error: config.sh not found in current directory
    exit /b 1
)

:: Read settings from config.sh
set "PROJECT_TYPE=unknown"
set "FOLDER_NAME="
set "VERSION_BACKUP_ENABLED=false"
set "VERSION_AUTO_CLOSE=true"

:: Read config file safely
for /f "usebackq tokens=1* delims=:" %%i in (`findstr /n "." "config.sh" 2^>nul`) do (
    set "line=%%j"
    
    :: Skip empty lines and comments
    if not "!line!"=="" if not "!line:~0,1!"=="#" (
        :: Extract TYPE
        echo !line! | findstr /c:"TYPE=" >nul 2>&1
        if !errorlevel! equ 0 (
            echo !line! | findstr /c:"TYPE=\"plugin\"" >nul 2>&1
            if !errorlevel! equ 0 set "PROJECT_TYPE=plugin"
            echo !line! | findstr /c:"TYPE=\"theme\"" >nul 2>&1
            if !errorlevel! equ 0 set "PROJECT_TYPE=theme"
        )
        
        :: Extract FOLDER_NAME
        echo !line! | findstr /b "FOLDER_NAME=" >nul 2>&1
        if !errorlevel! equ 0 (
            for /f "tokens=2 delims==" %%b in ("!line!") do (
                for /f "tokens=1 delims=#" %%c in ("%%b") do (
                    set "temp_name=%%c"
                    set "temp_name=!temp_name:"=!"
                    set "temp_name=!temp_name: =!"
                    set "FOLDER_NAME=!temp_name!"
                )
            )
        )
        
        :: Extract VERSION_BACKUP setting
        echo !line! | findstr /c:"VERSION_BACKUP=" >nul 2>&1
        if !errorlevel! equ 0 (
            echo !line! | findstr /c:"VERSION_BACKUP=\"true\"" >nul 2>&1
            if !errorlevel! equ 0 set "VERSION_BACKUP_ENABLED=true"
        )
		
		:: Extract VERSION_AUTO_CLOSE setting
        echo !line! | findstr /c:"VERSION_AUTO_CLOSE=" >nul 2>&1
        if !errorlevel! equ 0 (
            echo !line! | findstr /c:"VERSION_AUTO_CLOSE=\"false\"" >nul 2>&1
            if !errorlevel! equ 0 set "VERSION_AUTO_CLOSE=false"
        )
    )
)

:: Validate configuration
if "%PROJECT_TYPE%"=="unknown" (
    echo Error: PROJECT_TYPE not found or invalid in config.sh
    exit /b 1
)
if "%FOLDER_NAME%"=="" (
    echo Error: FOLDER_NAME not found in config.sh
    exit /b 1
)
if "%FOLDER_NAME%"=="your-folder-name" (
    echo Error: Please set FOLDER_NAME in config.sh to your actual folder name
    exit /b 1
)

:: Determine target file based on project type
if "%PROJECT_TYPE%"=="plugin" (
    set "TARGET_FILE=%FOLDER_NAME%\%FOLDER_NAME%.php"
) else (
    set "TARGET_FILE=%FOLDER_NAME%\style.css"
)

if not exist "%TARGET_FILE%" (
    echo Error: Target file "%TARGET_FILE%" not found
    echo Make sure the folder name matches your actual plugin/theme folder
    exit /b 1
)

:: Create backup if enabled
if "%VERSION_BACKUP_ENABLED%"=="true" (
    copy "%TARGET_FILE%" "%TARGET_FILE%.backup" >nul 2>&1
    if !errorlevel! equ 0 (
        echo Backup created: %TARGET_FILE%.backup
    )
)

:: Find and replace version numbers using PowerShell for precise replacement
set "updated=false"

if "%PROJECT_TYPE%"=="plugin" (
    :: Find plugin header version
    for /f "tokens=3" %%v in ('findstr /r /c:"^ \* Version:" "%TARGET_FILE%" 2^>nul') do (
        call :increment_version "%%v" new_version
        echo Plugin header version updated: %%v -^> !new_version!
        powershell -Command "(Get-Content '%TARGET_FILE%') -replace '( \* Version: )%%v', '${1}!new_version!' | Set-Content '%TARGET_FILE%'" >nul 2>&1
        set "updated=true"
    )
    
    :: Find define version
    for /f "tokens=4 delims='" %%v in ('findstr /r /c:"define.*VERSION" "%TARGET_FILE%" 2^>nul') do (
        call :increment_version "%%v" new_version
        echo Plugin define version updated: %%v -^> !new_version!
        powershell -Command "(Get-Content '%TARGET_FILE%') -replace \"'%%v'\", \"'!new_version!'\" | Set-Content '%TARGET_FILE%'" >nul 2>&1
        set "updated=true"
    )
) else (
    :: Find CSS version
    for /f "tokens=3" %%v in ('findstr /r /c:"^ \* Version:" "%TARGET_FILE%" 2^>nul') do (
        call :increment_version "%%v" new_version
        echo Theme version updated: %%v -^> !new_version!
        powershell -Command "(Get-Content '%TARGET_FILE%') -replace '( \* Version: )%%v', '${1}!new_version!' | Set-Content '%TARGET_FILE%'" >nul 2>&1
        set "updated=true"
    )
)

if "%updated%"=="false" (
    echo Warning: No version numbers found to update in %TARGET_FILE%
    echo Make sure your file has proper version headers
)

:: Check if should auto-close
if "%VERSION_AUTO_CLOSE%"=="false" (
    echo.
    echo Version update completed.
    pause
)

goto :eof

:increment_version
setlocal
set "version=%~1"

:: Clean and split version - remove any trailing spaces or characters
for /f "tokens=1 delims= " %%i in ("%version%") do set "clean_version=%%i"

:: Handle different version formats (x.y.z, x.y, x)
set "major=1"
set "minor=0"
set "patch=0"

:: Split version by dots
for /f "tokens=1,2,3 delims=." %%a in ("%clean_version%") do (
    if not "%%a"=="" set "major=%%a"
    if not "%%b"=="" set "minor=%%b"
    if not "%%c"=="" set "patch=%%c"
)

:: Ensure numeric values
set /a major=!major! 2>nul || set "major=1"
set /a minor=!minor! 2>nul || set "minor=0"
set /a patch=!patch! 2>nul || set "patch=0"

:: Increment patch version
set /a patch+=1

endlocal & set "%~2=%major%.%minor%.%patch%"
goto :eof