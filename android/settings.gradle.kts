pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    // Firebase config plugin — reads android/app/google-services.json
    // at build time and generates the values Firebase SDK reads at
    // runtime. Without this, Firebase.initializeApp() crashes on
    // Android with "Default FirebaseApp is not initialized in this
    // process". Kept `apply false` here; the actual :app module opts
    // in via its own plugins {} block.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
