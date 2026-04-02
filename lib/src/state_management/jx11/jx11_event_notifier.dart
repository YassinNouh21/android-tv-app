import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Events sent by the JX-11 Bluetooth ring via MethodChannel from Android.
enum Jx11Event {
  swipeLeft,
  swipeRight,
  rollerUp,
  rollerDown,
  volumeUp,
  volumeDown,
  playPause,
  middleButton,
  tap;

  /// True for any event that logically means "go to next / forward / down".
  bool get isNext => switch (this) {
        swipeRight || rollerDown || volumeUp => true,
        swipeLeft || rollerUp || volumeDown => false,
        playPause || middleButton || tap => false,
      };

  /// True for any event that logically means "go to previous / backward / up".
  bool get isPrevious => switch (this) {
        swipeLeft || rollerUp || volumeDown => true,
        swipeRight || rollerDown || volumeUp => false,
        playPause || middleButton || tap => false,
      };

  /// True for any event that logically means "activate / select / confirm".
  bool get isActivate => switch (this) {
        playPause || middleButton || tap => true,
        swipeLeft || swipeRight || rollerUp || rollerDown => false,
        volumeUp || volumeDown => false,
      };
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

const _channel = MethodChannel('jx11Channel');

/// Enable or disable JX-11 input handling on the Android side.
/// Call with `true` when entering Quran mode, `false` when leaving.
Future<void> setJx11Enabled(bool enabled) async {
  try {
    await _channel.invokeMethod('setEnabled', enabled);
  } catch (e) {
    debugPrint('[JX-11] Failed to set enabled=$enabled: $e');
  }
}

/// StreamProvider-based JX-11 event handler.
/// Uses a StreamController so rapid-fire events are never dropped.
/// keepAlive() prevents the MethodChannel handler from being nulled during
/// screen transitions, which would cause JX-11 events to be silently lost.
final jx11EventProvider = StreamProvider.autoDispose<Jx11Event>((ref) {
  ref.keepAlive();

  final controller = StreamController<Jx11Event>();

  Future<void> handleEvent(MethodCall call) async {
    if (call.method != 'jx11Event') return;
    final name = call.arguments;
    if (name is! String) return;
    try {
      controller.add(Jx11Event.values.byName(name));
    } on ArgumentError {
      debugPrint('[JX-11] Unknown event: "$name"');
    }
  }

  _channel.setMethodCallHandler(handleEvent);
  ref.onDispose(() {
    _channel.setMethodCallHandler(null);
    controller.close();
  });

  return controller.stream;
});

// ---------------------------------------------------------------------------
// Reusable focus helpers — keep JX-11 handling DRY across screens
// ---------------------------------------------------------------------------

/// Move focus forward / backward through the focus tree.
void jx11TraverseFocus(Jx11Event event) {
  if (event.isNext) {
    FocusManager.instance.primaryFocus?.nextFocus();
  } else if (event.isPrevious) {
    FocusManager.instance.primaryFocus?.previousFocus();
  } else if (event.isActivate) {
    jx11ActivateFocused();
  }
}

/// Invoke [ActivateIntent] on the currently focused widget.
void jx11ActivateFocused() {
  final focused = FocusManager.instance.primaryFocus;
  if (focused?.context != null) {
    Actions.maybeInvoke(focused!.context!, const ActivateIntent());
  }
}

/// Move directional focus (useful for grid layouts).
void jx11DirectionalFocus(TraversalDirection direction) {
  final focused = FocusManager.instance.primaryFocus;
  if (focused?.context != null) {
    Actions.maybeInvoke(
      focused!.context!,
      DirectionalFocusIntent(direction),
    );
  }
}
