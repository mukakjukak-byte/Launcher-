# CRMP / SAMP Launcher

Лаунчер для сервера **188.127.241.74:2626**. Две версии: **ПК (Windows)** и **Android**.

---

# 💻 ПК-лаунчер (`pc/`)

Лёгкий лаунчер на C# / .NET Framework 4.8 — около 20 МБ ОЗУ, работает на слабых ПК (2 ГБ).

**Скачать:** Releases → `launcher-pc` → `Launcher.exe` (собирается GitHub Actions при каждом изменении в `pc/`).

**Что нужно игроку:** своя GTA San Andreas для ПК (версия 1.0 US) + SA-MP 0.3.7.

**Что умеет:**
- онлайн, пинг, название и мод сервера (обновление раз в 15 сек);
- копирование адреса;
- ник (сохраняется, пишется в реестр SA-MP);
- сам находит папку GTA SA (реестр SA-MP / стандартные пути) или выбор вручную;
- свой кэш из релиза `cache-pc` → распаковывается в папку игры, качается только при новой версии;
- запуск: `samp.exe 188.127.241.74:2626`, а если samp.exe нет — `gta_sa.exe` + `samp.dll`;
- «закрыть лаунчер после запуска», чтобы не занимать память.

Настройки — `pc/Launcher/Config.cs`. Кэш — папка `cache-pc/` и
**Actions → Publish cache → target: pc**.

---

# 📱 Android-лаунчер (`app/`)

## Что умеет
- Показывает онлайн, пинг, название и мод сервера (SA-MP query, обновление раз в 15 сек).
- Копирование адреса сервера.
- Ввод и сохранение ника (Имя_Фамилия).
- **Свой кэш**: качает `cache.zip` из GitHub-релиза `cache`, распаковывает в `/sdcard/CRMP/`,
  перекачивает только когда меняется версия (`version.txt`).
- Пишет `/sdcard/CRMP/SAMP/settings.ini` (`name`, `host`, `port`) и запускает клиент игры
  (также передаёт `host`, `port`, `nick` через Intent extras).

## Как получить APK
Сборка идёт через **GitHub Actions** автоматически при каждом пуше
(workflow `Build APK`). Готовый файл:
- **Releases → `launcher` → `CrmpLauncher.apk`** — можно скачать прямо с телефона;
- или Actions → последний запуск → Artifacts.

## Как выложить кэш
См. [`cache/README.md`](cache/README.md): кладёшь файлы в `cache/` (или даёшь ссылку на zip)
и запускаешь **Actions → Publish cache → Run workflow**.

## Настройки
Всё в [`app/src/main/java/com/crmp/launcher/Config.kt`](app/src/main/java/com/crmp/launcher/Config.kt):

| Поле | Что это |
|---|---|
| `SERVER_IP`, `SERVER_PORT` | адрес сервера |
| `GAME_PACKAGE` | package name APK клиента (GTA SA + CRMP/SAMP mobile), который запускается кнопкой «Играть» |
| `CACHE_FOLDER` | папка на телефоне для кэша (`/sdcard/CRMP`) |
| `CLIENT_APK_URL` | откуда скачать клиент, если он не установлен (по умолчанию `client.apk` в релизе `cache`) |

Название лаунчера — `app/src/main/res/values/strings.xml`, цвета — `res/values/colors.xml`.
