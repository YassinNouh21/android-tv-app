import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

/// Reusable onboarding toggle button. Single [OutlinedButton] styled via
/// [ButtonStyle] so the focus node survives selection changes.
class ToggleButtonWidget extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onPressed;
  final String label;
  final TextStyle? textStyle;
  final bool isPortrait;

  /// Optional focus node so callers can drive/observe focus (TV remote).
  final FocusNode? focusNode;

  /// Whether the button should request focus when it first appears.
  final bool autofocus;

  const ToggleButtonWidget({
    super.key,
    required this.isSelected,
    required this.onPressed,
    required this.label,
    this.textStyle,
    this.isPortrait = false,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    // Dynamic vertical padding based on screen size and orientation
    final verticalPadding = isPortrait ? (screenWidth > 600 ? 1.2.h : 1.0.h) : (screenWidth > 600 ? 1.8.h : 1.5.h);

    // Ensure font size is responsive but has a minimum size
    final effectiveTextStyle = textStyle ?? TextStyle(fontSize: isPortrait ? 8.sp : 10.sp);

    final focusColor = theme.focusColor;

    return OutlinedButton(
      focusNode: focusNode,
      autofocus: autofocus,
      onPressed: onPressed,
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        minimumSize: WidgetStatePropertyAll(Size(100.w, 0)),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            vertical: verticalPadding,
            horizontal: isPortrait ? 1.w : 2.w,
          ),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (isSelected) return theme.primaryColor;
          if (states.contains(WidgetState.focused)) {
            return theme.primaryColor.withOpacity(0.12);
          }
          return Colors.transparent;
        }),
        foregroundColor: WidgetStatePropertyAll(
          isSelected ? Colors.white : theme.colorScheme.onSurface,
        ),
        overlayColor: WidgetStatePropertyAll(focusColor.withOpacity(0.12)),
        side: WidgetStateProperty.resolveWith((states) {
          // A clear, thick focus ring so the remote position is obvious on TV.
          if (states.contains(WidgetState.focused)) {
            return BorderSide(color: focusColor, width: 3);
          }
          return BorderSide(
            color: isSelected ? theme.primaryColor : theme.dividerColor,
            width: 1.5,
          );
        }),
      ),
      child: Text(
        label,
        style: effectiveTextStyle.copyWith(
          height: 1.2,
          color: isSelected ? Colors.white : effectiveTextStyle.color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }
}
