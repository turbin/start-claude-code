@echo off
setlocal enabledelayedexpansion

REM install.bat - Install start-claude-code to a target directory on Windows
REM
REM Usage:
REM   install.bat
REM   install.bat D:\custom\path

REM -- Default install path --
if "%~1"=="" (
  set "INSTALL_DIR=%USERPROFILE%\.local\bin\start-claude-code"
) else (
  set "INSTALL_DIR=%~1"
)

REM -- Resolve source directory --
set "SOURCE_DIR=%~dp0"
REM Strip trailing backslash
if "%SOURCE_DIR:~-1%"=="\" set "SOURCE_DIR=%SOURCE_DIR:~0,-1%"

echo Installing start-claude-code to %INSTALL_DIR% ...
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

REM -- Copy core files --
copy /Y "%SOURCE_DIR%\start-claude-quick.sh"  "%INSTALL_DIR%\" >nul
copy /Y "%SOURCE_DIR%\start-claude-quick.bat" "%INSTALL_DIR%\" >nul
copy /Y "%SOURCE_DIR%\start-claude-quick.nu"  "%INSTALL_DIR%\" >nul
copy /Y "%SOURCE_DIR%\model-env.sh"           "%INSTALL_DIR%\" >nul
copy /Y "%SOURCE_DIR%\model-env.nu"           "%INSTALL_DIR%\" >nul
copy /Y "%SOURCE_DIR%\model-switch.sh"        "%INSTALL_DIR%\" >nul
copy /Y "%SOURCE_DIR%\model-switch.bat"       "%INSTALL_DIR%\" >nul
copy /Y "%SOURCE_DIR%\model-switch.nu"        "%INSTALL_DIR%\" >nul
copy /Y "%SOURCE_DIR%\models.json"            "%INSTALL_DIR%\" >nul
echo Copied core files

REM -- Create or copy .env --
if exist "%SOURCE_DIR%\.env" (
  copy /Y "%SOURCE_DIR%\.env" "%INSTALL_DIR%\.env" >nul
  echo Copied existing .env with API keys
) else (
  (
    echo # Qwen Coding Plan API Key
    echo QWEN_CODING_API_KEY=""
    echo.
    echo # Moonshot / Kimi API Key (optional)
    echo # MOONSHOT_API_KEY=""
  ) > "%INSTALL_DIR%\.env"
  echo Created %INSTALL_DIR%\.env - please edit it to add your API keys
)

REM -- Add to user PATH --
echo "%PATH%" | find /I "%INSTALL_DIR%" >nul 2>nul
if !errorlevel! neq 0 (
  echo Adding %INSTALL_DIR% to user PATH ...
  powershell -NoProfile -Command "$p=[Environment]::GetEnvironmentVariable('PATH','User'); if($p -notlike '*%INSTALL_DIR%*'){[Environment]::SetEnvironmentVariable('PATH',\"$p;%INSTALL_DIR%\",'User')}"
  if !errorlevel! equ 0 (
    echo Added to user PATH - open a NEW terminal to use it
  ) else (
    echo WARNING: Could not modify PATH automatically.
    echo Please add this directory manually: %INSTALL_DIR%
  )
) else (
  echo PATH already contains %INSTALL_DIR%
)

REM -- Add PowerShell profile functions --
for /f "tokens=*" %%p in ('powershell -NoProfile -Command "$profile"') do set "PS_PROFILE=%%p"
if defined PS_PROFILE (
  if not exist "!PS_PROFILE!" type nul > "!PS_PROFILE!"
  findstr /c:"function claude-new" "!PS_PROFILE!" >nul 2>nul
  if !errorlevel! neq 0 (
    echo Adding PowerShell profile functions ...
    (
      echo.
      echo function claude-new { ^& "%INSTALL_DIR%\claude-new.bat" $args }
      echo function claude-resume { ^& "%INSTALL_DIR%\claude-resume.bat" $args }
      echo function model-switch { ^& "%INSTALL_DIR%\model-switch.bat" $args }
    ) >> "!PS_PROFILE!"
    echo Added claude-new / claude-resume / model-switch to PowerShell profile
  ) else (
    echo PowerShell profile functions already configured
  )
)

REM -- Create convenience wrappers --
(
  echo @echo off
  echo call "%INSTALL_DIR%\start-claude-quick.bat" --new
) > "%INSTALL_DIR%\claude-new.bat"

(
  echo @echo off
  echo call "%INSTALL_DIR%\start-claude-quick.bat" --resume
) > "%INSTALL_DIR%\claude-resume.bat"

echo Created claude-new.bat and claude-resume.bat shortcuts

REM -- Summary --
echo.
echo Installation complete!
echo   Directory: %INSTALL_DIR%
echo.
echo Next steps:
echo   1. Edit %INSTALL_DIR%\.env  to add your API keys (if not already set)
echo   2. Open a NEW terminal window  (PATH change takes effect)
echo   3. Use:  claude-new         (start new session)
echo           claude-resume      (resume last session)
echo           model-switch       (list / switch models)
echo   Or:    start-claude-quick  (interactive picker)
echo          start-claude-quick --switch deepseek-v4-flash (one-step switch + launch)
