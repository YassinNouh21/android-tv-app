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

            if (usePortraitLayout) {
              // Portrait mode: New responsive layout
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 5.w,
                  vertical: 1.h,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top row: Dots indicator (centered)
                    Center(
                      child: DotsIndicator(
                        dotsCount: data.screenFlow.length,
                        position: data.currentScreen,
                        decorator: DotsDecorator(
                          size: const Size.square(7.0),
                          activeSize: const Size(15.0, 7.0),
                          activeShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0)),
                          spacing: const EdgeInsets.all(2),
                        ),
                      ),
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
                          child: VersionWidget(
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(.5),
                              fontSize: 8.sp,
                              overflow: TextOverflow.ellipsis,
                            ),
                            textAlign: TextAlign.start,
                          ),
                        ),
                        SizedBox(width: 2.w),
                        // Navigation buttons (right side)
                        Flexible(
                          flex: 5,
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (data.enablePreviousButton) ...[
                                MawaqitBackIconButton(
                                  icon: Icons.arrow_back_rounded,
                                  label: S.of(context).previous,
                                  onPressed: onPreviousPressed,
                                ),
                                SizedBox(width: 2.w),
                              ],
                              // Next/Skip/Finish button
                              if (data.enableNextButton)
                                _buildPrimaryButton(context, data, isMosqueSearchSelected, shouldShowFinish),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            // Landscape mode: Original implementation
            return Container(
              padding: const EdgeInsets.only(left: 30, right: 30, bottom: 20),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: VersionWidget(
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(.5),
                      ),
                    ),
                  ),
                  const Expanded(flex: 1, child: SizedBox()),
                  DotsIndicator(
                    dotsCount: data.screenFlow.length,
                    position: data.currentScreen,
                    decorator: DotsDecorator(
                      size: const Size.square(9.0),
                      activeSize: const Size(21.0, 9.0),
                      activeShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0)),
                      spacing: const EdgeInsets.all(3),
                    ),
                  ),
                  const Expanded(flex: 1, child: SizedBox()),
                  Expanded(
                    flex: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Visibility(
                          visible: data.enablePreviousButton,
                          replacement: Opacity(
                            opacity: 0,
                            child: MawaqitBackIconButton(
                              icon: Icons.arrow_back_rounded,
                              label: S.of(context).previous,
                              onPressed: onPreviousPressed,
                            ),
                          ),
                          child: MawaqitBackIconButton(
                            icon: Icons.arrow_back_rounded,
                            label: S.of(context).previous,
                            onPressed: onPreviousPressed,
                          ),
                        ),
                        if (data.enablePreviousButton) const SizedBox(width: 5),

                        // Fixed conditional widget section
                        if (data.enableNextButton)
                          // Only show the button when it's either:
                          // 1. Not a mosque search screen, OR
                          // 2. A mosque search screen WITH a mosque selected
                          if (data.canSkipCurrentScreen && onSkipPressed != null)
                            MawaqitIconButton(
                              focusNode: nextButtonFocusNode ?? FocusNode(),
                              icon: Icons.navigate_next,
                              label: S.of(context).skip,
                              onPressed: onSkipPressed,
                              isAutoFocus: true,
                            )
                          else if (!data.isMosqueSearchScreen || (data.isMosqueSearchScreen && isMosqueSearchSelected))
                            MawaqitIconButton(
                              focusNode: nextButtonFocusNode ?? FocusNode(),
                              icon: data.isLastItem ? Icons.check : Icons.arrow_forward_rounded,
                              label: shouldShowFinish ? S.of(context).finish : S.of(context).next,
                              onPressed: onNextPressed,
                            )
                          else
                            // Show disabled button when on mosque search without selection
                            Opacity(
                              opacity: 0.5,
                              child: MawaqitIconButton(
                                focusNode: nextButtonFocusNode ?? FocusNode(),
                                icon: Icons.arrow_forward_rounded,
                                label: S.of(context).next,
                                onPressed: null, // Disabled button
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      error: (e, s) => Container(),
      loading: () => Container(),
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
