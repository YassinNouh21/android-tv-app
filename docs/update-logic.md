# Update Logic

## Build Artifacts

```mermaid
graph TD
    Codebase --> AAB["AAB"]
    Codebase --> APK["APK"]

    AAB --> PLAY["Google Play"]
    APK --> GITHUB["GitHub Releases"]
    APK --> S3_APK["S3: android/tv/apk/"]
```

## Update Flow

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
    DOWNLOAD --> INSTALL["Install via root shell<br/>(no special permission)<br/><br/>Native: installApkRoot<br/>su -c 'pm install -r'"]
    INSTALL -- Success --> DONE["Update complete"]
    INSTALL -- NOT_ROOTED / INSTALL_FAILED --> OPEN_PLAY

    style INSTALL fill:#4CAF50,color:#fff
    style OPEN_PLAY fill:#2196F3,color:#fff
    style NO_NET fill:#f44336,color:#fff
    style UP_TO_DATE fill:#FF9800,color:#fff
    style DONE fill:#4CAF50,color:#fff
```

## CI/CD Pipeline (Codemagic)

```mermaid
flowchart TD
    TAG["Tag created"] --> RELEASE
    PR["PR / branch push"] --> DEV

    subgraph RELEASE["Release Workflow"]
        B1["1. Build AAB"]
        B2["2. Build APK"]
    end

    subgraph DEV["Dev Workflow"]
        D1["1. Build AAB"]
        D2["2. Build APK"]
    end

    B1 --> A1["MAWAQIT-For-TV-v*.aab"]
    B2 --> A2["MAWAQIT-For-TV-v*.apk"]

    A1 --> PLAY["Google Play"]
    A2 --> GITHUB["GitHub Release"]
    A2 --> S3_APK["S3: android/tv/apk/"]

    D1 --> DA1["MAWAQIT-For-TV-v*-dev.aab"]
    D2 --> DA2["MAWAQIT-For-TV-v*-dev.apk"]

    style PLAY fill:#2196F3,color:#fff
    style GITHUB fill:#333,color:#fff
    style S3_APK fill:#FF9800,color:#fff
```

## Summary Table

| Scenario | Update Source | Install Method |
|---|---|---|
| Rooted device | S3 (`apk/`) | `su -c "pm install -r"` — falls back to Play Store on failure |
| Non-rooted device | Google Play | Play Store |

## Key Files

| File | Role |
|---|---|
| `android/app/build.gradle.kts` | Android build config (no product flavors) |
| `android/app/src/main/AndroidManifest.xml` | App manifest (no install permission needed) |
| `lib/src/state_management/manual_app_update/manual_update_notifier.dart` | Picks S3 APK (non-sideload), installs via root |
| `lib/src/pages/SettingScreen.dart` | Routes update flow based on root status |
| `android/.../MainActivity.kt` | Native `installApkRoot` method (`su pm install`) |
| `codemagic.yaml` | Builds AAB + APK, uploads to S3 / GitHub / Play Store |
