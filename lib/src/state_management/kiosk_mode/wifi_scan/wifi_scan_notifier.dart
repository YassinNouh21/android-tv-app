import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mawaqit/main.dart';
import 'package:mawaqit/src/pages/onBoarding/widgets/widgets.dart';
import 'package:mawaqit/src/state_management/kiosk_mode/wifi_scan/wifi_scan_state.dart';
import 'package:wifi_scan/wifi_scan.dart';

class WifiScanNotifier extends AsyncNotifier<WifiScanState> {
  @override
  Future<WifiScanState> build() async {
    // Grant location through su before the first scan so wifi_scan never has
    // to pop a system permission dialog (see [_scan]'s askPermissions: false).
    await _ensureLocationPermission();
    return _scan();
  }

  /// Grants ACCESS_FINE_LOCATION and enables location services via the app's
  /// root (su) channel. Swallows failures — a denied grant just means the
  /// scan below reports no permission, which the UI handles gracefully.
  Future<void> _ensureLocationPermission() async {
    try {
      await platform.invokeMethod('addLocationPermission');
      await platform.invokeMethod('grantFineLocationPermission');
      logger.i('[wifi-debug] scan: location granted via su');
    } on PlatformException catch (e, s) {
      logger.e('[wifi-debug] scan: location grant via su failed: $e', stackTrace: s);
    }
  }

  /// Scans for nearby networks. Throws on failure so Riverpod surfaces a clean
  /// [AsyncError]; callers must not assume [state] always has a value.
  ///
  /// Uses the `wifi_scan` plugin rather than `wifi_hunter`: the latter holds
  /// the Flutter result inside a `SCAN_RESULTS` broadcast receiver it never
  /// unregisters, so a second system scan broadcast makes it reply twice and
  /// crash the app ("Reply already submitted"). `wifi_scan` reads results via
  /// an explicit call instead, so it has no such race.
  Future<WifiScanState> _scan() async {
    logger.i('[wifi-debug] scan: starting wifi_scan');
    try {
      // askPermissions: false — location is granted upfront via su in
      // [_ensureLocationPermission]; letting the plugin ask would pop a
      // system dialog the user must dismiss.
      final canGet = await WiFiScan.instance.canGetScannedResults(askPermissions: false);
      if (canGet != CanGetScannedResults.yes) {
        throw StateError('cannot read wifi scan results: $canGet');
      }
      // Best-effort fresh scan; if Android throttles it we still read the
      // platform's last cached results below.
      if (await WiFiScan.instance.canStartScan(askPermissions: false) == CanStartScan.yes) {
        await WiFiScan.instance.startScan();
      }
      final results = await WiFiScan.instance.getScannedResults();
      logger.i('[wifi-debug] scan: succeeded with ${results.length} networks');
      return WifiScanState(
        accessPoints: results,
        hasPermission: true,
        status: Status.connecting,
      );
    } catch (e, s) {
      logger.e('[wifi-debug] scan: FAILED: $e', stackTrace: s);
      rethrow;
    }
  }

  Future<void> connectToWifi(String ssid, String security, String password) async {
    logger.i('[wifi-debug] connectToWifi: invoked for ssid="$ssid"');
    // A failed scan leaves no state value; nothing to connect from.
    final current = state.value;
    if (current == null) {
      logger.e('[wifi-debug] connectToWifi: ABORT — state has no value '
          '(isLoading=${state.isLoading} hasError=${state.hasError}); '
          'password screen spinner will not clear');
      return;
    }
    try {
      logger.i('[wifi-debug] connectToWifi: calling native connectToWifi channel');
      final isSuccess = await platform.invokeMethod('connectToWifi', {
        "ssid": ssid,
        "security": security,
        "password": password,
      }) as bool? ??
          false;
      logger.i('[wifi-debug] connectToWifi: native returned isSuccess=$isSuccess');
      if (isSuccess) {
        state = AsyncData(current.copyWith(status: Status.connected));
      } else {
        state = AsyncData(current.copyWith(status: Status.error));
      }
    } on PlatformException catch (e, s) {
      // Keep a value in state (Status.error) rather than emitting an AsyncError
      // the password screen would skip, leaving its spinner stuck forever.
      logger.e('[wifi-debug] connectToWifi: PlatformException: $e', stackTrace: s);
      state = AsyncData(current.copyWith(status: Status.error));
    } catch (e, s) {
      // Any non-platform error (e.g. a bad cast) must still resolve the state,
      // otherwise the spinner hangs.
      logger.e('[wifi-debug] connectToWifi: unexpected error: $e', stackTrace: s);
      state = AsyncData(current.copyWith(status: Status.error));
    }
  }

  Future<void> retry() async {
    logger.i('[wifi-debug] retry: rescanning');
    state = const AsyncLoading<WifiScanState>();
    state = await AsyncValue.guard(_scan);
    logger.i('[wifi-debug] retry: done — hasError=${state.hasError} '
        'networks=${state.value?.accessPoints.length}');
  }
}

final wifiScanNotifierProvider = AsyncNotifierProvider<WifiScanNotifier, WifiScanState>(WifiScanNotifier.new);
