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
REM Convert script directory to Git Bash Unix-style with lowercase drive letter:
set "SH_DIR_BASH=%SCRIPT_DIR:\=/%"
for /f "tokens=1,* delims=:" %%A in ("%SH_DIR_BASH%") do (
  set "DRIVE_UPPER=%%A"
  set "REST=%%B"
)
set "DRIVE_LOWER=%DRIVE_UPPER:A=a%"
set "DRIVE_LOWER=%DRIVE_LOWER:B=b%"
set "DRIVE_LOWER=%DRIVE_LOWER:C=c%"
set "DRIVE_LOWER=%DRIVE_LOWER:D=d%"
set "DRIVE_LOWER=%DRIVE_LOWER:E=e%"
set "DRIVE_LOWER=%DRIVE_LOWER:F=f%"
set "DRIVE_LOWER=%DRIVE_LOWER:G=g%"
set "DRIVE_LOWER=%DRIVE_LOWER:H=h%"
set "DRIVE_LOWER=%DRIVE_LOWER:I=i%"
set "DRIVE_LOWER=%DRIVE_LOWER:J=j%"
set "DRIVE_LOWER=%DRIVE_LOWER:K=k%"
set "DRIVE_LOWER=%DRIVE_LOWER:L=l%"
set "DRIVE_LOWER=%DRIVE_LOWER:M=m%"
set "DRIVE_LOWER=%DRIVE_LOWER:N=n%"
set "DRIVE_LOWER=%DRIVE_LOWER:O=o%"
set "DRIVE_LOWER=%DRIVE_LOWER:P=p%"
set "DRIVE_LOWER=%DRIVE_LOWER:Q=q%"
set "DRIVE_LOWER=%DRIVE_LOWER:R=r%"
set "DRIVE_LOWER=%DRIVE_LOWER:S=s%"
set "DRIVE_LOWER=%DRIVE_LOWER:T=t%"
set "DRIVE_LOWER=%DRIVE_LOWER:U=u%"
set "DRIVE_LOWER=%DRIVE_LOWER:V=v%"
set "DRIVE_LOWER=%DRIVE_LOWER:W=w%"
set "DRIVE_LOWER=%DRIVE_LOWER:X=x%"
set "DRIVE_LOWER=%DRIVE_LOWER:Y=y%"
set "DRIVE_LOWER=%DRIVE_LOWER:Z=z%"
set "SH_DIR_BASH=/%DRIVE_LOWER%%REST%"

REM cd into script dir first so BASH_SOURCE resolves correctly
"%BASH_CMD%" -l -c "cd '%SH_DIR_BASH%' && ./model-switch.sh %*"
exit /b !errorlevel!
