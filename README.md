# CRMP / SAMP Launcher для Android

Лаунчер для сервера **188.127.241.74:2626**.

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
