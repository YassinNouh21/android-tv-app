import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mawaqit/main.dart';
import 'package:mawaqit/src/pages/onBoarding/widgets/widgets.dart';
import 'package:mawaqit/src/state_management/kiosk_mode/wifi_scan/wifi_scan_state.dart';
import 'package:wifi_hunter/wifi_hunter.dart';

class WifiScanNotifier extends AsyncNotifier<WifiScanState> {
  @override
  Future<WifiScanState> build() => _scan();

  /// Scans for nearby networks. Throws on failure so Riverpod surfaces a clean
  /// [AsyncError]; callers must not assume [state] always has a value.
  Future<WifiScanState> _scan() async {
    logger.i('[wifi-debug] scan: starting WiFiHunter.huntWiFiNetworks');
    try {
      final result = await WiFiHunter.huntWiFiNetworks;
      logger.i('[wifi-debug] scan: succeeded with ${result?.results.length ?? 0} networks');
      return WifiScanState(
        accessPoints: result?.results ?? const [],
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
