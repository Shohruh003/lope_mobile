import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load release signing config from android/key.properties. The file
// is git-ignored (see android/.gitignore) so the storePassword /
// keyPassword never leak into version control. Fields:
//   storePassword, keyPassword, keyAlias, storeFile
// The storeFile path is resolved relative to android/app/, so
// `../../BarberBook.jks` points at the repo-root .jks placed there
// by the release manager.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) FileInputStream(f).use { load(it) }
}

android {
    // Namespace = local package for R.java / BuildConfig code — must
    // match the manifest package. Kept aligned with applicationId so
    // there's one source of truth.
    namespace = "uz.barberbook.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Play Store identifier — MUST NOT change once the app is
        // live on Google Play (used as the unique app key). Current
        // Play Store listing is uz.barberbook.mobile with 292+
        // installs, so we keep the id in lock-step with production.
        applicationId = "uz.barberbook.mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties.getProperty("storeFile")
            if (storeFilePath != null) {
                storeFile = file(storeFilePath)
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Prefer the real release keystore when key.properties is
            // present. Falls back to the debug keystore on machines
            // that don't have the release .jks (CI without secrets,
            // dev laptops) so `flutter run --release` still works.
            signingConfig = if (keystoreProperties.getProperty("storeFile") != null) {
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
