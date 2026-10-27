@ECHO OFF
chcp 65001 >nul
setlocal

rem Script by MasterCont. Вход через API сервера, затем запуск Game.exe с одноразовым токеном
set "WF_API=https://api.wf.suboot.pro"

title Warface 2013 - Suboot Games
echo.
echo   ===========================================
echo     Warface 2013  -  Suboot Games
echo   ===========================================
echo.
echo     Загрузка лаунчера...
echo.
rem Проверка Windows: снимает пометку «из интернета» и предупреждает о Smart App Control
call "%~dp0windows-check.cmd" || exit /b 1

set "WF_OUT=%TEMP%\wf-login-%RANDOM%.txt"
del "%WF_OUT%" 2>nul
rem Меню, вход и сохранённая сессия — PowerShell-часть в конце этого файла
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex (((Get-Content -LiteralPath '%~f0' -Raw -Encoding UTF8) -split '#PS-BEGIN#')[2])"
if not exist "%WF_OUT%" exit /b 0
for /f "usebackq tokens=1-4" %%a in ("%WF_OUT%") do (
    set "uid=%%a"
    set "token=%%b"
    set "server=%%c"
    set "port=%%d"
)
del "%WF_OUT%" 2>nul

echo.
echo  Запуск игры...
start "" "%~dp0Bin32Release\Game.exe" -devmode -uid %uid% -token 1.1.1.426~%token% +online_server %server% +online_server_port %port% +online_use_protect 0 +online_check_certificate 0 +online_use_tls 1
timeout /t 3 >nul
exit /b 0

#PS-BEGIN#
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$api = $env:WF_API
# Сессия «запомнить меня» зашифрована DPAPI: прочитать её может только этот пользователь Windows на этом ПК
$sessionDir = Join-Path $env:APPDATA 'SubootGames'
$sessionFile = Join-Path $sessionDir 'warface.session'

function Read-Secret([string]$prompt) {
    $secure = Read-Host -Prompt $prompt -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

function Call-Api([string]$path, $body) {
    $json = [Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Compress))
    try {
        return (Invoke-RestMethod -Method Post -Uri ($api + $path) -Body $json -ContentType 'application/json; charset=utf-8' -TimeoutSec 20).data
    } catch {
        $reason = $_.Exception.Message
        $code = 0
        if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            try { $reason = ($_.ErrorDetails.Message | ConvertFrom-Json).reason } catch {}
        }
        $err = New-Object Exception $reason
        $err.Data['code'] = $code
        throw $err
    }
}

function Save-Session([string]$session) {
    New-Item -ItemType Directory -Force $sessionDir | Out-Null
    ConvertTo-SecureString $session -AsPlainText -Force | ConvertFrom-SecureString | Set-Content -LiteralPath $sessionFile -Encoding ASCII
}

function Load-Session {
    if (-not (Test-Path -LiteralPath $sessionFile)) { return $null }
    try {
        $secure = (Get-Content -LiteralPath $sessionFile -Raw).Trim() | ConvertTo-SecureString
        $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
    } catch { Remove-Item -LiteralPath $sessionFile -ErrorAction SilentlyContinue; return $null }
}

function Forget-Session {
    Remove-Item -LiteralPath $sessionFile -ErrorAction SilentlyContinue
}

$serverFile = Join-Path $sessionDir 'warface.server'

function Get-Servers {
    try { return @((Invoke-RestMethod -Uri ($api + '/v1/servers') -TimeoutSec 10).data) } catch { return @() }
}

# Выбранный сервер запоминается; по умолчанию — первый доступный
function Pick-Server($servers) {
    $saved = if (Test-Path -LiteralPath $serverFile) { (Get-Content -LiteralPath $serverFile -Raw).Trim() } else { '' }
    $found = $servers | Where-Object { $_.id -eq $saved } | Select-Object -First 1
    if (-not $found) { $found = $servers | Where-Object { $_.state -ne 'offline' } | Select-Object -First 1 }
    if (-not $found) { $found = $servers | Select-Object -First 1 }
    return $found
}

function Show-Servers($servers, $selected) {
    if (-not $servers.Count) {
        Write-Host '    Список серверов недоступен' -ForegroundColor Red
        return
    }
    Write-Host '    Серверы:'
    foreach ($srv in $servers) {
        $mark = if ($selected -and $srv.id -eq $selected.id -and $servers.Count -gt 1) { '>' } else { ' ' }
        switch ($srv.state) {
            'online' { $color = 'Green'; $text = 'работает' }
            'degraded' { $color = 'Yellow'; $text = 'работает частично' }
            default { $color = 'Red'; $text = 'недоступен' }
        }
        $players = if ($srv.online -ne $null) { ', игроков: ' + $srv.online } else { '' }
        Write-Host ('    {0} ' -f $mark) -NoNewline
        Write-Host '●' -ForegroundColor $color -NoNewline
        Write-Host (' {0} ({1}) — {2}{3}' -f $srv.name, $srv.host, $text, $players)
    }
    Write-Host ''
}

function Choose-Server($servers) {
    for ($i = 0; $i -lt $servers.Count; $i++) { Write-Host ('    {0}. {1} ({2})' -f ($i + 1), $servers[$i].name, $servers[$i].host) }
    $n = [int](Read-Host '  Номер сервера') - 1
    if ($n -ge 0 -and $n -lt $servers.Count) {
        New-Item -ItemType Directory -Force $sessionDir | Out-Null
        Set-Content -LiteralPath $serverFile -Value $servers[$n].id -Encoding ASCII
    }
}

