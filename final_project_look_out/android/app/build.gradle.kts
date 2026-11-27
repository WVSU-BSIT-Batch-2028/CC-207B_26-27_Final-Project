plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Add the Google services Gradle plugin
    id("com.google.gms.google-services")
}

val firebaseEnvironmentFile = rootProject.file("../.env.json")
val googleServicesTemplate = file("google-services.json.template")
val generatedGoogleServicesJson =
    layout.buildDirectory.file("generated/google-services/google-services.json")

val generateGoogleServicesJson by tasks.registering {
    inputs.file(googleServicesTemplate)
    if (firebaseEnvironmentFile.exists()) {
        inputs.file(firebaseEnvironmentFile)
    }
    inputs.property(
        "firebaseApiKey",
        providers.environmentVariable("FIREBASE_API_KEY").orElse(""),
    )
    outputs.file(generatedGoogleServicesJson)

    doLast {
        val environment = if (firebaseEnvironmentFile.exists()) {
            groovy.json.JsonSlurper().parse(firebaseEnvironmentFile) as Map<*, *>
        } else {
            emptyMap<Any, Any>()
        }
        val apiKey = System.getenv("FIREBASE_API_KEY")
            ?: environment["FIREBASE_API_KEY"] as? String
            ?: throw GradleException(
                "FIREBASE_API_KEY is missing from .env.json and the process environment.",
            )
        if (!apiKey.matches(Regex("[A-Za-z0-9_-]+"))) {
            throw GradleException("FIREBASE_API_KEY contains unsupported characters.")
        }

        val template = googleServicesTemplate.readText()
        if (!template.contains("__FIREBASE_API_KEY__")) {
            throw GradleException("Firebase config template is missing its API key placeholder.")
        }
        val outputFile = generatedGoogleServicesJson.get().asFile
        outputFile.parentFile.mkdirs()
        outputFile.writeText(template.replace("__FIREBASE_API_KEY__", apiKey))
    }
}

afterEvaluate {
    tasks.withType<com.google.gms.googleservices.GoogleServicesTask>().configureEach {
        googleServicesJsonFiles.set(
            generatedGoogleServicesJson.map { listOf(it.asFile) },
        )
        dependsOn(generateGoogleServicesJson)
    }
}

dependencies {
  // Import the Firebase BoM
  implementation(platform("com.google.firebase:firebase-bom:35.2.0"))


  // TODO: Add the dependencies for Firebase products you want to use
  // When using the BoM, don't specify versions in Firebase dependencies
  implementation("com.google.firebase:firebase-analytics")


  // Add the dependencies for any other desired Firebase products
  // https://firebase.google.com/docs/android/setup#available-libraries
}

android {
    namespace = "com.example.final_project_look_out"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.final_project_look_out"
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
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
