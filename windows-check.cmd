@echo off
chcp 65001 >nul
rem Проверки Windows перед запуском игры. Вызывается из Start.bat:
rem     call "%~dp0windows-check.cmd" || exit /b 1
setlocal
set "GAME_ROOT=%~dp0"

rem 1. Снять пометку «скачано из интернета» (Mark of the Web) со всех файлов игры.
rem    С ней Windows строже проверяет старые неподписанные DLL игры (CryOnline.dll и др.).
rem    Обход 8000+ файлов занимает секунды, поэтому делается один раз: отметка — файл Bin32Release\.unblocked.
rem    Если игру скачали заново (новая папка), отметки нет и проверка повторится.
if not exist "%GAME_ROOT%Bin32Release\.unblocked" (
    echo   Первый запуск: подготовка файлов игры...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%GAME_ROOT%' -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue" >nul 2>&1
    type nul > "%GAME_ROOT%Bin32Release\.unblocked"
)

rem 2. Smart App Control (Windows 11): при значении 1 блокирует неподписанные DLL игры,
rem    игра падает с ошибкой «Недопустимый образ» / «Ungültiges Bild», код 0xc0e90002.
set "SAC_STATE="
for /f "tokens=3" %%v in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy" /v VerifiedAndReputablePolicyState 2^>nul ^| find "VerifiedAndReputablePolicyState"') do set "SAC_STATE=%%v"
if /i "%SAC_STATE%"=="0x1" goto :smart_app_control
exit /b 0

:smart_app_control
echo.
echo  ============================================================================
echo   Игра не сможет запуститься: в Windows включено
echo   «Интеллектуальное управление приложениями» (Smart App Control).
echo  ============================================================================
echo.
echo   Эта защита Windows 11 блокирует старые файлы игры 2013 года, у которых нет
echo   цифровой подписи. Игра покажет ошибку «Недопустимый образ» про CryOnline.dll
echo   с кодом 0xc0e90002.
echo.
echo   Как выключить:
echo     Безопасность Windows ^> Управление приложениями/браузером ^>
echo     Интеллектуальное управление приложениями ^> Выкл.
echo     (English: App ^& browser control ^> Smart App Control ^> Off;
echo      Deutsch: App- ^& Browsersteuerung ^> Intelligente App-Steuerung ^> Aus)
echo.
echo   ВАЖНО: обратно эту функцию Windows включить нельзя без переустановки
echo   системы. Остальная защита (антивирус Microsoft Defender, брандмауэр)
echo   продолжит работать.
echo.
choice /c YN /n /m "  Открыть нужный раздел настроек сейчас? [Y/N] "
if errorlevel 2 goto :stop
start "" "windowsdefender://appbrowser/"
:stop
echo.
echo   После выключения запустите игру заново.
pause
exit /b 1
