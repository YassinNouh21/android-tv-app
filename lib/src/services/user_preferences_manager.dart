import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/helpers/Api.dart';
import 'package:mawaqit/src/helpers/AppRouter.dart';
import 'package:mawaqit/src/helpers/RelativeSizes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Application display modes
enum AppMode {
  normal,
  announcement,
  quran,
}

const announcementsStoreKey = 'UserPreferencesManager.AnnouncementsOnly';
const appModeStoreKey = 'UserPreferencesManager.app.mode';
const _developerModeKey = 'UserPreferencesManager.developer.mode.enabled';
const _secondaryScreenKey = 'UserPreferencesManager.secondary.screen.enabled';
const _webViewModeKey = 'UserPreferencesManager.webView.mode.enabled';
const _forceStagingKey = 'UserPreferencesManager.api.settings.staging';
const _forcePreProdKey = 'UserPreferencesManager.api.settings.preprod';
const _screenOrientation = 'UserPreferencesManager.screen.orientation';
const quranLastPortraitKey = 'quran_last_portrait';
const _hijriAdjustments = 'UserPreferencesManager.hijriAdjustments';
const _adhanNotificationKey = 'UserPreferencesManager.adhan.notification.enabled';

/// this manager responsible for managing user preferences
class UserPreferencesManager extends ChangeNotifier {
  UserPreferencesManager() {
    init();
  }

  Future<UserPreferencesManager> init() async {
    _sharedPref = await SharedPreferences.getInstance();

    // Migrate old announcementsOnly boolean to new appMode enum
    _migrateAnnouncementsOnly();


    // Set environment based on preferences (Pre-Prod > Staging > Production)
    if (forcePreProduction) {
      Api.usePreProdApi(true);
    } else if (forceStaging) {
      Api.useStagingApi(true);
    }
    // Production is default when both are false
    forceOrientation();

    return this;
  }

  /// Migrates the old announcementsOnly boolean preference to the new appMode enum.
  /// This ensures existing users who had announcement mode enabled retain their setting.
  void _migrateAnnouncementsOnly() {
    if (_sharedPref.containsKey(announcementsStoreKey)) {
      final oldValue = _sharedPref.getBool(announcementsStoreKey) ?? false;
      // Only migrate if appMode hasn't been set yet
      if (!_sharedPref.containsKey(appModeStoreKey) && oldValue) {
        _sharedPref.setString(appModeStoreKey, AppMode.announcement.name);
      }
      // Remove the old key after migration
      _sharedPref.remove(announcementsStoreKey);
    }
  }

  late SharedPreferences _sharedPref;

  bool get announcementsOnly => appMode == AppMode.announcement;

  set announcementsOnly(bool value) {
    appMode = value ? AppMode.announcement : AppMode.normal;
  }

  /// Get the current app mode (defaults to normal mode)
  AppMode get appMode {
    final modeString = _sharedPref.getString(appModeStoreKey);
    if (modeString == null) return AppMode.normal;
    return AppMode.values.firstWhere(
      (e) => e.name == modeString,
      orElse: () => AppMode.normal,
    );
  }

  /// Set the app mode
  set appMode(AppMode value) {
    _sharedPref.setString(appModeStoreKey, value.name);
    notifyListeners();
  }

  bool get developerModeEnabled => _sharedPref.getBool(_developerModeKey) ?? false;

  set developerModeEnabled(bool value) {
    _sharedPref.setBool(_developerModeKey, value);
    notifyListeners();
  }

  bool get isSecondaryScreen => _sharedPref.getBool(_secondaryScreenKey) ?? false;

  set isSecondaryScreen(bool value) {
    _sharedPref.setBool(_secondaryScreenKey, value);
    notifyListeners();
  }

  bool get webViewMode => _sharedPref.getBool(_webViewModeKey) ?? false;

  set webViewMode(bool value) {
    _sharedPref.setBool(_webViewModeKey, value);
    notifyListeners();
  }

  bool get forceStaging => _sharedPref.getBool(_forceStagingKey) ?? false;

  /// Enables or disables the staging API environment.
  /// When enabled, automatically disables pre-production to ensure mutual exclusion.
  /// The value is persisted to SharedPreferences and triggers listeners.
  set forceStaging(bool value) {
    // If enabling staging, disable pre-prod
    if (value) {
      _sharedPref.setBool(_forcePreProdKey, false);
    }

    // Switch environment
    Api.useStagingApi(value);

    // Save preference
    _sharedPref.setBool(_forceStagingKey, value);

    // Show success toast
    final context = AppRouter.navigationKey.currentContext;
    Fluttertoast.showToast(
      msg: context != null ? S.of(context).environmentSwitchSuccess : "Environment switched successfully",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Color(0xff490094),
      textColor: Colors.white,
      fontSize: 16.0,
    );

    notifyListeners();
  }

  bool get forcePreProduction => _sharedPref.getBool(_forcePreProdKey) ?? false;

  /// Enables or disables the pre-production API environment.
  /// When enabled, automatically disables staging to ensure mutual exclusion.
  /// The value is persisted to SharedPreferences and triggers listeners.
  set forcePreProduction(bool value) {
    // If enabling pre-prod, disable staging
    if (value) {
      _sharedPref.setBool(_forceStagingKey, false);
    }

    // Switch environment
    Api.usePreProdApi(value);

    // Save preference
    _sharedPref.setBool(_forcePreProdKey, value);

    // Show success toast
    final context = AppRouter.navigationKey.currentContext;
    Fluttertoast.showToast(
      msg: context != null ? S.of(context).environmentSwitchSuccess : "Environment switched successfully",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Color(0xff490094),
      textColor: Colors.white,
      fontSize: 16.0,
    );

    notifyListeners();
  }

  /// orientation section  ///

  /// return true if the screen orientation is horizontal
  /// null will use the default orientation
  bool get orientationLandscape =>
      _sharedPref.getBool(_screenOrientation) ?? RelativeSizes.instance.orientation == Orientation.landscape;

  /// set the screen orientation
  /// null will use the default orientation based on the device
  set orientationLandscape(bool? value) {
    if (value == null) {
      _sharedPref.remove(_screenOrientation);
    } else {
      _sharedPref.setBool(_screenOrientation, value);
    }
    forceOrientation();
    notifyListeners();
  }

  void forceOrientation() {
    switch (orientationLandscape) {
      case true:
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      case false:
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
    }
  }

  void toggleOrientation() {
    orientationLandscape = !orientationLandscape;
  }

  /// calculate the orientation based on the user preferences and screen size
  Orientation get calculatedOrientation {
    switch (orientationLandscape) {
      case true:
        return Orientation.landscape;
      case false:
        return Orientation.portrait;
      default:
        return RelativeSizes.instance.orientation;
    }
  }

  int? get hijriAdjustments => _sharedPref.getInt(_hijriAdjustments);

  set hijriAdjustments(int? value) {
    if (value == null) {
      _sharedPref.remove(_hijriAdjustments);
    } else {
      _sharedPref.setInt(_hijriAdjustments, value);
    }
    notifyListeners();
  }

  bool get adhanNotificationEnabled => _sharedPref.getBool(_adhanNotificationKey) ?? false;

  set adhanNotificationEnabled(bool value) {
    _sharedPref.setBool(_adhanNotificationKey, value);
    notifyListeners();
  }
}
