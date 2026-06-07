import 'package:equatable/equatable.dart';
import 'package:wifi_scan/wifi_scan.dart';

enum Status {
  connecting,
  connected,
  error,
}

class WifiScanState extends Equatable {
  final List<WiFiAccessPoint> accessPoints;
  final bool hasPermission;
  final Status status;

  /// True when the last failure was because the network already has a saved
  /// config owned by Android Settings (addNetwork=-1) — the user must forget it
  /// in Settings before the app can reconnect.
  final bool isSystemOwnedError;

  WifiScanState({
    required this.accessPoints,
    required this.hasPermission,
    this.status = Status.connecting,
    this.isSystemOwnedError = false,
  });

  WifiScanState copyWith({
    List<WiFiAccessPoint>? accessPoints,
    bool? shouldCheckCan,
    Status? status,
    bool? hasPermission,
    bool? isSystemOwnedError,
  }) {
    return WifiScanState(
      status: status ?? this.status,
      accessPoints: accessPoints ?? this.accessPoints,
      hasPermission: hasPermission ?? this.hasPermission,
      isSystemOwnedError: isSystemOwnedError ?? this.isSystemOwnedError,
    );
  }

  @override
  List get props => [
        accessPoints,
        hasPermission,
        status,
        isSystemOwnedError,
      ];
}
