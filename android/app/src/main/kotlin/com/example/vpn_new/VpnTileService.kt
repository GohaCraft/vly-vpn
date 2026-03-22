// ================================================================
//  VpnTileService.kt
//  Quick Settings тайл — кнопка в шторке как WiFi/Авиарежим
//
//  Добавить в AndroidManifest.xml внутри <application>:
//
//  <service
//      android:name=".VpnTileService"
//      android:exported="true"
//      android:label="Aura VPN"
//      android:permission="android.permission.BIND_QUICK_SETTINGS_TILE">
//      <intent-filter>
//          <action android:name="android.service.quicksettings.action.QS_TILE"/>
//      </intent-filter>
//  </service>
//
//  Требует API 24+ (Android 7.0) — уже стоит у 99% пользователей
// ================================================================

package com.example.vpn_new

import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.MethodChannel

@RequiresApi(Build.VERSION_CODES.N)
class VpnTileService : TileService() {

    companion object {
        // Состояние тайла — обновляется из Flutter
        var isVpnActive: Boolean = false
        var serverName: String   = "Aura VPN"

        // Обновить тайл из Flutter (вызывается после смены статуса VPN)
        fun requestTileUpdate() {
            requestListeningState(
                // Используем глобальный контекст через Application
                AuraVpnApp.engine?.let {
                    try {
                        Class.forName("com.example.vpn_new.VpnTileService")
                    } catch (e: Exception) { null }
                }?.let { null } ?: return,
                android.content.ComponentName(
                    "com.example.vpn_new",
                    "com.example.vpn_new.VpnTileService"
                )
            )
        }
    }

    // ── Тайл стал видимым ─────────────────────────────────────────
    override fun onStartListening() {
        super.onStartListening()
        updateTile()
    }

    // ── Пользователь нажал тайл ───────────────────────────────────
    override fun onClick() {
        super.onClick()
        try {
            AuraVpnApp.engine?.let { engine ->
                MethodChannel(
                    engine.dartExecutor.binaryMessenger,
                    "aura_vpn/commands"
                ).invokeMethod(
                    if (isVpnActive) "disconnect" else "connect",
                    null
                )
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        // Оптимистично меняем состояние сразу — Flutter подтвердит потом
        isVpnActive = !isVpnActive
        updateTile()
    }

    // ── Обновить внешний вид тайла ────────────────────────────────
    private fun updateTile() {
        val tile = qsTile ?: return
        if (isVpnActive) {
            tile.state = Tile.STATE_ACTIVE
            tile.label = "Aura VPN"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                tile.subtitle = serverName
            }
        } else {
            tile.state = Tile.STATE_INACTIVE
            tile.label = "Aura VPN"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                tile.subtitle = "Отключён"
            }
        }
        tile.updateTile()
    }
}
