import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:mawaqit/main.dart';
import 'package:notification_overlay/notification_overlay.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mawaqit/src/const/constants.dart';

class PermissionsManager {
  static const String _permissionsGrantedKey = 'permissions_granted';
  static const String _nativeMethodsChannel = 'nativeMethodsChannel';
  static const int _androidAlarmPermissionSdk = 33;

  /// Checks if permissions have already been granted
  static Future<bool> arePermissionsGranted() async {
    final prefs = await SharedPreferences.getInstance();
    final previouslyGranted = prefs.getBool(_permissionsGrantedKey) ?? false;

    if (await _isDeviceRooted()) {
      return await _handleRootedDevice(prefs, previouslyGranted);
    }

    // Always verify actual permissions with system
    final verified = await _verifyCurrentPermissions(prefs);

    return verified;
  }

  /// Check if device is rooted
  static Future<bool> _isDeviceRooted() async {
    final isRooted =
        await MethodChannel(TurnOnOffTvConstant.kNativeMethodsChannel).invokeMethod(TurnOnOffTvConstant.kCheckRoot);
    return isRooted;
  }

  /// Handle rooted device logic
  static Future<bool> _handleRootedDevice(SharedPreferences prefs, bool previouslyGranted) async {
    if (!previouslyGranted) {
      await prefs.setBool(_permissionsGrantedKey, true);
    }
    return true;
  }

  /// Verify current permission status with system
  static Future<bool> _verifyCurrentPermissions(SharedPreferences prefs) async {
    final overlayGranted = await _checkOverlayPermission();
    final alarmGranted = await _checkAlarmPermission();

    final allGranted = overlayGranted && alarmGranted;

    if (!allGranted) {
      await prefs.setBool(_permissionsGrantedKey, false);
      return false;
    }

    // Mark as granted in SharedPreferences if not already marked
    final previouslyGranted = prefs.getBool(_permissionsGrantedKey) ?? false;
    if (!previouslyGranted) {
      await prefs.setBool(_permissionsGrantedKey, true);
    }

    return true;
  }

  /// Check overlay permission status
  static Future<bool> _checkOverlayPermission() async {
    final granted = await NotificationOverlay.checkOverlayPermission();
    return granted;
  }

  /// Check alarm permission status
  static Future<bool> _checkAlarmPermission() async {
    if (!Platform.isAndroid) return true;

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;

    if (androidInfo.version.sdkInt >= _androidAlarmPermissionSdk) {
      try {
        final granted = await MethodChannel(_nativeMethodsChannel).invokeMethod<bool>('checkExactAlarmPermission');
        return granted ?? false;
      } on PlatformException catch (e) {
        logger.e('Failed to check alarm permission', error: e);
        return false;
      }
    } else {
      return true;
    }
  }

  /// Marks permissions as granted in shared preferences
  static Future<void> _markPermissionsAsGranted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionsGrantedKey, true);
  }

  /// Initialize permissions only if needed
  static Future<void> initializePermissions() async {
    // Quick check if permissions were already granted previously
    if (await arePermissionsGranted()) {
      return;
    }

    final isRooted = await _isDeviceRooted();
    final deviceModel = await _getDeviceModel();

    // Handle overlay permissions
    final overlayGranted = await _handleOverlayPermissions(deviceModel, isRooted);

    // Check for exact alarm permission
/*     final alarmPermissionGranted = await _checkAndRequestExactAlarmPermission();
 */
    // Mark permissions as granted only if all permissions were successfully granted
    if (overlayGranted /* && alarmPermissionGranted */) {
      await _markPermissionsAsGranted();
    }
  }

  /// Handle overlay permissions based on device model and root status
  /// Returns true if permission was granted
  static Future<bool> _handleOverlayPermissions(String deviceModel, bool isRooted) async {
    final methodChannel = MethodChannel(TurnOnOffTvConstant.kNativeMethodsChannel);
    final isPermissionGranted = await NotificationOverlay.checkOverlayPermission();

    // If permission is already granted, return true
    if (isPermissionGranted) {
      return true;
    }

    // Special handling for ONVO devices
    if (_isOnvoDevice(deviceModel)) {
      return await _handleOnvoOverlayPermission(methodChannel);
    }

    // Handle overlay permission based on root status
    if (isRooted) {
      return await _handleRootedOverlayPermission(methodChannel);
    } /*  else {
      return await _handleUserOverlayPermission();
    } */
    return false;
  }

  /// Check if device is ONVO
  static bool _isOnvoDevice(String deviceModel) {
    return RegExp(r'ONVO.*').hasMatch(deviceModel);
  }

  /// Handle ONVO device overlay permission
  static Future<bool> _handleOnvoOverlayPermission(MethodChannel methodChannel) async {
    try {
      await methodChannel.invokeMethod("grantOnvoOverlayPermission");
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Handle rooted device overlay permission
  static Future<bool> _handleRootedOverlayPermission(MethodChannel methodChannel) async {
    try {
      await methodChannel.invokeMethod("grantOverlayPermission");
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Handle user overlay permission request
  static Future<bool> _handleUserOverlayPermission() async {
    final granted = await NotificationOverlay.requestOverlayPermission();
    return granted;
  }

  /// Get device model information
  static Future<String> _getDeviceModel() async {
    final hardware = await DeviceInfoPlugin().androidInfo;
    return hardware.model;
  }

  /// Check and request exact alarm permissions if needed (Android 13+)
  /// Returns true if permission is granted or not needed
  static Future<bool> _checkAndRequestExactAlarmPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    // Only needed for Android 13 (API level 33) and above
    if (sdkInt >= _androidAlarmPermissionSdk) {
      return await _requestExactAlarmPermission();
    } else {
      return true;
    }
  }

  /// Request exact alarm permission for Android 13+
  static Future<bool> _requestExactAlarmPermission() async {
    try {
      // First check if permission is already granted using native method
      final canSchedule = await MethodChannel(_nativeMethodsChannel).invokeMethod('checkExactAlarmPermission');

      if (canSchedule) {
        return true;
      }

      final requestResult = await MethodChannel(_nativeMethodsChannel).invokeMethod('requestExactAlarmPermission');

      if (requestResult) {
        return false; // Return false because user needs to grant manually and app will check again later
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Check if device should auto-initialize permissions
  /// Returns true if device is rooted OR Android version < 11 (API 30)
  /// Android 11+ non-rooted devices must use the permission screen
  static Future<bool> shouldAutoInitializePermissions() async {
    // Check if device is rooted - rooted devices always auto-initialize
    final isRooted = await _isDeviceRooted();
    if (isRooted) {
      return true;
    }
/* 
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    // Android 11 is SDK 30
    // Non-rooted Android 11+ must use permission screen
    final shouldAutoInit = sdkInt < 34; */

    return isRooted;
  }
}
