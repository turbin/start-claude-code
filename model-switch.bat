@echo off
setlocal enabledelayedexpansion

REM model-switch.bat - Windows wrapper for model-switch.sh

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "SH_SCRIPT=%SCRIPT_DIR%\model-switch.sh"

REM -- Find Git Bash --
set "BASH_CMD="

for %%G in (
  "%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
  "%ProgramFiles%\Git\bin\bash.exe"
  "%ProgramFiles(x86)%\Git\bin\bash.exe"
) do (
  if exist "%%~G" (
    set "BASH_CMD=%%~G"
    goto :found_bash
  )
)

where bash >nul 2>nul
if !errorlevel! equ 0 (
  set "BASH_CMD=bash"
  goto :found_bash
)

where wsl >nul 2>nul
if !errorlevel! equ 0 (
  echo [model-switch] Git Bash not found, falling back to WSL...
  wsl bash "%SH_SCRIPT%" %*
  exit /b !errorlevel!
)

echo ERROR: Git Bash is not installed or not in PATH.
echo Please install Git for Windows: https://git-scm.com/download/win
exit /b 1

:found_bash
REM Convert Windows path to Unix-style
set "SH_SCRIPT_BASH=%SH_SCRIPT:\=/%"
for /f "tokens=1,* delims=:" %%A in ("%SH_SCRIPT_BASH%") do (
  set "SH_SCRIPT_BASH=/%%A%%B"
)

"%BASH_CMD%" -l -c "'%SH_SCRIPT_BASH%' %*"
exit /b !errorlevel!
