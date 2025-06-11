import java.util.Properties
import java.io.FileInputStream

  plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
  }

// Load key.properties for local development
val keystorePropsFile = rootProject.file("key.properties")
val keystoreProps = Properties().apply {
  if (keystorePropsFile.exists()) {
    load(FileInputStream(keystorePropsFile))
  }
}

android {
    namespace = "com.mawaqit.androidtv"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    val appVersionCode = (System.getenv()["NEW_BUILD_NUMBER"] ?: flutter.versionCode).toString().toInt()

    defaultConfig {
        applicationId = "com.mawaqit.androidtv"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = appVersionCode
        versionName = flutter.versionName
        manifestPlaceholders["crashlyticsCollectionEnabled"] = false
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    signingConfigs {
        create("release") {
          if (System.getenv()["CI"] == "true") {
            val keystorePath = System.getenv()["CM_KEYSTORE_PATH"]
            val storePassword = System.getenv()["CM_KEYSTORE_PASSWORD"]
            val keyAlias = System.getenv()["CM_KEY_ALIAS"]
            val keyPassword = System.getenv()["CM_KEY_PASSWORD"]
            
            if (keystorePath != null && storePassword != null && keyAlias != null && keyPassword != null) {
              storeFile = file(keystorePath)
              this.storePassword = storePassword
              this.keyAlias = keyAlias
              this.keyPassword = keyPassword
            }
          } else if (keystorePropsFile.exists() &&
            keystoreProps["storeFile"] != null &&
            keystoreProps["storePassword"] != null &&
            keystoreProps["keyAlias"] != null &&
            keystoreProps["keyPassword"] != null
          ) {
            storeFile = rootProject.file(keystoreProps["storeFile"].toString())
            storePassword = keystoreProps["storePassword"].toString()
            keyAlias = keystoreProps["keyAlias"].toString()
            keyPassword = keystoreProps["keyPassword"].toString()
          }
        }
    }

    buildTypes {
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
            // Debug builds use the default debug signing, no need to specify signingConfig
        }
        
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
        }
    }

  testOptions {
    execution = "ANDROIDX_TEST_ORCHESTRATOR"
  }
}

dependencies {
  androidTestUtil("androidx.test:orchestrator:1.5.1")

}



flutter {
  source = "../.."
}
