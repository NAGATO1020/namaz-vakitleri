import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Yayın imzası. `android/key.properties` depoya girmez (bkz. .gitignore);
// yoksa hata ayıklama anahtarına düşülür, böylece proje anahtarsız da derlenir.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile")?.let { file(it).exists() } == true

android {
    namespace = "com.tunahan.namaz_vakitleri"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications java.time API'lerini kullanıyor;
        // eski Android sürümlerinde çalışması için desugaring şart.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.tunahan.namaz_vakitleri"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Vakit adları Türkçe; kaynaklar TR ve EN olarak tutuluyor.
        resourceConfigurations += listOf("tr", "en")
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Havadan güncellemenin çalışması için her sürüm aynı anahtarla
            // imzalanmalı; imza değişirse Android güncellemeyi reddeder.
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // NotificationCompat, RemoteViews yardımcıları ve izin kontrolleri
    implementation("androidx.core:core-ktx:1.15.0")
    // PrayerSchedule ve SourceFetcher testleri (cihaz gerektirmez)
    testImplementation("junit:junit:4.13.2")
    // android.jar'daki org.json yalnızca saplama; birim testlerde çağrılınca
    // "not mocked" fırlatıyor. Gerçek uygulamayı test sınıf yoluna alıyoruz.
    testImplementation("org.json:json:20250107")
}

flutter {
    source = "../.."
}
