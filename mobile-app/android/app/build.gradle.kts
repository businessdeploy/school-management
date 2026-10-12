import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // Firebase
}

android {
    namespace = "com.qdocs.smartschool2026"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // Load keystore properties
    val keystorePropertiesFile = rootProject.projectDir.parentFile.resolve("android/key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    defaultConfig {
        applicationId = "com.qdocs.smartschool2026"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }

        getByName("release") {
            // Apply signing configuration if it exists
            if (keystoreProperties["storeFile"] != null) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Firebase BOM (version manager)
    implementation(platform("com.google.firebase:firebase-bom:33.1.2"))

    // Firebase modules
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-database")
    implementation("com.google.firebase:firebase-storage")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
}

gradle.projectsEvaluated {
    tasks.named("assembleRelease") {
        doLast {
            val outputDir = layout.buildDirectory.dir("outputs/flutter-apk").get().asFile
            if (!outputDir.exists()) {
                logger.warn("Output directory not found at ${outputDir.path}")
                return@doLast
            }

            val flutterRootBuildDir = rootProject.projectDir.parentFile.resolve("build")
            val targetDir = flutterRootBuildDir.resolve("app/outputs/flutter-apk")
            targetDir.mkdirs()

            outputDir.listFiles { file -> file.extension == "apk" }?.forEach { apkFile ->
                logger.lifecycle("Copying ${apkFile.name} to ${targetDir.path}")
                apkFile.copyTo(targetDir.resolve(apkFile.name), overwrite = true)
            }
        }
    }
}
