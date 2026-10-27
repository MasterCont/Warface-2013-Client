# Клиент Warface RU 1.1.1.426 — документация

Этот каталог описывает готовый клиентский дистрибутив CryEngine 3 build `1.1.1.426` и входящий в него dedicated server. Исходников `Game.exe` и `DedicatedServer.exe` здесь нет: поведение этих программ определяется скомпилированным кодом, DLL, конфигурациями и ресурсами.

## Навигация

| Раздел | Содержание |
|---|---|
| [Архитектура клиента](client-architecture.md) | Роли `Game.exe`, CryOnline, ресурсов и dedicated server |
| [Запуск и параметры](launch-and-parameters.md) | `Start.bat`, Player BAT-файлы и командная строка |
| [Ресурсы и конфигурация](resources-and-config.md) | `Game/`, `Engine/`, `.pak`, XML/CFG и пользовательские данные |
| [Dedicated server](dedicated-server.md) | Запуск игровых серверов и UDP-порты |
| [Логи и диагностика](logs-and-troubleshooting.md) | Логи, маркеры успешного подключения и типовые ошибки |

## Быстрые ссылки на файлы

- [`Start.bat`](../Start.bat) — интерактивный запуск клиента и dedicated server starter.
- [`Bin32Release/Game.exe`](../Bin32Release/Game.exe) — клиентский бинарник.
- [`Bin32Release/DedicatedServer.exe`](../Bin32Release/DedicatedServer.exe) — бинарник игрового сервера.
- [`Bin32Release/DedicatedServersStart.bat`](../Bin32Release/DedicatedServersStart.bat) — запуск набора dedicated-серверов.
- [`Game/config/`](../Game/config/) — CryEngine/Warface-конфигурации.
- [`Game/Levels/`](../Game/Levels/) — уровни и их `.pak`-ресурсы.
- [`Game.log`](../Game.log) — основной лог последнего запуска.

## Связь с серверной документацией

Клиент общается с Node.js backend из соседнего каталога [`Server`](../../Server/). Его серверная документация находится в [Server/docs](../../Server/docs/README.md).

---

Далее: [архитектура клиента](client-architecture.md) · [запуск](launch-and-parameters.md) · [диагностика](logs-and-troubleshooting.md)
