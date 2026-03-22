// ================================================================
//  AuraVpnApp.kt
//  Application класс — хранит ссылку на FlutterEngine
//  чтобы DisconnectReceiver мог отправить команду во Flutter
//
//  Добавить в AndroidManifest.xml:
//  <application android:name=".AuraVpnApp" ...>
// ================================================================

package com.example.vpn_new

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine

class AuraVpnApp : Application() {
    companion object {
        var engine: FlutterEngine? = null
    }
}
