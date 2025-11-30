import 'dart:async';

import 'package:mawaqit/i18n/AppLanguage.dart';
import 'package:mawaqit/src/const/constants.dart';
import 'package:mawaqit/src/helpers/Api.dart';
import 'package:mawaqit/src/helpers/StreamGenerator.dart';
import 'package:mawaqit/src/services/FeatureManager.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:mawaqit/src/services/user_preferences_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// this is a wrapper class for all crashlytics related functions
class CrashlyticsWrapper {
  static StreamSubscription? _subscription;

  static init(FutureOr<void>? Function() appRunner) async {
    await SentryFlutter.init(
      (options) async {
        options.dsn = kSentryDns;

        // Initialize FeatureManager to check the feature flag
        // Use the singleton instance to avoid context dependency during init
        final featureManager = FeatureManager.instance;

        // Check if Session Replay feature flag is enabled
        final isReplayEnabled = featureManager.isFeatureEnabled('sentry_session_replay');

        if (isReplayEnabled) {
          // Enable error-only replay when feature flag is ON
          options.replay.sessionSampleRate = 0.0; // No normal sessions
          options.replay.onErrorSampleRate = 1.0; // All error sessions
          options.privacy.maskAllText = false;
          options.privacy.maskAllImages = false;
        }

        // Defer PackageInfo call to avoid binding initialization error
        try {
          final info = await PackageInfo.fromPlatform();
          options.release = 'androidtv@${info.version}';
        } catch (e) {
          // Fallback if PackageInfo fails - use a default version identifier
          options.release = 'androidtv@unknown';
        }

        try {
          final prefs = UserPreferencesManager();
          await prefs.init();
          if (prefs.forceStaging) options.environment = 'staging';
        } catch (e) {
          // Continue initialization even if preferences fail
        }
      },
      appRunner: appRunner,
    );

    /// keep the user scope updated
    _subscription?.cancel();
    _subscription = generateStream(Duration(minutes: 10)).listen((event) {
      updateUserScope();
    });
  }

  /// setup the user scope for crashlytics
  ///
  static Future<void> updateUserScope() async {
    final userData = await Api.prepareUserData();

    // Get mosque UUID from MosqueManager
    final mosqueUUID = await MosqueManager.loadLocalUUID();

    // Get current language
    final language = await AppLanguage.getCountryCode();

    Sentry.configureScope((scopes) {
      if (userData == null) {
        scopes.setUser(null);
        scopes.setContexts("user-data", null);

        // Still set mosque UUID and language if available
        if (mosqueUUID != null) {
          scopes.setTag('mosque-uuid', mosqueUUID);
        }
        if (language != null) {
          scopes.setTag('language', language);
        }
        return;
      }
      final (uuid, data) = userData;

      scopes.setTag('app-version', data['app-version']);
      scopes.setTag('android-version', data['android-version']);

      // Add mosque UUID as a tag for better filtering
      if (mosqueUUID != null) {
        scopes.setTag('mosque-uuid', mosqueUUID);
      }

      // Add language as a tag
      if (language != null) {
        scopes.setTag('language', language);
      }

      scopes.setUser(SentryUser(
        username: uuid,
        id: data['device-id'],
      ));

      // Include mosque UUID and language in context data
      final enhancedData = Map<String, dynamic>.from(data);
      if (mosqueUUID != null) {
        enhancedData['mosque-uuid'] = mosqueUUID;
      }
      if (language != null) {
        enhancedData['language'] = language;
      }

      scopes.setContexts("user-data", enhancedData);
    });
  }

  /// function to report an exception to crashlytics
  static Future<void> sendException(dynamic exception, StackTrace stackTrace) async {
    await Sentry.captureException(exception, stackTrace: stackTrace);
  }

  /// Reports a hadith-related exception with detailed context for debugging.
  ///
  /// This method captures information about why hadith display failed,
  /// allowing filtering in Sentry dashboard by:
  /// - `hadith_failure_reason`: 'api_failed_no_cache' | 'offline_no_cache'
  /// - `hadith_language`: The requested language (e.g., 'fr', 'ar')
  /// - `had_cached_value`: Whether cache was available
  /// - `is_online`: Whether device was online when failure occurred
  static Future<void> sendHadithException({
    required String reason,
    required String language,
    required bool hadCachedValue,
    required bool isOnline,
    dynamic originalError,
  }) async {
    await Sentry.captureException(
      Exception('Hadith unavailable: $reason'),
      stackTrace: StackTrace.current,
      withScope: (scope) {
        scope.setTag('hadith_failure_reason', reason);
        scope.setTag('hadith_language', language);
        scope.setTag('had_cached_value', hadCachedValue.toString());
        scope.setTag('is_online', isOnline.toString());
        scope.setContexts('hadith_debug', {
          'reason': reason,
          'language': language,
          'had_cached_value': hadCachedValue,
          'is_online': isOnline,
          'original_error': originalError?.toString(),
        });
      },
    );
  }

  /// Helper method to check if replay is currently enabled
  static bool isReplayEnabled() {
    final featureManager = FeatureManager.instance;
    return featureManager.isFeatureEnabled('sentry_session_replay');
  }
}
