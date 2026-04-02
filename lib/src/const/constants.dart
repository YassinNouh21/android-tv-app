/// this file will has all the constant values of the app

const kAppName = 'MAWAQIT for TV';
const kAppId = 'com.mawaqit.androidtv';

const kDeviceInfo = 'device_info';

const kBaseUrl = 'https://mawaqit.net/api';
const kStagingUrl = 'https://staging.mawaqit.net/api';
const kPreProdUrl = 'https://preprod.mawaqit.net/api';
const kStaticFilesUrl = 'https://cdn.mawaqit.net';
const kStagingStaticFilesUrl = 'https://cdn.mawaqit.net';
const kPreProdStaticFilesUrl = 'https://cdn.mawaqit.net';

const kApiToken = String.fromEnvironment('mawaqit.api.key');
const kSentryDns = String.fromEnvironment('mawaqit.sentry.dns');
const kGooglePlayId = 'com.mawaqit.androidtv';

const kAppFlavor = String.fromEnvironment('APP_FLAVOR', defaultValue: 'googleplay');
const kIsSideloadFlavor = kAppFlavor == 'sideload';

class CacheKey {
  static const String kMosqueBackgroundScreen = 'mosque_background_screen';
  static const String kLastPopupDisplay = 'last_popup_display';
  static const String kAutoUpdateChecking = 'auto_update_checking';
  static const String kIsUpdateDismissed = 'is_update_dismissed';
  static const String kUpdateDismissedVersion = 'update_dismissed_version';
  static const String kHttpRequests = 'http_requests_cache';
}

class HttpHeaderConstant {
  // HTTP Header keys
  static const String kHeaderContentType = 'content-type';
  static const String kHeaderLastModified = 'Last-Modified';
  static const String kHeaderIfModifiedSince = 'If-Modified-Since';

  // Content types
  static const String kContentTypeApplicationJson = 'application/json';
}

abstract class RandomHadithConstant {
  static const String kLastHadithXMLFetchDate = "last_hadith_xml_fetch_date";
  static const String kBoxName = "random_hadith_list";
  static const String kHadithLanguage = "hadith_language";
  static const String kLastHadithXMLFetchLanguage = "last_hadith_xml_language";
  static const String kUseMosqueDefaultLanguage = "auto";
  static const String kDefaultLanguageFallback = "Default";
}

/// Constants for bilingual language separator patterns (e.g., 'fr-ar', 'en_ar')
abstract class LanguageConstants {
  static const String separatorDash = '-';
  static const String separatorUnderscore = '_';
  static const String separatorPattern = r'[-_]';
}

class TurnOnOffTvConstant {
  static const String kActivateToggleFeature = 'activate_toggle_feature';
  static const String kisFajrIshaOnly = 'is_fajr_isha_only';
  static const String kScheduledTimersKey = 'scheduled_timers_key';
  static const String kLastEventDate = 'last_event_date';
  static const String kMinuteBeforeKey = 'minute_before_key';
  static const String kMinuteAfterKey = 'minute_after_key';
  static const String kIsEventsSet = 'is_events_set';
  static const String kScheduleParamsKey = 'schedule_params_key';
  static const String kLastExecutedEventDate = 'last_executed_event_date';
  static const String kBatteryOptimizationDisabledAtSchedule = 'battery_optimization_disabled_at_schedule';

  /// native methods calls
  static const String kNativeMethodsChannel = "nativeMethodsChannel";
  static const String kCheckRoot = "checkRoot";
}

abstract class AnnouncementConstant {
  static const String kBoxName = "announcement";
}

abstract class MosqueManagerConstant {
  static const String kMosqueUUID = "mosqueUUID";
  static const String khasCachedMosque = "hasCachedMosque";
}

