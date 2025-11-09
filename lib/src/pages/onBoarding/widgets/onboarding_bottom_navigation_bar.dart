import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/state_management/on_boarding/on_boarding.dart';
import 'package:mawaqit/src/widgets/InfoWidget.dart';
import 'package:mawaqit/src/widgets/mawaqit_icon_button.dart';
import 'package:mawaqit/src/widgets/mawaqit_back_icon_button.dart';
import 'package:sizer/sizer.dart';

/// Screen size breakpoints for responsive design
enum ScreenSize {
  compact, // < 600 (phones)
  medium, // 600-840 (small tablets, large phones in landscape)
  large, // > 840 (tablets, TV)
}

class OnboardingBottomNavigationBar extends ConsumerWidget {
  final VoidCallback onPreviousPressed;
  final VoidCallback onNextPressed;
  final FocusNode? nextButtonFocusNode;
  final VoidCallback? onSkipPressed;

  const OnboardingBottomNavigationBar({
    super.key,
    required this.onPreviousPressed,
    required this.onNextPressed,
    this.nextButtonFocusNode,
    this.onSkipPressed,
  });

  /// Determines the screen size category based on width
  ScreenSize _getScreenSize(double width) {
    if (width < 600) return ScreenSize.compact;
    if (width < 840) return ScreenSize.medium;
    return ScreenSize.large;
  }

  /// Determines if we should use portrait layout
  bool _shouldUsePortraitLayout(BuildContext context, double width) {
    final orientation = MediaQuery.of(context).orientation;
    final screenSize = _getScreenSize(width);

    // Use portrait layout for:
    // 1. Compact screens (< 600) regardless of orientation
    // 2. Medium screens in portrait orientation
    return screenSize == ScreenSize.compact || (screenSize == ScreenSize.medium && orientation == Orientation.portrait);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingNavigationProvider);

