import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/pages/onBoarding/widgets/on_boarding_permission_adhan_screen.dart';

/// A wrapper widget that displays the permission screen with a styled "Ok" button
/// Used when accessing mosque search from settings (not during onboarding)
class PermissionScreenWithButton extends StatefulWidget {
  final Option<FocusNode> selectedNode;

  const PermissionScreenWithButton({
    super.key,
    required this.selectedNode,
  });

  @override
  State<PermissionScreenWithButton> createState() => _PermissionScreenWithButtonState();
}

class _PermissionScreenWithButtonState extends State<PermissionScreenWithButton> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: PermissionAdhanScreen(
                isOnboarding: false,
                nextButtonFocusNode: widget.selectedNode,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
