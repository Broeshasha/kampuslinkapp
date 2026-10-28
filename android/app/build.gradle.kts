import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

android {
    ndkVersion = "28.2.13676358"
    namespace = "com.kampuslink.kampuslink"
    compileSdk = 37

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Needed by flutter_local_notifications (study reminders).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.kampuslink.kampuslink"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = System.getenv("KS_ALIAS") ?: (keystoreProperties["keyAlias"] as String?)
            keyPassword = System.getenv("KS_KEY_PW") ?: (keystoreProperties["keyPassword"] as String?)
            storeFile = (System.getenv("KS_FILE") ?: (keystoreProperties["storeFile"] as String?))?.let { file(it) }
            storePassword = System.getenv("KS_STORE_PW") ?: (keystoreProperties["storePassword"] as String?)
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
