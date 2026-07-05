// ================================================================
//  DisconnectReceiver.kt
//  Обрабатывает нажатие кнопки "Отключить" в уведомлении
//
//  Добавить в AndroidManifest.xml внутри <application>:
//  <receiver android:name=".DisconnectReceiver"
//            android:exported="false"/>
// ================================================================

package app.vlyvpn

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodChannel

class DisconnectReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Отправляем команду в Flutter через MethodChannel
        // FlutterEngine живёт в MainActivity — используем глобальный канал
        try {
            VlyApp.engine?.let { engine ->
                MethodChannel(
                    engine.dartExecutor.binaryMessenger,
                    "vly_vpn/commands"
                ).invokeMethod("disconnect", null)
            }
            // Убираем уведомление
            NotificationHelper.dismissPersistent(context)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
