package com.crmp.launcher

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.widget.Button
import android.widget.EditText
import android.widget.ImageButton
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import java.io.File

class MainActivity : Activity() {

    private lateinit var txtAddress: TextView
    private lateinit var txtHostname: TextView
    private lateinit var txtOnline: TextView
    private lateinit var txtMode: TextView
    private lateinit var txtStatus: TextView
    private lateinit var editNick: EditText
    private lateinit var progress: ProgressBar
    private lateinit var btnPlay: Button
    private lateinit var btnCache: Button

    private val ui = Handler(Looper.getMainLooper())
    private val prefs by lazy { getSharedPreferences("launcher", Context.MODE_PRIVATE) }

    @Volatile private var busy = false

    private val gameDir: File
        get() = File(Environment.getExternalStorageDirectory(), Config.CACHE_FOLDER)

    private val refreshTask = object : Runnable {
        override fun run() {
            refreshOnline()
            ui.postDelayed(this, 15_000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        txtAddress = findViewById(R.id.txtAddress)
        txtHostname = findViewById(R.id.txtHostname)
        txtOnline = findViewById(R.id.txtOnline)
        txtMode = findViewById(R.id.txtMode)
        txtStatus = findViewById(R.id.txtStatus)
        editNick = findViewById(R.id.editNick)
        progress = findViewById(R.id.progress)
        btnPlay = findViewById(R.id.btnPlay)
        btnCache = findViewById(R.id.btnCache)

        txtAddress.text = "Адрес: ${Config.SERVER_ADDRESS}"
        editNick.setText(prefs.getString("nick", ""))

        findViewById<ImageButton>(R.id.btnCopy).setOnClickListener {
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            cm.setPrimaryClip(ClipData.newPlainText("server", Config.SERVER_ADDRESS))
            toast("Адрес скопирован")
        }

        btnPlay.setOnClickListener { onPlay() }
        btnCache.setOnClickListener { runCache(force = true, thenLaunch = false) }
    }

    override fun onResume() {
        super.onResume()
        ui.post(refreshTask)
    }

    override fun onPause() {
        super.onPause()
        ui.removeCallbacks(refreshTask)
        prefs.edit().putString("nick", editNick.text.toString().trim()).apply()
    }

    // ---------- Онлайн сервера ----------

    private fun refreshOnline() {
        Thread {
            val info = SampQuery.query(Config.SERVER_IP, Config.SERVER_PORT)
            ui.post {
                if (info == null) {
                    txtHostname.text = "Сервер"
                    txtOnline.setTextColor(getColor(R.color.offline))
                    txtOnline.text = "● Оффлайн / нет ответа"
                    txtMode.text = ""
                } else {
                    txtHostname.text = info.hostname.ifEmpty { "Сервер" }
                    txtOnline.setTextColor(getColor(R.color.online))
                    txtOnline.text = "● Онлайн: ${info.players} / ${info.maxPlayers}   Пинг: ${info.pingMs} мс"
                    txtMode.text = listOf(info.gamemode, info.language)
                        .filter { it.isNotEmpty() }.joinToString(" • ")
                }
            }
        }.start()
    }

    // ---------- Играть ----------

    private fun onPlay() {
        if (busy) return
        val nick = editNick.text.toString().trim()
        if (!NICK_REGEX.matches(nick)) {
            editNick.error = "3–20 символов: латиница, цифры, _ [ ] ( ) . \$ @ ="
            return
        }
        prefs.edit().putString("nick", nick).apply()

        if (!ensureStoragePermission()) return
        runCache(force = false, thenLaunch = true)
    }

    private fun runCache(force: Boolean, thenLaunch: Boolean) {
        if (busy) return
        if (!ensureStoragePermission()) return
        setBusy(true)

        val tmp = externalCacheDir ?: cacheDir
        val manager = CacheManager(gameDir, tmp)
        val listener = object : CacheManager.Listener {
            override fun onStatus(text: String) { ui.post { txtStatus.text = text } }
            override fun onProgress(percent: Int) { ui.post { progress.progress = percent } }
        }

        Thread {
            var error: String? = null
            var published = true
            try {
                published = manager.update(listener, force)
            } catch (e: Exception) {
                error = e.message ?: e.javaClass.simpleName
            }
            ui.post {
                setBusy(false)
                when {
                    error != null -> {
                        txtStatus.text = "Ошибка кэша: $error"
                        AlertDialog.Builder(this)
                            .setTitle("Не удалось обновить кэш")
                            .setMessage("$error\n\nПроверь интернет и свободное место.")
                            .setPositiveButton("OK", null)
                            .show()
                    }
                    !published -> {
                        txtStatus.text = "Кэш на GitHub не опубликован — пропускаю"
                        if (thenLaunch) launchGame()
                    }
                    thenLaunch -> launchGame()
                }
            }
        }.start()
    }

    private fun launchGame() {
        val nick = editNick.text.toString().trim()
        writeClientSettings(nick)

        val intent = packageManager.getLaunchIntentForPackage(Config.GAME_PACKAGE)
        if (intent == null) {
            val dlg = AlertDialog.Builder(this)
                .setTitle("Клиент не установлен")
                .setMessage("Не найден клиент игры (${Config.GAME_PACKAGE}).")
                .setNegativeButton("Закрыть", null)
            if (Config.CLIENT_APK_URL.isNotEmpty()) {
                dlg.setPositiveButton("Скачать") { _, _ ->
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(Config.CLIENT_APK_URL)))
                }
            }
            dlg.show()
            return
        }

        // Передаём данные и через extras — если клиент умеет их читать
        intent.putExtra("host", Config.SERVER_IP)
        intent.putExtra("port", Config.SERVER_PORT)
        intent.putExtra("nick", nick)
        intent.putExtra("name", nick)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    /** SAMP/settings.ini — формат, который читают SA-MP/CRMP mobile клиенты. */
    private fun writeClientSettings(nick: String) {
        try {
            val dir = File(gameDir, "SAMP")
            dir.mkdirs()
            val file = File(dir, "settings.ini")
            val old = if (file.exists()) file.readLines() else emptyList()

            // сохраняем чужие строки, обновляем только наши ключи в секции [client]
            val keys = mapOf(
                "name" to nick,
                "host" to Config.SERVER_IP,
                "port" to Config.SERVER_PORT.toString()
            )
            val out = mutableListOf<String>()
            var inClient = false
            var hadClient = false
            val written = mutableSetOf<String>()
            fun flushMissing() {
                for ((k, v) in keys) if (k !in written) out.add("$k=$v")
                written.addAll(keys.keys)
            }
            for (line in old) {
                val t = line.trim()
                if (t.startsWith("[")) {
                    if (inClient) flushMissing()
                    inClient = t.equals("[client]", ignoreCase = true)
                    if (inClient) hadClient = true
                    out.add(line)
                    continue
                }
                val key = t.substringBefore('=').trim().lowercase()
                if (inClient && key in keys) {
                    out.add("$key=${keys[key]}")
                    written.add(key)
                } else {
                    out.add(line)
                }
            }
            if (inClient) flushMissing()
            if (!hadClient) {
                if (out.isNotEmpty()) out.add("")
                out.add("[client]")
                flushMissing()
            }
            file.writeText(out.joinToString("\n") + "\n")
        } catch (e: Exception) {
            toast("Не удалось записать settings.ini: ${e.message}")
        }
    }

    // ---------- Разрешения ----------

    private fun ensureStoragePermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (Environment.isExternalStorageManager()) return true
            AlertDialog.Builder(this)
                .setTitle("Нужен доступ к файлам")
                .setMessage("Лаунчеру нужен доступ к памяти, чтобы установить кэш игры в папку /${Config.CACHE_FOLDER}.")
                .setPositiveButton("Разрешить") { _, _ ->
                    try {
                        startActivity(
                            Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                                Uri.parse("package:$packageName"))
                        )
                    } catch (e: Exception) {
                        startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
                    }
                }
                .setNegativeButton("Отмена", null)
                .show()
            return false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE, Manifest.permission.READ_EXTERNAL_STORAGE),
                REQ_STORAGE
            )
            return false
        }
        return true
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_STORAGE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                toast("Доступ получен, нажми «Играть» ещё раз")
            } else {
                toast("Без доступа к памяти кэш не установить")
            }
        }
    }

    // ---------- Утилиты ----------

    private fun setBusy(value: Boolean) {
        busy = value
        btnPlay.isEnabled = !value
        btnCache.isEnabled = !value
        btnPlay.text = if (value) "ЗАГРУЗКА…" else "ИГРАТЬ"
    }

    private fun toast(msg: String) = Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()

    companion object {
        private const val REQ_STORAGE = 100
        private val NICK_REGEX = Regex("^[A-Za-z0-9_\\[\\]().\$@=]{3,20}$")
    }
}