abstract class QuranConstant {
  static const String kQuranZipBaseUrl = "https://cdn.mawaqit.net/quran/";
  static const String kHafsQuranLocalVersion = 'hafs_quran_local_version';
  static const String kWarshQuranLocalVersion = 'warsh_quran_local_version';
  static const String kSelectedMoshafType = 'selected_moshaf_type';
  static const String kQuranBaseUrl = 'https://mp3quran.net/api/v3/';
  static const String kSurahBox = 'surah_box_v2';
  static const String kReciterBox = 'reciter_box_v3';
  static const String kQuranModePref = 'quran_mode';
  static const String kSavedCurrentPage = 'saved_current_page';
  static const String kHafsSavedCurrentPage = 'hafs_saved_current_page';
  static const String kWarshSavedCurrentPage = 'warsh_saved_current_page';
  static const String kFavoriteReciterBox = 'favorite_reciter_box';
  static const String quranMoshafConfigJsonUrl = 'https://cdn.mawaqit.net/quran/tv_config.json';
  static const String kIsFirstTime = 'is_first_time_quran';
  static const String kQuranReciterImagesBaseUrl = 'https://cdn.mawaqit.net/quran/reciters-pictures/';
  static const String kQuranCacheBoxName = 'timestamp_box';
  static const String kQuranReciterRetentionTime = 'quran_reciter_retention_time';

  // Playback session persistence keys
  static const String kLastPlayedReciterId = 'quran_last_reciter_id';
  static const String kLastPlayedMoshafId = 'quran_last_moshaf_id';
  static const String kLastPlayedSurahId = 'quran_last_surah_id';
  static const String kLastPlayedPositionMs = 'quran_last_position_ms';
  static const String kLastPlayedSurahJson = 'quran_last_surah_json';

  static const int kCacheWidth = 300;
  static const int kCacheHeight = 300;
  static const String kArabicLanguage = 'ar';
  static const String kEnglishLanguage = 'eng';
}

abstract class AzkarConstant {
  static const String kAzkarAfterPrayer = 'أذكار بعد الصلاة';
  static const String kAzkarSabahAfterPrayer = 'أذكار الصباح';
  static const String kAzkarAsrAfterPrayer = 'أذكار المساء';
}

abstract class SettingsConstant {
  static const String kLanguageCode = 'language_code';
  static const String kSelectedCountry = 'selected_country';
}

abstract class SystemFeaturesConstant {
  static const String kLeanback = 'android.software.leanback';
  static const String kHdmi = 'android.hardware.hdmi';
  static const String kEthernet = 'android.hardware.ethernet';
}

class BackgroundScheduleAudioServiceConstant {
  static const String kManualPause = 'manual_pause_enabled';
  static const String kPendingSchedule = 'pending_schedule';
  static const String kScheduleEnabled = 'schedule_enabled';
  static const String kStartTime = 'start_time';
  static const String kEndTime = 'end_time';
  static const String kRandomEnabled = 'isRandomEnabled';
  static const String kRandomUrls = 'random_urls';
  static const String kSelectedSurah = 'selected_surah';
  static const String kSelectedSurahName = 'selected_surah_name';
  static const String kSelectedSurahUrl = 'selected_surah_url';
  static const String kSelectedReciter = 'selected_reciter';
  static const String kSelectedMoshaf = 'selected_moshaf';
  static const String kAudioStateChanged = 'kAudioStateChanged';
  static const String kGetPlaybackState = 'kGetPlaybackState';
  static const String kStopAudio = 'kStopAudio';
  static const String kResumeAudio = 'kResumeAudio';
}

abstract class MawaqitBackendSettingsConstant {
  static const String kSettingsTitle = "Mawaqit";
  static const String kSettingsShare =
      "Download Mawaqit\r\nAndroid:\r\nhttps:\/\/play.google.com\/store\/apps\/details?id=com.mawaqit.admin\r\niOS:\r\nhttps:\/\/apps.apple.com\/fr\/app\/mawaqit-prayer-times-mosque\/id1460522683\r\n";
  static const String kSettingsAndroidUserAgent =
      "Mozilla\/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit\/537.36 (KHTML, like Gecko) Chrome\/95.0.4638.69 Safari\/537.36";
  static const String kSettingsIosUserAgent =
      "Mozilla\/5.0 (iPhone; CPU iPhone OS 14_5 like Mac OS X) AppleWebKit\/605.1.15 (KHTML, like Gecko) CriOS\/90.0.4430.78 Mobile\/15E148 Safari\/604.1";
}

