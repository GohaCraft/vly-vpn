plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace    = "com.example.vpn_new"
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
        applicationId = "com.example.vpn_new"
        minSdk        = flutter.minSdkVersion
        targetSdk     = flutter.targetSdkVersion
        // versionCode по timestamp — каждый билд уникален, обновление без удаления
        versionCode   = (System.currentTimeMillis() / 1000).toInt()
        versionName   = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}

flutter {
    source = "../.."
}
