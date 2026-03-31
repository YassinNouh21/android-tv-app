# Update Logic - Dual Flavor Architecture

## Build Artifacts

```mermaid
graph TD
    subgraph Codebase["Single Codebase"]
        GP["googleplay flavor<br/>(clean - no special perms)"]
        SL["sideload flavor<br/>(REQUEST_INSTALL_PACKAGES)"]
    end

    GP --> AAB["AAB"]
    GP --> APK_CLEAN["Clean APK"]
    SL --> APK_SIDE["Sideload APK"]

    AAB --> PLAY["Google Play"]
    APK_CLEAN --> GITHUB["GitHub Releases"]
    APK_CLEAN --> S3_APK["S3: android/tv/apk/"]
    APK_SIDE --> S3_SIDE["S3: android/tv/onvo-apks/"]
```

## Update Flow - Sideload Flavor

```mermaid
flowchart TD
    START["User taps 'Check for Updates'"] --> INTERNET{Connected to internet?}
    INTERNET -- No --> NO_NET["Show 'No Internet' dialog"]
    INTERNET -- Yes --> CHECK_S3["Check S3 bucket<br/>(onvo-apks/)"]
    CHECK_S3 --> UPDATE{Update available?}
    UPDATE -- No --> UP_TO_DATE["Show 'Up to date' dialog"]
    UPDATE -- Yes --> DIALOG["Show update dialog<br/>User confirms"]
    DIALOG --> DOWNLOAD["Download APK from S3"]
    DOWNLOAD --> INSTALL["Install via FileProvider<br/>(REQUEST_INSTALL_PACKAGES)<br/><br/>Native: installApk<br/>ACTION_VIEW intent"]

    style INSTALL fill:#4CAF50,color:#fff
    style NO_NET fill:#f44336,color:#fff
    style UP_TO_DATE fill:#FF9800,color:#fff
```

## Update Flow - Google Play (Clean) Flavor

```mermaid
flowchart TD
    START["User taps 'Check for Updates'"] --> INTERNET{Connected to internet?}
    INTERNET -- No --> NO_NET["Show 'No Internet' dialog"]
    INTERNET -- Yes --> ROOTED{Device rooted?}
    ROOTED -- No --> OPEN_PLAY["Open Google Play Store"]
    ROOTED -- Yes --> CHECK_S3["Check S3 bucket<br/>(apk/)"]
    CHECK_S3 --> UPDATE{Update available?}
    UPDATE -- No --> UP_TO_DATE["Show 'Up to date' dialog"]
    UPDATE -- Yes --> DIALOG["Show update dialog<br/>User confirms"]
    DIALOG --> DOWNLOAD["Download APK from S3"]
    DOWNLOAD --> INSTALL["Install via root shell<br/>(no special permission)<br/><br/>Native: installApkRoot<br/>su -c 'pm install -r -d'"]

    style INSTALL fill:#4CAF50,color:#fff
    style OPEN_PLAY fill:#2196F3,color:#fff
    style NO_NET fill:#f44336,color:#fff
    style UP_TO_DATE fill:#FF9800,color:#fff
```

## CI/CD Pipeline (Codemagic)

```mermaid
flowchart TD
    TAG["Tag created"] --> BUILD

    subgraph BUILD["Codemagic Workflow"]
        B1["1. Build AAB<br/>--flavor googleplay"]
        B2["2. Build APK<br/>--flavor googleplay"]
        B3["3. Build APK<br/>--flavor sideload"]
    end

    B1 --> A1["MAWAQIT-For-TV-v*.aab"]
    B2 --> A2["MAWAQIT-For-TV-v*.apk"]
    B3 --> A3["MAWAQIT-For-TV-v*-sideload.apk"]

    A1 --> PLAY["Google Play"]
    A2 --> GITHUB["GitHub Release"]
    A2 --> S3_APK["S3: android/tv/apk/"]
    A3 --> S3_SIDE["S3: android/tv/onvo-apks/"]

    style PLAY fill:#2196F3,color:#fff
    style GITHUB fill:#333,color:#fff
    style S3_APK fill:#FF9800,color:#fff
    style S3_SIDE fill:#FF9800,color:#fff
```

## Summary Table

| Scenario | Flavor | Update Source | S3 Bucket | Install Method |
|---|---|---|---|---|
| Any device | sideload | S3 | `onvo-apks/` | FileProvider (REQUEST_INSTALL_PACKAGES) |
| Rooted device | googleplay | S3 | `apk/` | `su -c "pm install -r -d"` |
| Non-rooted device | googleplay | Google Play | - | Play Store |

## Key Files

| File | Role |
|---|---|
| `android/app/build.gradle.kts` | Defines `googleplay` and `sideload` product flavors |
| `android/app/src/sideload/AndroidManifest.xml` | Adds `REQUEST_INSTALL_PACKAGES` for sideload only |
| `android/app/src/main/AndroidManifest.xml` | Shared manifest (no install permission) |
| `lib/src/const/constants.dart` | `kAppFlavor` / `kIsSideloadFlavor` compile-time constants |
| `lib/src/state_management/manual_app_update/manual_update_notifier.dart` | Picks `installApk` vs `installApkRoot` based on flavor |
| `lib/src/pages/SettingScreen.dart` | Routes update flow based on flavor + root status |
| `android/.../MainActivity.kt` | Both native install methods (`installApk` + `installApkRoot`) |
| `codemagic.yaml` | Builds all 3 artifacts with correct `--flavor` and `--dart-define` |
