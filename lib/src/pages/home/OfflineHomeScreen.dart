import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mawaqit/const/resource.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/domain/model/home_active_screen.dart';
import 'package:mawaqit/src/helpers/AppRouter.dart';
import 'package:mawaqit/src/helpers/RelativeSizes.dart';
import 'package:mawaqit/src/pages/ErrorScreen.dart';
import 'package:mawaqit/src/pages/MosqueSearchScreen.dart';
import 'package:mawaqit/src/pages/home/sub_screens/AnnouncementScreen.dart';
import 'package:mawaqit/src/pages/home/sub_screens/StreamReplacementScreen.dart';
import 'package:mawaqit/src/pages/home/widgets/mosque_background_screen.dart';
import 'package:mawaqit/src/pages/home/widgets/workflows/repeating_workflow_widget.dart';
import 'package:mawaqit/src/pages/home/workflow/app_workflow_screen.dart';
import 'package:mawaqit/src/pages/home/workflow/jumua_workflow_screen.dart';
import 'package:mawaqit/src/pages/home/workflow/normal_workflow.dart';
import 'package:mawaqit/src/pages/home/workflow/salah_workflow.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:mawaqit/src/services/user_preferences_manager.dart';
import 'package:mawaqit/src/state_management/livestream_viewer/live_stream_notifier.dart';
import 'package:mawaqit/src/state_management/livestream_viewer/live_stream_state.dart';
import 'package:mawaqit/src/pages/quran/quran_mode_screen.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

import '../HomeScreen.dart';

/// When true, OfflineHomeScreen shows prayer times instead of quran
/// even though appMode is still quran. This allows navigating freely
/// without stacking routes.
final quranHomeOverrideProvider = StateProvider<bool>((ref) => false);

class OfflineHomeScreen extends ConsumerWidget {
  OfflineHomeScreen({Key? key}) : super(key: key);

  Future<bool?> showClosingDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => new AlertDialog(
        title: new Text(S.of(context).closeApp),
        content: new Text(S.of(context).sureCloseApp),
        actions: <Widget>[
          new TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: new Text(S.of(context).cancel),
          ),
          SizedBox(height: 16),
          new TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: new Text(S.of(context).ok),
          ),
        ],
      ),
    );
  }

  /// show online home if enabled
  /// show the appropriate screen based on app mode
  Widget activeHomeScreen(
    MosqueManager mosqueManager,
    bool onlineMode,
    AppMode appMode,
    bool showHomeOverride,
  ) {
    if (onlineMode) return HomeScreen();

    // If quran mode but user navigated to "Home" via drawer, show prayer times
    if (appMode == AppMode.quran && showHomeOverride) {
      final now = mosqueManager.mosqueDate();
      return AppWorkflowScreen(
        key: ValueKey(now.day ^ now.month ^ now.year ^ (mosqueManager.mosque?.id ?? 1)),
      );
    }

    switch (appMode) {
      case AppMode.announcement:
        return AnnouncementScreen();
      case AppMode.quran:
        return const QuranModeScreen();
      case AppMode.normal:
      default:
        final now = mosqueManager.mosqueDate();
        return AppWorkflowScreen(
          key: ValueKey(now.day ^ now.month ^ now.year ^ (mosqueManager.mosque?.id ?? 1)),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    RelativeSizes.instance.size = MediaQuery.of(context).size;
    final mosqueProvider = context.watch<MosqueManager>();
    final userPrefs = context.watch<UserPreferencesManager>();
    final streamState = ref.watch(liveStreamProvider);
    final showHomeOverride = ref.watch(quranHomeOverrideProvider);

    if (!mosqueProvider.loaded)
      return ErrorScreen(
        title: S.of(context).reset,
        description: S.of(context).mosqueNotFoundMessage,
        image: R.ASSETS_IMG_ICON_EXIT_PNG,
        onTryAgain: () => AppRouter.push(MosqueSearchScreen(
          nextButtonFocusNode: None(),
        )),
        tryAgainText: S.of(context).changeMosque,
      );

    final shouldShowStream = streamState.valueOrNull?.shouldReplaceWorkflow == true;
    final isShowingQuran = userPrefs.appMode == AppMode.quran && !showHomeOverride;

    return WillPopScope(
      onWillPop: () async {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
          return false;
        }

        return await showClosingDialog(context) ?? false;
      },
      // If stream is active and replacing workflow, show only the stream
      // Otherwise show the normal app workflow
      child: shouldShowStream
          ? const StreamReplacementScreen()
          // Quran mode has its own full-screen UI — skip the mosque background
          // and drawer wrapper so arrow keys reach the Quran page navigation.
          : isShowingQuran
              ? SafeArea(
                  bottom: true,
                  child: activeHomeScreen(
                    mosqueProvider,
                    userPrefs.webViewMode,
                    userPrefs.appMode,
                    showHomeOverride,
                  ),
                )
              : MosqueBackgroundScreen(
                  key: ValueKey(mosqueProvider.mosque?.uuid),
                  child: SafeArea(
                    bottom: true,
                    child: activeHomeScreen(
                      mosqueProvider,
                      userPrefs.webViewMode,
                      userPrefs.appMode,
                      showHomeOverride,
                    ),
                  ),
                ),
    );
  }
}