    return state.when(
      data: (data) {
        final isMosqueSearchSelected = ref.watch(mosqueManagerProvider).fold(() => false, (t) => true);
        final shouldShowFinish = data.shouldShowFinishButton(isMosqueSearchSelected);

        return LayoutBuilder(
          builder: (context, constraints) {
            final usePortraitLayout = _shouldUsePortraitLayout(context, constraints.maxWidth);

            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: usePortraitLayout ? 5.w : 3.w,
                vertical: usePortraitLayout ? 1.h : 2.h,
              ),
              child: usePortraitLayout
                  ? _buildPortraitLayout(
                      context,
                      data,
                      isMosqueSearchSelected,
                      shouldShowFinish,
                    )
                  : _buildLandscapeLayout(
                      context,
                      data,
                      isMosqueSearchSelected,
                      shouldShowFinish,
                    ),
            );
          },
        );
      },
      error: (e, s) => Container(),
      loading: () => Container(),
    );
  }

  /// Builds the portrait/mobile layout (vertical: dots on top, version + buttons on bottom)
  Widget _buildPortraitLayout(
    BuildContext context,
    dynamic data,
    bool isMosqueSearchSelected,
    bool shouldShowFinish,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top row: Dots indicator (centered)
        Center(
          child: _buildDotsIndicator(data, isCompact: true),
        ),
        SizedBox(height: 1.5.h),
        // Bottom row: Version (left) + Navigation buttons (right)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Version widget (left side)
            Flexible(
              flex: 2,
              child: _buildVersionWidget(context),
            ),
            SizedBox(width: 2.w),
            // Navigation buttons (right side)
            Flexible(
              flex: 5,
              child: _buildNavigationButtons(
                context,
                data,
                isMosqueSearchSelected,
                shouldShowFinish,
                isPortrait: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the landscape/tablet/TV layout (horizontal)
  Widget _buildLandscapeLayout(
    BuildContext context,
    dynamic data,
    bool isMosqueSearchSelected,
    bool shouldShowFinish,
  ) {
    return Row(
      children: [
        // Left section: Version widget
        Expanded(
          flex: 4,
          child: _buildVersionWidget(context),
        ),
        const Expanded(flex: 1, child: SizedBox()),
        // Center section: Dots indicator
        _buildDotsIndicator(data),
        const Expanded(flex: 1, child: SizedBox()),
        // Right section: Navigation buttons
        Expanded(
          flex: 4,
          child: _buildNavigationButtons(
            context,
            data,
            isMosqueSearchSelected,
            shouldShowFinish,
            isPortrait: false,
          ),
        ),
      ],
    );
  }

  /// Builds the version widget with overflow protection
  Widget _buildVersionWidget(BuildContext context) {
    return VersionWidget(
      style: TextStyle(
        color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(.5),
        fontSize: 8.sp,
        overflow: TextOverflow.ellipsis,
      ),
      textAlign: TextAlign.start,
    );
  }

  /// Builds the dots indicator
  Widget _buildDotsIndicator(dynamic data, {bool isCompact = false}) {
    return DotsIndicator(
      dotsCount: data.screenFlow.length,
      position: data.currentScreen,
      decorator: DotsDecorator(
        size: Size.square(isCompact ? 7.0 : 9.0),
        activeSize: Size(isCompact ? 15.0 : 21.0, isCompact ? 7.0 : 9.0),
        activeShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0)),
        spacing: EdgeInsets.all(isCompact ? 2 : 3),
      ),
    );
  }

  /// Builds the navigation buttons (Previous, Next/Skip/Finish)
  /// This shared method eliminates code duplication
  Widget _buildNavigationButtons(
    BuildContext context,
    dynamic data,
    bool isMosqueSearchSelected,
    bool shouldShowFinish, {
    required bool isPortrait,
  }) {
    return Row(
      mainAxisSize: isPortrait ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: isPortrait ? MainAxisAlignment.end : MainAxisAlignment.end,
      children: [
        // Previous button
        if (data.enablePreviousButton) ...[
          MawaqitBackIconButton(
            icon: Icons.arrow_back_rounded,
            label: S.of(context).previous,
            onPressed: onPreviousPressed,
          ),
          SizedBox(width: isPortrait ? 2.w : 1.w),
        ] else if (!isPortrait)
          // Invisible spacer for landscape layout to maintain alignment
          Opacity(
            opacity: 0,
            child: MawaqitBackIconButton(
              icon: Icons.arrow_back_rounded,
              label: S.of(context).previous,
              onPressed: onPreviousPressed,
            ),
          ),

        // Next/Skip/Finish button
        if (data.enableNextButton) _buildPrimaryButton(context, data, isMosqueSearchSelected, shouldShowFinish),
      ],
    );
  }

  /// Builds the primary action button (Next/Skip/Finish)
  Widget _buildPrimaryButton(
    BuildContext context,
    dynamic data,
    bool isMosqueSearchSelected,
    bool shouldShowFinish,
  ) {
    // Skip button has priority if available
    if (data.canSkipCurrentScreen && onSkipPressed != null) {
      return MawaqitIconButton(
        focusNode: nextButtonFocusNode ?? FocusNode(),
        icon: Icons.navigate_next,
        label: S.of(context).skip,
        onPressed: onSkipPressed,
        isAutoFocus: true,
      );
    }

    // Next/Finish button - enabled when not on mosque search or mosque is selected
    if (!data.isMosqueSearchScreen || (data.isMosqueSearchScreen && isMosqueSearchSelected)) {
      return MawaqitIconButton(
        focusNode: nextButtonFocusNode ?? FocusNode(),
        icon: data.isLastItem ? Icons.check : Icons.arrow_forward_rounded,
        label: shouldShowFinish ? S.of(context).finish : S.of(context).next,
        onPressed: onNextPressed,
      );
    }

    // Disabled button when on mosque search without selection
    return Opacity(
      opacity: 0.5,
      child: MawaqitIconButton(
        focusNode: nextButtonFocusNode ?? FocusNode(),
        icon: Icons.arrow_forward_rounded,
        label: S.of(context).next,
        onPressed: null,
      ),
    );
  }
}
