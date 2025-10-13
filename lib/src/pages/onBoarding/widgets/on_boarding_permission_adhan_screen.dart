import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:fpdart/fpdart.dart' as fp;
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/services/notification/prayer_schedule_service.dart';
import 'package:mawaqit/src/services/user_preferences_manager.dart';
import 'package:mawaqit/src/services/permissions_manager.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:mawaqit/src/widgets/ScreenWithAnimation.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class PermissionAdhanScreen extends StatelessWidget {
  final VoidCallback? onNext;
  final bool isOnboarding;
  final fp.Option<FocusNode> nextButtonFocusNode;
  final bool showAppBar;
  final bool useAnimation;
  final String? animationName;

  const PermissionAdhanScreen({
    super.key,
    this.onNext,
    this.isOnboarding = false,
    this.nextButtonFocusNode = const fp.None(),
    this.showAppBar = false,
    this.useAnimation = false,
    this.animationName,
  });

  Future<void> _handleToggle(BuildContext context, UserPreferencesManager userPrefs, bool value) async {
    userPrefs.adhanNotificationEnabled = value;

    // Only request permissions if user enables the toggle
    if (value) {
      // Initialize permissions (this will request them from user)
      await PermissionsManager.initializePermissions();

      // Check if permissions were actually granted
      final permissionsGranted = await PermissionsManager.arePermissionsGranted();

      if (!permissionsGranted) {
        // You could show a snackbar or dialog here
      }
    } else {
      await PrayerScheduleService.clearAllScheduledPrayers();
    }

    if (!isOnboarding) {
      onNext?.call();
    } else {
      nextButtonFocusNode.fold(
        () => null,
        (focusNode) {
          Future.delayed(Duration(milliseconds: 300), () {
            if (focusNode.canRequestFocus) {
              focusNode.requestFocus();
            }
          });
        },
      );
    }
  }

  /// Called when user proceeds to next screen or completes onboarding
  /// Called when user proceeds to next screen or completes onboarding
  static Future<void> scheduleIfEnabled(BuildContext context) async {
    final userPrefs = context.read<UserPreferencesManager>();

    // Only schedule if user enabled notifications
    if (!userPrefs.adhanNotificationEnabled) {
      return;
    }

    // Always do a fresh check of permissions (not from SharedPreferences)
    // This ensures we get the actual current system permission state
    final permissionsGranted = await PermissionsManager.arePermissionsGranted();

    if (!permissionsGranted) {
      return;
    }

    final mosqueManager = context.read<MosqueManager>();
    if (mosqueManager.times != null && mosqueManager.mosqueConfig != null) {
      final service = FlutterBackgroundService();
      await PrayerScheduleService.schedulePrayerTasks(
        mosqueManager.times!,
        mosqueManager.mosqueConfig,
        mosqueManager.isAdhanVoiceEnabled,
        mosqueManager.salahIndex,
        service,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userPrefs = context.watch<UserPreferencesManager>();
    final theme = Theme.of(context);
    final tr = S.of(context);
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    // Adjust font sizes based on orientation
    final double headerFontSize = isPortrait ? 14.sp : 16.sp;
    final double subtitleFontSize = isPortrait ? 6.sp : 8.sp;
    final double descriptionFontSize = isPortrait ? 6.sp : 8.sp;
    final double titleFontSize = isPortrait ? 8.sp : 10.sp;

    // Adjust width factor based on orientation
    final double widthFactor = isPortrait ? 0.9 : 0.75;

    final content = FractionallySizedBox(
      widthFactor: widthFactor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(theme, tr, headerFontSize, subtitleFontSize, context),
          SizedBox(height: isPortrait ? 3.h : 4.h),
          _buildToggleSection(
            context: context,
            theme: theme,
            tr: tr,
            userPrefs: userPrefs,
            titleFontSize: titleFontSize,
            descriptionFontSize: descriptionFontSize,
            isPortrait: isPortrait,
          ),
        ],
      ),
    );

    // If using animation, wrap in ScreenWithAnimationWidget
    if (useAnimation) {
      return ScreenWithAnimationWidget(
        animation: animationName ?? 'settings',
        hasBackButton: showAppBar,
        child: Center(child: content),
      );
    }

    // Otherwise, use standard Scaffold with optional AppBar
    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
            )
          : null,
      body: SafeArea(
        child: Center(child: content),
      ),
    );
  }

  /// Builds the header section with title and subtitle
  Widget _buildHeader(
      ThemeData theme, AppLocalizations tr, double headerFontSize, double subtitleFontSize, BuildContext context) {
    return Column(
      children: [
        AutoSizeText(
          S.of(context).prayerTimeNotificationTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: headerFontSize,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          minFontSize: 10,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 1.5.h),
        AutoSizeText(
          S.of(context).prayerTimeNotificationDesc,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.textTheme.bodyLarge?.color?.withOpacity(0.8),
            fontSize: subtitleFontSize,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
          maxLines: 4,
          minFontSize: 8,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Builds the toggle switch section
  Widget _buildToggleSection({
    required BuildContext context,
    required ThemeData theme,
    required AppLocalizations tr,
    required UserPreferencesManager userPrefs,
    required double titleFontSize,
    required double descriptionFontSize,
    required bool isPortrait,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isPortrait ? 3.w : 4.w,
        vertical: isPortrait ? 1.5.h : 2.h,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Switch(
            value: userPrefs.adhanNotificationEnabled,
            onChanged: (value) => _handleToggle(context, userPrefs, value),
            activeColor: theme.primaryColor,
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  S.of(context).enablePrayerReminders,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: titleFontSize,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 0.3.h),
                Text(
                  S.of(context).enablePrayerRemindersDesc,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    fontSize: descriptionFontSize,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
