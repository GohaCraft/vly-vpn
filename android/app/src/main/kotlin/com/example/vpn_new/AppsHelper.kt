// ================================================================
//  AppsHelper.kt
//  Получает список установленных приложений для Split Tunnel
//
//  Подключение в MainActivity.kt:
//    AppsHelper.setup(this, engine)
//
//  Положить рядом с MainActivity.kt:
//  android/app/src/main/kotlin/com/example/vpn_new/AppsHelper.kt
// ================================================================

package com.example.vpn_new

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.util.Base64
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import kotlinx.coroutines.*

object AppsHelper {

    private const val CHANNEL = "aura_vpn/apps"

    // Пакеты которые скрываем из списка — системные / сам VPN
    private val HIDDEN_PACKAGES = setOf(
        "com.example.vpn_new",
        "android",
        "com.android.systemui",
        "com.android.settings",
        "com.google.android.gms",
        "com.android.providers.telephony",
        "com.android.providers.calendar",
        "com.android.providers.media",
        "com.android.packageinstaller",
        "com.android.phone",
        "com.android.shell",
        "com.android.wallpaper",
        "com.android.inputmethod.latin",
    )

    fun setup(context: Context, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> {
                        // Запускаем в фоновом потоке — список может быть большим
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val apps = getInstalledApps(context)
                                withContext(Dispatchers.Main) {
                                    result.success(apps)
                                }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("APPS_ERROR", e.message, null)
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getInstalledApps(context: Context): List<Map<String, String>> {
        val pm = context.packageManager
        val apps = mutableListOf<Map<String, String>>()

        val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)

        for (pkg in packages) {
            // Пропускаем системные приложения без launcher иконки
            val isSystem = (pkg.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            val hasLauncher = pm.getLaunchIntentForPackage(pkg.packageName) != null

            if (isSystem && !hasLauncher) continue
            if (pkg.packageName in HIDDEN_PACKAGES) continue

            val label = try {
                pm.getApplicationLabel(pkg).toString()
            } catch (_: Exception) { pkg.packageName }

            // Иконка — конвертируем в base64 PNG (маленький размер)
            val iconBase64 = try {
                val drawable = pm.getApplicationIcon(pkg.packageName)
                drawableToBase64(drawable, 48)
            } catch (_: Exception) { "" }

            apps.add(mapOf(
                "packageName" to pkg.packageName,
                "label"       to label,
                "icon"        to iconBase64,
            ))
        }

        // Сортируем по названию
        apps.sortBy { it["label"]?.lowercase() ?: "" }
        return apps
    }

    private fun drawableToBase64(drawable: Drawable, sizePx: Int): String {
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            Bitmap.createScaledBitmap(drawable.bitmap, sizePx, sizePx, true)
        } else {
            val bmp = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bmp
        }
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 85, out)
        return Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
    }
}