function Launch($session, $server) {
    $hostName = if ($server) { $server.host } else { $session.game.server }
    $port = if ($server) { $server.port } else { $session.game.port }
    $line = '{0} {1} {2} {3}' -f $session.uid, $session.token, $hostName, $port
    [IO.File]::WriteAllText($env:WF_OUT, $line)
}

# Смена пароля завершает все сессии; если вход был запомнен — входим заново и сохраняем новую
function Change-Password([string]$login, [bool]$keepSession) {
    if (-not $login) { $login = Read-Host -Prompt '  Логин' }
    $old = Read-Secret '  Текущий пароль'
    $new = Read-Secret '  Новый пароль'
    if ($new -ne (Read-Secret '  Повторите новый пароль')) { throw 'Пароли не совпадают' }
    Call-Api '/v1/auth/password' @{ login = $login; password = $old; new_password = $new } | Out-Null
    if ($keepSession) {
        $logged = Call-Api '/v1/auth/login' @{ login = $login; password = $new; remember = $true }
        Save-Session $logged.session
    }
    Write-Host '  Пароль изменён.' -ForegroundColor Green
    Start-Sleep -Seconds 2
}

function Show-Account($me) {
    Write-Host ('    Аккаунт: {0} (uid {1})' -f $me.login, $me.uid)
    if ($me.profile) {
        $p = $me.profile
        $clan = if ($p.clan) { '   Клан: ' + $p.clan } else { '' }
        Write-Host ('    Персонаж: {0}   Ранг: {1}   Опыт: {2:N0}{3}' -f $p.nick, $p.rank, $p.experience, $clan) -ForegroundColor Yellow
        Write-Host ('    Варбаксы: {0:N0}   Кредиты: {1:N0}   Короны: {2:N0}' -f $p.money.game, $p.money.cry, $p.money.crown)
    } else {
        Write-Host '    Персонаж ещё не создан: игра предложит выбрать ник при первом входе.'
    }
}

function Header {
    Clear-Host
    Write-Host '  ==========================================='
    Write-Host '    Warface 2013  -  Suboot Games'
    Write-Host '  ==========================================='
    Write-Host ''
}

while ($true) {
    $session = Load-Session
    $me = $null
    if ($session) {
        try { $me = Call-Api '/v1/auth/me' @{ session = $session } }
        catch {
            if ($_.Exception.Data['code'] -eq 401) { Forget-Session; $session = $null }
            else { Header; Write-Host ('  Сервер недоступен: ' + $_.Exception.Message) -ForegroundColor Red; Read-Host '  Enter — повторить' | Out-Null; continue }
        }
    }

    # @() — иначе PowerShell превращает список из одного сервера в одиночный объект без .Count
    $servers = @(Get-Servers)
    $server = Pick-Server $servers
    Header
    Show-Servers $servers $server
    try {
        if ($me) {
            Show-Account $me
            Write-Host ''
            Write-Host '    1. Играть'
            Write-Host '    2. Сменить пароль'
            Write-Host '    3. Выйти из аккаунта'
            if ($servers.Count -gt 1) { Write-Host '    4. Выбрать сервер' }
            Write-Host '    0. Закрыть'
            Write-Host ''
            $choice = Read-Host '  Выберите действие [1]'
            if (-not $choice) { $choice = '1' }
            switch ($choice) {
                '1' {
                    if ($server -and $server.state -eq 'offline') { throw ('Сервер {0} сейчас недоступен' -f $server.name) }
                    Launch (Call-Api '/v1/auth/session' @{ session = $session }) $server
                    return
                }
                '2' { Change-Password $me.login $true }
                '4' { if ($servers.Count -gt 1) { Choose-Server $servers } }
                '3' { try { Call-Api '/v1/auth/logout' @{ session = $session } | Out-Null } catch {}; Forget-Session }
                '0' { return }
            }
        } else {
            Write-Host '    1. Войти'
            Write-Host '    2. Регистрация'
            Write-Host '    3. Сменить пароль'
            Write-Host '    0. Закрыть'
            Write-Host ''
            $choice = Read-Host '  Выберите действие [1]'
            if (-not $choice) { $choice = '1' }
            if ($choice -eq '0') { return }
            if ($choice -eq '3') { Write-Host ''; Change-Password '' $false; continue }
            if ($choice -ne '1' -and $choice -ne '2') { continue }
            Write-Host ''
            $login = Read-Host -Prompt '  Логин'
            $password = Read-Secret '  Пароль'
            if ($choice -eq '2') {
                if ($password -ne (Read-Secret '  Повторите пароль')) { throw 'Пароли не совпадают' }
                # Сервер частный: регистрация по одноразовому ключу приглашения от администратора
                $invite = ''
                try { $mode = (Invoke-RestMethod -Uri ($api + '/v1/auth/registration') -TimeoutSec 10).data.mode } catch { $mode = 'invite' }
                if ($mode -eq 'closed') { throw 'Регистрация закрыта: аккаунт выдаёт администратор' }
                if ($mode -eq 'invite') { $invite = Read-Host -Prompt '  Ключ приглашения (WF-XXXX-XXXX-XXXX)' }
                $created = Call-Api '/v1/auth/register' @{ login = $login; password = $password; invite = $invite }
                Write-Host ("  Аккаунт создан (uid {0})." -f $created.uid) -ForegroundColor Green
            }
            $remember = (Read-Host '  Запомнить вход на этом компьютере? (Д/н)') -notmatch '^[нНnN]'
            $logged = Call-Api '/v1/auth/login' @{ login = $login; password = $password; remember = $remember }
            if ($remember) {
                Save-Session $logged.session
            } else {
                Launch $logged $server
                return
            }
        }
    } catch {
        Write-Host ('  Ошибка: ' + $_.Exception.Message) -ForegroundColor Red
        Read-Host '  Enter — продолжить' | Out-Null
    }
}
