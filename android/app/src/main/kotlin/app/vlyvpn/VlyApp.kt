// ================================================================
//  VlyApp.kt
//  Application класс — хранит ссылку на FlutterEngine
//  чтобы DisconnectReceiver мог отправить команду во Flutter
//
//  Добавить в AndroidManifest.xml:
//  <application android:name=".VlyApp" ...>
// ================================================================

package app.vlyvpn

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine

class VlyApp : Application() {
    companion object {
        var engine: FlutterEngine? = null
    }
}
