plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.crmp.launcher"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.crmp.launcher"
        minSdk = 23
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            // Подписываем debug-ключом, чтобы APK сразу ставился на телефон.
            // Для Google Play замени на свой keystore.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}
