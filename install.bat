@echo off
setlocal enabledelayedexpansion

REM install.bat — Install start-claude-code to a target directory on Windows
REM
REM Usage:
REM   install.bat                     REM install to default location
REM   install.bat D:\custom\path      REM install to custom location

REM ══ Default install path ═══════════════════════════════════════
if "%~1"=="" (
  set "INSTALL_DIR=%USERPROFILE%\.local\bin\start-claude-code"
) else (
  set "INSTALL_DIR=%~1"
)

REM ══ Resolve source directory ══════════════════════════════════
set "SOURCE_DIR=%~dp0"
REM Strip trailing backslash
if "%SOURCE_DIR:~-1%"=="\" set "SOURCE_DIR=%SOURCE_DIR:~0,-1%"

echo Installing start-claude-code to %INSTALL_DIR% ...
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

REM ══ Copy core files ═══════════════════════════════════════════
copy /Y "%SOURCE_DIR%\start-claude-quick.sh"  "%INSTALL_DIR%\" >nul
if %errorlevel% equ 0 (echo   Copied start-claude-quick.sh) else (echo   FAILED: start-claude-quick.sh)

copy /Y "%SOURCE_DIR%\start-claude-quick.bat" "%INSTALL_DIR%\" >nul
if %errorlevel% equ 0 (echo   Copied start-claude-quick.bat) else (echo   FAILED: start-claude-quick.bat)

copy /Y "%SOURCE_DIR%\model-env.sh"           "%INSTALL_DIR%\" >nul
if %errorlevel% equ 0 (echo   Copied model-env.sh)           else (echo   FAILED: model-env.sh)

copy /Y "%SOURCE_DIR%\models.json"            "%INSTALL_DIR%\" >nul
if %errorlevel% equ 0 (echo   Copied models.json)            else (echo   FAILED: models.json)

REM ══ Create or copy .env ═══════════════════════════════════════
if exist "%SOURCE_DIR%\.env" (
  copy /Y "%SOURCE_DIR%\.env" "%INSTALL_DIR%\.env" >nul
  echo Copied existing .env with API keys
) else (
  (
    echo # Qwen Coding Plan API Key
    echo QWEN_CODING_API_KEY=""
    echo.
    echo # Moonshot / Kimi API Key ^(optional^)
    echo REM MOONSHOT_API_KEY=""
  ) > "%INSTALL_DIR%\.env"
  echo Created %INSTALL_DIR%\.env — please edit it to add your API keys
)

REM ══ Add to user PATH ══════════════════════════════════════════
REM Check if INSTALL_DIR is already in the user PATH
echo "%PATH%" | find /I "%INSTALL_DIR%" >nul 2>nul
if %errorlevel% neq 0 (
  echo Adding %INSTALL_DIR% to user PATH ...
  REM Use PowerShell to modify the user PATH registry value
  powershell -NoProfile -Command "$p = [Environment]::GetEnvironmentVariable('PATH', 'User'); if ($p -notlike '*%INSTALL_DIR%*') { [Environment]::SetEnvironmentVariable('PATH', \"$p;%INSTALL_DIR%\", 'User') }"
  if %errorlevel% equ 0 (
    echo Added to user PATH — open a NEW terminal to use it
  ) else (
    echo WARNING: Could not modify PATH automatically.
    echo Please add this directory manually: %INSTALL_DIR%
  )
) else (
  echo PATH already contains %INSTALL_DIR%
)

REM ══ Create convenience shortcuts ══════════════════════════════
REM Create claude-new.bat and claude-resume.bat wrappers in INSTALL_DIR
(
  echo @echo off
  echo "%INSTALL_DIR%\start-claude-quick.bat" --new
) > "%INSTALL_DIR%\claude-new.bat"

(
  echo @echo off
  echo "%INSTALL_DIR%\start-claude-quick.bat" --resume
) > "%INSTALL_DIR%\claude-resume.bat"

echo   Created claude-new.bat and claude-resume.bat shortcuts

REM ══ Summary ═══════════════════════════════════════════════════
echo.
echo Installation complete!
echo   Directory: %INSTALL_DIR%
echo.
echo Next steps:
echo   1. Edit %INSTALL_DIR%\.env  to add your API keys ^(if not already set^)
echo   2. Open a NEW terminal window  ^(PATH change takes effect^)
echo   3. Use:  claude-new         REM start new session
echo           claude-resume      REM resume last session
echo   Or:    start-claude-quick  REM interactive picker
