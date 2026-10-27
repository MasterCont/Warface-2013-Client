# Архитектура клиентского дистрибутива

## Слои

```text
Game.exe
  ├─ CrySystem / CryEntitySystem / CryAISystem
  ├─ CryOnline ── TCP/XMPP ── XmppServerTcp/Masterserver
  ├─ Scaleform UI и локальные игровые состояния
  └─ CryNetwork ── UDP ── DedicatedServer.exe

Engine/*.pak + Game/*.pak + Game/Levels/*/*.pak
  └─ графика, звук, UI, оружие, персонажи, уровни и XML-данные
```

## `Game.exe`

Клиент отвечает за:

- рендеринг и ввод;
- интерфейс Scaleform/Flash;
- локальную загрузку уровней и `.pak`;
- XMPP-авторизацию и лобби через CryOnline;
- соединение с dedicated server через CryNetwork;
- локальные настройки и логи.

`Game.exe` не содержит серверный профиль в себе. Профиль, магазин, предметы и комнаты приходят XML-ответами Masterserver.

## `DedicatedServer.exe`

Это отдельный headless/удалённый экземпляр CryEngine. Он отвечает за авторитетную игровую сессию:

- игровой мир;
- AI и физику;
- урон, стрельбу и правила режима;
- синхронизацию игроков по UDP;
- загрузку базового уровня и sublevel.

Он использует XMPP только для регистрации/служебного управления и не заменяет Masterserver.

## Сетевые пути

| Направление | Транспорт | Назначение |
|---|---|---|
| `Game.exe → Masterserver` | TLS/XMPP TCP `5222` | авторизация, профиль, лобби |
| `Masterserver → Game.exe` | XMPP request/push | ответы и события |
| `DedicatedServer.exe → XmppServerTcp` | XMPP TCP `5224` | регистрация сервера и команды |
| `Game.exe ↔ DedicatedServer.exe` | CryNetwork UDP `64000+` | игровой матч |

## Клиентский поток

1. BAT-файл регистрирует временный токен через API backend.
2. `Game.exe` подключается к `online_server` и проходит SASL.
3. CryOnline получает профиль, предметы, магазин и миссии.
4. Клиент загружает локальный уровень `hideout` и открывает lobby UI.
5. При старте матча получает внешний адрес dedicated server.
6. CryNetwork загружает уровень и устанавливает UDP-сессию.
7. После матча Masterserver присылает обновлённые награды и профиль.

## Что нельзя изменить этим дистрибутивом

Без исходников невозможно полноценно изменить:

- внутреннюю логику `Game.exe`;
- правила AI/физики в бинарном dedicated server;
- сетевой протокол CryNetwork;
- Scaleform-код, зашитый в бинарники и `.pak`.

Можно менять BAT-файлы, доступные CFG/XML и серверные ответы, но это не является заменой исходного кода игры.

---

[← оглавление](README.md) · [запуск →](launch-and-parameters.md) · [серверная архитектура](../../Server/docs/architecture.md)
