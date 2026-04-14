@echo off
REM start-claude-quick.bat — Windows wrapper for start-claude-quick.sh
REM Launches the shell script via Git Bash, falling back to WSL then
REM plain sh if Git Bash is not available.
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "SH_SCRIPT=%SCRIPT_DIR%start-claude-quick.sh"

REM ── Find Git Bash ─────────────────────────────────────────────
set "BASH_CMD="

REM Check common Git Bash locations
for %%G in (
  "%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
  "%ProgramFiles%\Git\bin\bash.exe"
  "%ProgramFiles(x86)%\Git\bin\bash.exe"
) do (
  if exist "%%~G\bash.exe" (
    set "BASH_CMD=%%~G\bash.exe"
    goto :found_bash
  )
)

REM Check if bash is in PATH
where bash >nul 2>nul
if %errorlevel% equ 0 (
  set "BASH_CMD=bash"
  goto :found_bash
)

REM Try WSL bash as last resort
where wsl >nul 2>nul
if %errorlevel% equ 0 (
  echo [start-claude] Git Bash not found, falling back to WSL...
  wsl bash "%SH_SCRIPT%" %*
  exit /b %errorlevel%
)

echo ERROR: Git Bash is not installed or not in PATH.
echo Please install Git for Windows: https://git-scm.com/download/win
exit /b 1

:found_bash
REM ── Launch ────────────────────────────────────────────────────
REM Convert script path to Git Bash Unix-style:
REM   D:\workspace\foo.sh → /d/workspace/foo.sh
set "SH_SCRIPT_BASH=%SH_SCRIPT:\=/%"
for /f "tokens=1,* delims=:" %%A in ("%SH_SCRIPT_BASH%") do (
  set "SH_SCRIPT_BASH=/%%A%%B"
)

"%BASH_CMD%" -l -c "'%SH_SCRIPT_BASH%' %*"
exit /b %errorlevel%
