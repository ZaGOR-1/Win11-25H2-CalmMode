@echo off
REM ============================================================
REM Win11 25H2 Calm Mode - double-click launcher for the GUI.
REM
REM This only starts the graphical interface (Win11-25H2-CalmMode-GUI.ps1),
REM which itself defaults to read-only Audit and changes nothing on its own.
REM It is a plain text launcher on purpose: no compiled .exe, no encoded
REM payload, nothing hidden - you can read exactly what it does.
REM ============================================================

setlocal
set "PSEXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "GUI=%~dp0Win11-25H2-CalmMode-GUI.ps1"

if not exist "%GUI%" (
    echo ERROR: GUI script not found next to this launcher:
    echo   "%GUI%"
    echo Keep Win11-25H2-CalmMode-GUI.cmd in the same folder as the .ps1 files.
    pause
    exit /b 1
)

REM -WindowStyle Hidden hides the transient PowerShell console; the GUI window
REM (and any error dialogs) still appear. The GUI runs detached via start.
start "" "%PSEXE%" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%GUI%"
endlocal
