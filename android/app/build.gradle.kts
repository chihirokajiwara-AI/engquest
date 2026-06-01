plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase: Google Services plugin (processes google-services.json)
    id("com.google.gms.google-services")
}

android {
    namespace = "com.edilab.engquest"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            keyAlias = System.getenv("KEY_ALIAS") ?: "akenquest"
            keyPassword = System.getenv("KEY_PASSWORD") ?: ""
            storeFile = file(System.getenv("STORE_FILE") ?: "keystore/release.jks")
            storePassword = System.getenv("STORE_PASSWORD") ?: ""
        }
    }

    defaultConfig {
        // applicationId is overridden per flavor below.
        // minSdk 23 required by Firebase Auth / Firestore
        minSdk = 23
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Enable multidex for Firebase
        multiDexEnabled = true
    }

    flavorDimensions += "product"
    productFlavors {
        create("edilab") {
            dimension = "product"
            applicationId = "jp.co.aesthetic.engquest.edilab"
            resValue("string", "app_name", "ENG Quest")
        }
        create("aken") {
            dimension = "product"
            applicationId = "jp.co.aesthetic.akenquest"
            resValue("string", "app_name", "A-KEN Quest")
        }
    }

    buildTypes {
        release {
            // Use release signing when the keystore file exists (CI/CD),
            // fall back to debug signing for local development.
            val keystorePath = System.getenv("STORE_FILE") ?: "keystore/release.jks"
            signingConfig = if (file(keystorePath).exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
