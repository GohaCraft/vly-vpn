// ================================================================
//  NotificationHelper.kt  v2.0
//  Vly — постоянное уведомление + Quick Settings тайл
//
//  Установка:
//  1. Этот файл → рядом с MainActivity.kt
//  2. VpnTileService.kt → рядом с MainActivity.kt (отдельный файл ниже)
//  3. MainActivity.kt → добавить NotificationHelper.setup(this, engine)
//  4. AndroidManifest.xml → добавить сервис тайла (см. ниже)
// ================================================================

package app.vlyvpn

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object NotificationHelper {

    // ── Каналы ───────────────────────────────────────────────────
    private const val CH_STATUS   = "vly_vpn_status"     // постоянное уведомление VPN
    private const val CH_EVENTS   = "vly_vpn_events"     // события (подключён / отключён)
    private const val METHOD_CH   = "vly_vpn/notifications"

    // ID уведомлений
    private const val ID_PERSISTENT = 100  // постоянное — пока VPN активен
    private const val ID_EVENT      = 101  // одноразовые события

    private var methodChannel: MethodChannel? = null

    // ── Публичный метод — вызывается из MainActivity ─────────────
    fun setup(context: Context, engine: FlutterEngine) {
        createChannels(context)
        methodChannel = MethodChannel(
            engine.dartExecutor.binaryMessenger, METHOD_CH
        ).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    // Простое событийное уведомление (подключён / отключён)
                    "show" -> {
                        val title = call.argument<String>("title") ?: "Vly"
                        val body  = call.argument<String>("body")  ?: ""
                        showEventNotification(context, title, body)
                        result.success(null)
                    }
                    // Постоянное уведомление пока VPN работает
                    "showPersistent" -> {
                        val server = call.argument<String>("server") ?: "Vly"
                        val speed  = call.argument<String>("speed")  ?: ""
                        showPersistentNotification(context, server, speed)
                        result.success(null)
                    }
                    // Обновить данные в постоянном уведомлении (скорость/трафик)
                    "updatePersistent" -> {
                        val server = call.argument<String>("server") ?: "Vly"
                        val speed  = call.argument<String>("speed")  ?: ""
                        showPersistentNotification(context, server, speed)
                        result.success(null)
                    }
                    // Убрать постоянное уведомление
                    "dismissPersistent" -> {
                        dismissPersistent(context)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    // ── Постоянное уведомление ────────────────────────────────────
    fun showPersistentNotification(context: Context, server: String, speed: String) {
        val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager

        // Intent для кнопки "Отключить"
        val disconnectIntent = Intent(context, DisconnectReceiver::class.java)
        val disconnectPi = PendingIntent.getBroadcast(
            context, 0, disconnectIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Intent — тап по уведомлению открывает приложение
        val openIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply { flags = Intent.FLAG_ACTIVITY_SINGLE_TOP }
        val openPi = PendingIntent.getActivity(
            context, 1, openIntent ?: Intent(),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val bodyText = if (speed.isNotEmpty()) speed else "VPN активен"

        val notification = NotificationCompat.Builder(context, CH_STATUS)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("🔒 $server")
            .setContentText(bodyText)
            .setContentIntent(openPi)
            .setOngoing(true)           // нельзя смахнуть
            .setShowWhen(false)         // не показывать время
            .setSilent(true)            // без звука
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .addAction(
                android.R.drawable.ic_lock_power_off,
                "Отключить",
                disconnectPi
            )
            .build()

        mgr.notify(ID_PERSISTENT, notification)
    }

    fun dismissPersistent(context: Context) {
        val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager
        mgr.cancel(ID_PERSISTENT)
    }

    // ── Событийные уведомления ────────────────────────────────────
    private fun showEventNotification(context: Context, title: String, body: String) {
        val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager

        val openIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
        val pi = PendingIntent.getActivity(
            context, 2, openIntent ?: Intent(),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CH_EVENTS)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()

        mgr.notify(ID_EVENT, notification)
    }

    // ── Создание каналов ──────────────────────────────────────────
    private fun createChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager

        // Канал для постоянного уведомления — тихий, низкий приоритет
        if (mgr.getNotificationChannel(CH_STATUS) == null) {
            NotificationChannel(
                CH_STATUS,
                "Vly — Статус",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Показывается пока VPN активен"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
            }.also { mgr.createNotificationChannel(it) }
        }

        // Канал для событий — обычный приоритет
        if (mgr.getNotificationChannel(CH_EVENTS) == null) {
            NotificationChannel(
                CH_EVENTS,
                "Vly — События",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Подключение, отключение, AI обходы"
                setShowBadge(true)
            }.also { mgr.createNotificationChannel(it) }
        }
    }
}
