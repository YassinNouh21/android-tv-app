import 'package:flutter/material.dart';
import 'package:mawaqit/i18n/l10n.dart';

/// Shows a confirmation dialog asking the user if they want to exit Quran mode.
/// Returns `true` if the user confirms, `false` otherwise.
Future<bool> showQuranModeExitDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(S.of(context).exitQuranModeTitle),
      content: Text(S.of(context).exitQuranModeMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(S.of(context).no),
        ),
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(S.of(context).yes),
        ),
      ],
    ),
  );
  return result ?? false;
}
