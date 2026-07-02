// ================================================================
//  MainActivity.kt  v2.0
//  Подключает: NotificationHelper + DisconnectReceiver + TileService
// ================================================================

package app.vlyvpn

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val commandsChannel = "vly_vpn/commands"

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)

        // Сохраняем engine для DisconnectReceiver и VpnTileService
        VlyApp.engine = engine

        // Уведомления
        NotificationHelper.setup(this, engine)

        // Список установленных приложений (Split Tunnel) — реализован в AppsHelper.kt
        AppsHelper.setup(this, engine)

        // Команды от нативного кода → во Flutter
        // (кнопка "Отключить" в уведомлении, тап по тайлу)
        MethodChannel(engine.dartExecutor.binaryMessenger, commandsChannel)
            .setMethodCallHandler { call, result ->
                // Flutter сам обрабатывает connect/disconnect
                result.success(null)
            }

        // Системный шаринг + файловый импорт
        MethodChannel(engine.dartExecutor.binaryMessenger, "vly_vpn/share")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "share" -> {
                        val text    = call.argument<String>("text")    ?: ""
                        val subject = call.argument<String>("subject") ?: ""
                        val intent  = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(android.content.Intent.EXTRA_TEXT, text)
                            putExtra(android.content.Intent.EXTRA_SUBJECT, subject)
                        }
                        startActivity(android.content.Intent.createChooser(intent, "Поделиться нодой"))
                        result.success(null)
                    }
                    "pickFile" -> {
                        // Открываем системный file picker для .txt/.conf/.json файлов
                        val intent = android.content.Intent(android.content.Intent.ACTION_GET_CONTENT).apply {
                            type = "*/*"
                            putExtra(android.content.Intent.EXTRA_MIME_TYPES,
                                arrayOf("text/plain", "application/json", "application/octet-stream"))
                            addCategory(android.content.Intent.CATEGORY_OPENABLE)
                        }
                        try {
                            startActivityForResult(
                                android.content.Intent.createChooser(intent, "Выбрать файл конфигурации"),
                                FILE_PICK_REQUEST
                            )
                            _filePickResult = result
                        } catch (e: Exception) {
                            result.error("UNAVAILABLE", "Файловый менеджер недоступен", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // Обновление тайла при изменении статуса VPN
        MethodChannel(engine.dartExecutor.binaryMessenger, "vly_vpn/tile")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            VpnTileService.isVpnActive =
                                call.argument<Boolean>("active") ?: false
                            VpnTileService.serverName  =
                                call.argument<String>("server")  ?: "Vly"
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        VlyApp.engine = null
        super.onDestroy()
    }

    // ── File picker result ────────────────────────────────────────────────────
    companion object { const val FILE_PICK_REQUEST = 1001 }
    private var _filePickResult: io.flutter.plugin.common.MethodChannel.Result? = null

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == FILE_PICK_REQUEST) {
            val result = _filePickResult
            _filePickResult = null
            if (resultCode == android.app.Activity.RESULT_OK && data?.data != null) {
                try {
                    val uri = data.data!!
                    val stream = contentResolver.openInputStream(uri)
                    val text = stream?.bufferedReader()?.readText() ?: ""
                    stream?.close()
                    result?.success(text)
                } catch (e: Exception) {
                    result?.error("READ_ERROR", e.message, null)
                }
            } else {
                result?.error("CANCELLED", "Пользователь отменил выбор", null)
            }
        }
    }
}