abstract class ManualUpdateConstant {
  static const String _s3BucketBase = 'https://cdn.mawaqit.net.s3.amazonaws.com/?list-type=2&prefix=';
  static const String s3BucketListUrl =
      kIsSideloadFlavor ? '${_s3BucketBase}android/tv/onvo-apks/' : '${_s3BucketBase}android/tv/apk/';
  static const String s3DownloadBaseUrl = 'https://cdn.mawaqit.net';
  static const String apkPrefix = 'MAWAQIT-For-TV-v';
}

abstract class ScheduleListeningConstant {
  static const startTime = '08:00';
  static const endTime = '20:00';
}

abstract class PrayerAudioConstant {
  static const String kDefaultAdhanFileName = 'adhan-afassy.mp3';
  static const String kFajrAdhanSuffix = '-fajr.mp3';
  static const String kDuaAfterAdhanFileName = 'duaa-after-adhan.mp3';
  static const String kMp3Directory = '/audio/';
  static const String kMp3Extension = '.mp3';
  static const String kHttpProtocol = 'http://';
  static const String kHttpsProtocol = 'https://';
  static const String kHttpsPrefix = 'https:';
}

abstract class DeviceDetectionConstant {
  static const chromeCastDeviceKeywords = {
    'chromecast',
    'haier',
    'condor',
    'xiaomi',
    'hyundai',
    'iris',
    'stream',
    'lifemax'
  };
}

abstract class LiveStreamConstants {
  /// Regular expression to match YouTube URLs
  static final RegExp youtubeUrlRegex = RegExp(
    r'^(https?\:\/\/)?(www\.)?(youtube\.com|youtu\.?be)\/.*',
    caseSensitive: false,
  );

  /// Key for the enabled preference in SharedPreferences
  static const String prefKeyEnabled = 'livestream_enabled';

  /// Key for the URL preference in SharedPreferences
  static const String prefKeyUrl = 'livestream_url';

  /// Key for the backoffice URL preference in SharedPreferences
  static const String prefKeyBackofficeUrl = 'livestream_backoffice_url';

  /// Key for the use backoffice stream toggle in SharedPreferences
  static const String prefKeyUseBackofficeStream = 'livestream_use_backoffice_stream';

  /// Key for the replace workflow preference in SharedPreferences
  static const String prefKeyReplaceWorkflow = 'livestream_replace_workflow';

  /// Key for storing the previous workflow replacement state for reconnection
  static const String prefKeyPreviousWorkflowReplacement = 'previous_workflow_replacement';

  /// Key for the auto replace workflow preference in SharedPreferences
  static const String prefKeyAutoReplaceWorkflow = 'livestream_auto_replace_workflow';

  /// Default buffer timeout in milliseconds
  static const int bufferTimeoutMs = 10000;

  /// Default status check interval in seconds (reduced for better responsiveness)
  static const int statusCheckIntervalSeconds = 15;

  /// Default stream reconnect attempt interval in seconds
  static const int streamReconnectIntervalSeconds = 20;

  /// Extended reconnect interval when server is unavailable (seconds)
  static const int serverUnavailableReconnectIntervalSeconds = 60;

  /// Default stream initialization delay in milliseconds
  static const int streamInitDelayMs = 200;

  /// Timeout for reconnection attempts in minutes
  static const int reconnectionTimeoutMinutes = 1;

  /// Timeout for auto-detection of live camera in minutes
  static const int autoDetectionTimeoutMinutes = 3;
}

abstract class AlarmManagerConstants {
  /// Maximum time difference in minutes for stale alarm detection
  /// If an alarm is scheduled to run more than this many minutes in the past,
  /// it will be considered stale and skipped
  static const int staleAlarmThresholdMinutes = 5;
}

abstract class BackgroundServiceConstants {
  /// Maximum time to wait for service to stop (in milliseconds)
  /// Used when polling for service shutdown completion
  static const int serviceStopTimeoutMs = 3000;

  /// Interval between service status checks (in milliseconds)
  /// Used when polling to verify service has stopped
  static const int serviceStopPollIntervalMs = 100;
}
