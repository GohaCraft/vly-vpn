import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Данные подписи читаются из android/key.properties (в .gitignore) или из
// CI-секретов (workflow сам создаёт этот файл). В РЕПОЗИТОРИИ ключа и паролей
// НЕТ. Если файла нет (локальная сборка без ключа или CI без секретов) —
// откатываемся на debug-подпись, и сборка всё равно проходит.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace    = "app.vlyvpn"
    compileSdk   = 36
    ndkVersion   = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "app.vlyvpn"
        minSdk        = flutter.minSdkVersion
        targetSdk     = flutter.targetSdkVersion
        // versionCode по timestamp — каждый билд уникален, обновление без удаления
        versionCode   = (System.currentTimeMillis() / 1000).toInt()
        versionName   = flutter.versionName
    }

    // Стабильный релизный keystore подписывает все сборки ОДНИМ ключом (локально
    // и в CI) → обновление поверх (in-place update) работает. Ключ и пароли
    // берутся из key.properties/CI-секретов, а не из репозитория.
    signingConfigs {
        if (hasReleaseKeystore) {
            create("vly") {
                storeFile     = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias      = keystoreProperties["keyAlias"] as String
                keyPassword   = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        // Настроенный ключ — если есть; иначе debug-подпись (fallback), чтобы
        // сборка не падала без секретов. Стабильность обновлений включается
        // автоматически, как только key.properties/секреты появятся.
        val signing = if (hasReleaseKeystore) signingConfigs.getByName("vly")
                      else signingConfigs.getByName("debug")
        getByName("debug")   { signingConfig = signing }
        getByName("release") { signingConfig = signing }
    }
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}

flutter {
    source = "../.."
}
