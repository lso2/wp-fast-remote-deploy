@echo off
setlocal enabledelayedexpansion

:: Look for config.sh in current directory
if not exist "config.sh" exit /b 1

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
        echo !line! | findstr /c:"FOLDER_NAME=" >nul 2>&1
        if !errorlevel! equ 0 (
            for /f "tokens=2 delims==" %%b in ("!line!") do (
                set "temp_line=%%b"
                for /f "tokens=1 delims=#" %%c in ("!temp_line!") do (
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

if "%PROJECT_TYPE%"=="unknown" exit /b 1
if "%FOLDER_NAME%"=="" exit /b 1

:: Determine target file based on project type
if "%PROJECT_TYPE%"=="plugin" (
    set "TARGET_FILE=%FOLDER_NAME%\%FOLDER_NAME%.php"
) else (
    set "TARGET_FILE=%FOLDER_NAME%\style.css"
)

if not exist "%TARGET_FILE%" exit /b 1

:: Create backup if enabled
if "%VERSION_BACKUP_ENABLED%"=="true" (
    copy "%TARGET_FILE%" "%TARGET_FILE%.backup" >nul 2>&1
)

:: Find and replace version numbers using PowerShell for precise replacement
if "%PROJECT_TYPE%"=="plugin" (
    :: Find plugin header version
    for /f "tokens=3" %%v in ('findstr /r /c:"^ \* Version:" "%TARGET_FILE%" 2^>nul') do (
        call :increment_version "%%v" new_version
        echo Plugin header version: %%v -^> !new_version!
        powershell -Command "(Get-Content '%TARGET_FILE%') -replace '( \* Version: )%%v', '${1}!new_version!' | Set-Content '%TARGET_FILE%'" >nul 2>&1
    )
    
    :: Find define version
    for /f "tokens=4 delims='" %%v in ('findstr /r /c:"define.*TR_COMMENT_SYSTEM_VERSION" "%TARGET_FILE%" 2^>nul') do (
        call :increment_version "%%v" new_version
        echo Plugin define version: %%v -^> !new_version!
        powershell -Command "(Get-Content '%TARGET_FILE%') -replace \"'%%v'\", \"'!new_version!'\" | Set-Content '%TARGET_FILE%'" >nul 2>&1
    )
) else (
    :: Find CSS version
    for /f "tokens=3" %%v in ('findstr /r /c:"^ \* Version:" "%TARGET_FILE%" 2^>nul') do (
        call :increment_version "%%v" new_version
        echo Theme version: %%v -^> !new_version!
        powershell -Command "(Get-Content '%TARGET_FILE%') -replace \"%%v\", \"!new_version!\" | Set-Content '%TARGET_FILE%'" >nul 2>&1
    )
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

:: Clean and split version
for /f "tokens=1 delims= " %%i in ("%version%") do set "clean_version=%%i"
for /f "tokens=1,2,3 delims=." %%a in ("%clean_version%") do (
    set "major=%%a"
    set "minor=%%b"
    set "patch=%%c"
)

:: Set defaults if missing
if not defined patch set "patch=0"
if not defined minor set "minor=0"
if not defined major set "major=1"

:: Increment patch version
set /a patch+=1

endlocal & set "%~2=%major%.%minor%.%patch%"
goto :eof