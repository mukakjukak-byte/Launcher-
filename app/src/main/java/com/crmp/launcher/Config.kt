package com.crmp.launcher

/**
 * Все настройки лаунчера в одном месте.
 * Поменял здесь -> запушил в GitHub -> Actions собрал новый APK.
 */
object Config {
    // Адрес твоего сервера
    const val SERVER_IP = "188.127.241.74"
    const val SERVER_PORT = 2626

    // Репозиторий GitHub, в релизе с тегом "cache" лежат cache.zip и version.txt
    const val GITHUB_REPO = "mukakjukak-byte/Launcher-"
    const val CACHE_TAG = "cache"

    val CACHE_VERSION_URL = "https://github.com/$GITHUB_REPO/releases/download/$CACHE_TAG/version.txt"
    val CACHE_ZIP_URL = "https://github.com/$GITHUB_REPO/releases/download/$CACHE_TAG/cache.zip"

    /**
     * Package name клиента игры (APK с GTA SA + SAMP/CRMP mobile), который запускает лаунчер.
     * Впиши сюда applicationId своей сборки клиента.
     */
    const val GAME_PACKAGE = "com.crmp.client"

    /**
     * Папка в памяти телефона (/sdcard/<CACHE_FOLDER>), куда распаковывается кэш
     * и пишется SAMP/settings.ini (ник + адрес сервера). Клиент должен читать файлы отсюда.
     */
    const val CACHE_FOLDER = "CRMP"

    /**
     * Ссылка, откуда скачать клиент, если он не установлен (откроется в браузере).
     * По умолчанию — client.apk в том же релизе "cache". Пустая строка = не показывать.
     */
    val CLIENT_APK_URL = "https://github.com/$GITHUB_REPO/releases/download/$CACHE_TAG/client.apk"

    const val SERVER_ADDRESS = "$SERVER_IP:$SERVER_PORT"
}
