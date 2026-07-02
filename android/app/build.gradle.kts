plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
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

    // Стабильный keystore — ОДИН на все сборки (локально и в CI). Раньше
    // использовался debug-keystore, который генерится заново на каждой машине CI
    // → каждая сборка подписана РАЗНЫМ ключом → Android отказывался обновлять
    // (signature mismatch), приходилось удалять старое приложение. Теперь подпись
    // одинаковая везде → обновление поверх (in-place update) работает.
    signingConfigs {
        create("vly") {
            storeFile     = file("vly.keystore")
            storePassword = "vlyvpn2026"
            keyAlias      = "vly"
            keyPassword   = "vlyvpn2026"
        }
    }

    buildTypes {
        getByName("debug") {
            signingConfig = signingConfigs.getByName("vly")
        }
        getByName("release") {
            signingConfig = signingConfigs.getByName("vly")
        }
    }
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}

flutter {
    source = "../.."
}
