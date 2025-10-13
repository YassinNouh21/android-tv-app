import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mawaqit/src/pages/mosque_search/widgets/permission_screen_with_button.dart';
import 'package:mawaqit/src/services/permissions_manager.dart';
import 'package:page_transition/page_transition.dart';

/// A utility class to handle permission screen navigation logic
class PermissionScreenNavigator {
  /// Checks permissions and shows permission screen if needed
  ///
  /// Returns `true` if permissions are granted or auto-initialized,
  /// `false` if user needs to grant permissions manually
  static Future<bool> checkAndShowPermissionScreen({
    required BuildContext context,
    required Option<FocusNode> selectedNode,
    VoidCallback? onComplete,
  }) async {
    if (!context.mounted) return false;

    final isRooted = await PermissionsManager.shouldAutoInitializePermissions();

    if (isRooted) {
      onComplete?.call();
      return true;
    }

    final permissionsGranted = await PermissionsManager.arePermissionsGranted();

    if (!permissionsGranted) {
      if (!context.mounted) return false;

      await Navigator.push(
        context,
        PageTransition(
          type: PageTransitionType.fade,
          alignment: Alignment.center,
          child: PermissionScreenWithButton(
            selectedNode: selectedNode,
          ),
        ),
      );

      if (context.mounted) {
        onComplete?.call();
      }
      return false;
    } else {
      onComplete?.call();
      return true;
    }
  }
}
