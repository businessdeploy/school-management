// File: android/build.gradle.kts
// Root-level Gradle configuration for Flutter + Firebase

buildscript {
    dependencies {
        // Google Services plugin (updated)
        classpath("com.google.gms:google-services:4.4.0")
    }
}

plugins {
    // Android & Kotlin plugins declared but not applied here
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    // Required by Flutter for correct module evaluation
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
