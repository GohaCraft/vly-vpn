// android/build.gradle.kts  (PROJECT level — не app/build.gradle.kts!)
// Aura VPN v6.0.0 — обновлено для AndroidX activity 1.12.4 + core 1.17.0

plugins {
    // AGP 8.9.1 — минимум для androidx.activity:1.12.4 и androidx.core:1.17.0
    id("com.android.application") version "8.9.1" apply false
    id("com.android.library")     version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}
