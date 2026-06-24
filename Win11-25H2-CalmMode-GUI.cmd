@echo off
chcp 65001 >nul
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
    echo ПОМИЛКА: Скрипт GUI не знайдено поруч із цим лаунчером:
    echo   "%GUI%"
    echo Keep Win11-25H2-CalmMode-GUI.cmd in the same folder as the .ps1 files.
    echo Зберігайте Win11-25H2-CalmMode-GUI.cmd в одній папці з файлами .ps1.
    pause
    exit /b 1
)

REM Використовуємо тимчасовий VBScript для запуску PowerShell у прихованому режимі,
REM щоб уникнути "блимання" чорної консолі.
set "VBS_TEMP=%temp%\Win11-CalmMode-Launch-%RANDOM%.vbs"
echo Set objShell = WScript.CreateObject("WScript.Shell") > "%VBS_TEMP%"
echo objShell.Run """%PSEXE%"" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""%GUI%""", 0, False >> "%VBS_TEMP%"
cscript //nologo "%VBS_TEMP%"
del "%VBS_TEMP%"
endlocal
