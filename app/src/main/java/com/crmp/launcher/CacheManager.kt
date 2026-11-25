package com.crmp.launcher

import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.zip.ZipInputStream

/**
 * Свой кэш: cache.zip + version.txt лежат в GitHub Release с тегом "cache".
 * Если версия на GitHub отличается от установленной — качаем и распаковываем.
 */
class CacheManager(private val gameDir: File, private val tempDir: File) {

    interface Listener {
        fun onStatus(text: String)
        fun onProgress(percent: Int)
    }

    private val versionFile = File(gameDir, ".cache_version")

    val installedVersion: String?
        get() = if (versionFile.exists()) versionFile.readText().trim().ifEmpty { null } else null

    /** null — кэш на GitHub ещё не опубликован. */
    fun fetchRemoteVersion(): String? {
        val conn = open(Config.CACHE_VERSION_URL)
        try {
            if (conn.responseCode != HttpURLConnection.HTTP_OK) return null
            return conn.inputStream.bufferedReader().use { it.readText() }.trim().ifEmpty { null }
        } finally {
            conn.disconnect()
        }
    }

    /** @return true если кэш актуален (или обновлён), false если кэш не опубликован. */
    @Throws(IOException::class)
    fun update(listener: Listener, force: Boolean = false): Boolean {
        listener.onStatus("Проверка кэша…")
        val remote = fetchRemoteVersion() ?: return false

        if (!force && remote == installedVersion) {
            listener.onStatus("Кэш актуален (версия $remote)")
            listener.onProgress(100)
            return true
        }

        tempDir.mkdirs()
        val zip = File(tempDir, "cache.zip")
        download(Config.CACHE_ZIP_URL, zip, listener)

        listener.onStatus("Распаковка…")
        listener.onProgress(0)
        unzip(zip, gameDir, listener)
        zip.delete()

        versionFile.writeText(remote)
        listener.onStatus("Кэш установлен (версия $remote)")
        listener.onProgress(100)
        return true
    }

    private fun download(url: String, target: File, listener: Listener) {
        val conn = open(url)
        try {
            if (conn.responseCode != HttpURLConnection.HTTP_OK) {
                throw IOException("Сервер ответил ${conn.responseCode}")
            }
            val total = conn.contentLengthLong
            var done = 0L
            var lastPercent = -1
            conn.inputStream.use { input ->
                FileOutputStream(target).use { out ->
                    val buf = ByteArray(64 * 1024)
                    while (true) {
                        val n = input.read(buf)
                        if (n < 0) break
                        out.write(buf, 0, n)
                        done += n
                        if (total > 0) {
                            val p = (done * 100 / total).toInt()
                            if (p != lastPercent) {
                                lastPercent = p
                                listener.onProgress(p)
                                listener.onStatus("Загрузка кэша: ${mb(done)} / ${mb(total)} МБ")
                            }
                        } else {
                            listener.onStatus("Загрузка кэша: ${mb(done)} МБ")
                        }
                    }
                }
            }
        } finally {
            conn.disconnect()
        }
    }

    private fun unzip(zip: File, dest: File, listener: Listener) {
        dest.mkdirs()
        val destPath = dest.canonicalPath + File.separator
        val totalSize = zip.length().coerceAtLeast(1)
        var lastPercent = -1
        val counting = CountingInputStream(zip.inputStream().buffered())
        ZipInputStream(counting).use { zis ->
            val buf = ByteArray(64 * 1024)
            while (true) {
                val entry = zis.nextEntry ?: break
                val out = File(dest, entry.name)
                // защита от zip-slip (выход за пределы папки)
                if (!out.canonicalPath.startsWith(destPath)) {
                    throw IOException("Плохой путь в архиве: ${entry.name}")
                }
                if (entry.isDirectory) {
                    out.mkdirs()
                } else {
                    out.parentFile?.mkdirs()
                    FileOutputStream(out).use { fos ->
                        while (true) {
                            val n = zis.read(buf)
                            if (n < 0) break
                            fos.write(buf, 0, n)
                        }
                    }
                }
                val p = (counting.count * 100 / totalSize).toInt().coerceAtMost(100)
                if (p != lastPercent) {
                    lastPercent = p
                    listener.onProgress(p)
                    listener.onStatus("Распаковка: $p%")
                }
            }
        }
    }

    private fun open(url: String): HttpURLConnection {
        var current = URL(url)
        // GitHub отдаёт 302 на objects.githubusercontent.com — идём по редиректам вручную
        repeat(5) {
            val conn = current.openConnection() as HttpURLConnection
            conn.connectTimeout = 15000
            conn.readTimeout = 30000
            conn.instanceFollowRedirects = false
            conn.setRequestProperty("User-Agent", "CrmpLauncher")
            val code = conn.responseCode
            if (code in 300..399) {
                val loc = conn.getHeaderField("Location") ?: return conn
                conn.disconnect()
                current = URL(current, loc)
            } else {
                return conn
            }
        }
        throw IOException("Слишком много редиректов")
    }

    private fun mb(bytes: Long) = String.format("%.1f", bytes / 1024.0 / 1024.0)

    private class CountingInputStream(private val inner: java.io.InputStream) : java.io.InputStream() {
        var count = 0L
            private set

        override fun read(): Int {
            val b = inner.read()
            if (b >= 0) count++
            return b
        }

        override fun read(b: ByteArray, off: Int, len: Int): Int {
            val n = inner.read(b, off, len)
            if (n > 0) count += n
            return n
        }

        override fun close() = inner.close()
    }
}
