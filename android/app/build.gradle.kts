plugins {
    id("com.android.application")
    // KGP (Kotlin Gradle Plugin). gradle.properties sets android.builtInKotlin=false
    // (opt out of AGP 9's built-in Kotlin), so the app MUST apply kotlin-android —
    // otherwise no Kotlin is compiled and KGP-based plugins (e.g. firebase_analytics)
    // produce no classes → "cannot find symbol FlutterFirebaseAnalyticsPlugin" (#143).
    id("org.jetbrains.kotlin.android")
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

    // AGP 9 disables resValues by default; the edilab/aken flavors set a custom
    // app_name via resValue(...), so the feature must be explicitly enabled (the
    // old android.defaults.buildfeatures.resvalues flag is deprecated in AGP 9).
    // Without this: "Product Flavor edilab contains custom resource values, but
    // the feature is disabled" → Android build fails (#143).
    buildFeatures {
        resValues = true
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
