import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// توقيع الإصدار: android/key.properties محلياً، أو متغيرات البيئة في CI (نفس أسرار «أسرتي» و«موعد»).
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
fun signingValue(prop: String, env: String): String? = keyProps.getProperty(prop) ?: System.getenv(env)

android {
    namespace = "sa.lamha.lamha"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "sa.lamha.lamha"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // اختبار لقطات الودجت على المحاكي (src/androidTest، job screens في CI).
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    // لقطات الودجت: منطق مشترك بين اختبار المحاكي (androidTest) واختبار Robolectric (test).
    sourceSets {
        getByName("test").java.srcDir("src/sharedTest/kotlin")
        getByName("androidTest").java.srcDir("src/sharedTest/kotlin")
    }

    testOptions {
        unitTests.isIncludeAndroidResources = true
    }

    signingConfigs {
        create("release") {
            val store = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")
            if (store != null) {
                storeFile = file(store)
                storePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // مفتاح الرفع في lamha-play.yml؛ وبدونه توقيع debug (APK التجربة في lamha-android.yml، لا المتجر).
            signingConfig = if (signingValue("storeFile", "ANDROID_KEYSTORE_PATH") != null)
                signingConfigs.getByName("release") else signingConfigs.getByName("debug")
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
    // جلب الطقس الدوري (LamhaWeatherWorker): نفس نسخة WorkManager في home_widget 0.10.0.
    implementation("androidx.work:work-runtime:2.11.2")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.16")
    testImplementation("androidx.test:core:1.6.1")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test:core:1.6.1")
}

// Robolectric (isIncludeAndroidResources) يحزم أصول الإصدار، ومنها أصول Flutter: ترتيب صريح يرضي
// تحقق Gradle دون أن يفرض بناء Flutter مع اختبارات JUnit.
tasks.configureEach {
    for (variant in listOf("Debug", "Profile", "Release")) {
        if (name == "package${variant}UnitTestForUnitTest") mustRunAfter("copyFlutterAssets$variant")
    }
}
