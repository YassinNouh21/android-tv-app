import 'package:flutter/widgets.dart';

/// Opts [child] out of the app-wide font scaling by forcing [TextScaler.noScaling].
///
/// `main.dart` sets a global `textScaler` from the in-app `AppFontSize` setting.
/// Screens that size text manually (`fontSize * appFontSizeScale`, usually inside a
/// `FittedBox`) must opt out here, otherwise the global scaler would apply on top of
/// the manual multiplier (double scaling) or `FittedBox` would cancel it out.
///
/// Centralizes the previously copy-pasted
/// `MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling), child: ...)`.
class NoTextScaling extends StatelessWidget {
  const NoTextScaling({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: child,
    );
  }
}
