import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing, read from a file that is never committed.
//
// `android/key.properties` holds the four values below; `android/.gitignore`
// keeps it out of the repository, because a keystore in git is a keystore
// everyone who ever cloned the project can publish updates with.
//
// When the file is absent — which is every checkout that only builds debug —
// the release build falls back to the debug keys, so `flutter run --release`
// keeps working without anyone having to generate a keystore first. What it
// will not do is silently produce an unpublishable artifact: `flutter build
// appbundle` prints the warning below when it signs with debug keys.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeys = keystorePropertiesFile.exists()
if (hasReleaseKeys) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "uz.barterapp.barter_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "uz.barterapp.barter_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeys) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeys) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "\n  BarterApp: android/key.properties topilmadi — reliz " +
                    "debug kaliti bilan imzolanadi.\n" +
                    "  Bunday paketni Play Console qabul qilmaydi. " +
                    "Kalit yaratish uchun android/key.properties.example ga qarang.\n"
                )
                signingConfigs.getByName("debug")
            }

            // Shrink and obfuscate. Flutter's own rules are contributed by the
            // Gradle plugin; the app adds none of its own because nothing here
            // looks classes up by name at runtime.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
