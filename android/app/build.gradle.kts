import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

// Read local.properties — contains sdk.dir and secret keys (gitignored)
val localProps = Properties().also { props ->
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { props.load(it) }
}

// Version from the release tag, signing from the environment: both set by CI
// (.github/workflows/android-release.yml). Local builds are 0.0.0-dev, code 1.
val releaseTag = System.getenv("RELEASE_TAG").orEmpty()
val tagVersion = Regex("""^v(\d+)\.(\d+)\.(\d+)(?:-rc\.\d+)?$""").matchEntire(releaseTag)?.destructured

android {
    namespace = "com.mananpatel.voicebridge"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.mananpatel.voicebridge"
        minSdk = 24
        targetSdk = 35
        versionName = tagVersion?.let { (x, y, z) -> "$x.$y.$z" } ?: "0.0.0-dev"
        versionCode = tagVersion?.let { (x, y, z) -> x.toInt() * 10000 + y.toInt() * 100 + z.toInt() } ?: 1
        buildConfigField("String", "RELEASE_TAG", "\"${releaseTag.ifEmpty { "dev" }}\"")
        buildConfigField("String", "GIT_SHA", "\"${System.getenv("GITHUB_SHA")?.take(7) ?: "local"}\"")

        // Inject STT API key at build time; falls back to "" if not set in local.properties.
        // The app surfaces a clear error message when the key is blank.
        buildConfigField(
            "String",
            "GCP_STT_API_KEY",
            "\"${localProps.getProperty("GCP_STT_API_KEY", "")}\""
        )
    }

    // Release APKs come from CI only. Without ANDROID_KEYSTORE_PATH there is no
    // signing config, and assembleRelease gives an unsigned APK (AGP 9 refuses
    // a signing config without a storeFile, so it is only created with one).
    val keystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
    signingConfigs {
        if (keystorePath != null) {
            create("release") {
                storeFile = file(keystorePath)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS") ?: "release"
                keyPassword = System.getenv("ANDROID_KEYSTORE_PASSWORD") // PKCS12: same password
            }
        }
    }

    buildTypes {
        release { signingConfig = signingConfigs.findByName("release") }
        // Own package id, so a debug build installs next to the release build.
        debug { applicationIdSuffix = ".debug" }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    lint {
        // Lint errors fail the build: CI's lintDebug / lintRelease are a gate.
        // HTML report is written to app/build/reports/lint-results-<variant>.html.
        abortOnError = true
        checkReleaseBuilds = false
        htmlReport = true
    }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.09.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    debugImplementation("androidx.compose.ui:ui-tooling")
}
