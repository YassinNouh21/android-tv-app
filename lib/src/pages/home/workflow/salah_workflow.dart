import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mawaqit/src/const/constants.dart';
import 'package:mawaqit/src/models/calendar/MawaqitHijriCalendar.dart';
import 'package:mawaqit/src/pages/home/sub_screens/AfterSalahAzkarScreen.dart';
import 'package:mawaqit/src/pages/home/sub_screens/DuaaBetweenAdhanAndIqama.dart';
import 'package:mawaqit/src/pages/home/sub_screens/DuaaEftarScreen.dart';
import 'package:mawaqit/src/pages/home/sub_screens/IqamaSubScreen.dart';
import 'package:mawaqit/src/pages/home/sub_screens/IqamaaCountDownSubScreen.dart';
import 'package:mawaqit/src/pages/home/sub_screens/normal_home.dart';
import 'package:mawaqit/src/pages/home/widgets/workflows/repeating_workflow_widget.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:mawaqit/src/services/user_preferences_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mawaqit/src/pages/home/workflow/workflow_segments.dart';
import 'package:mawaqit/src/state_management/livestream_viewer/live_stream_notifier.dart';
import 'package:mawaqit/src/state_management/livestream_viewer/live_stream_state.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../widgets/workflows/WorkFlowWidget.dart';

/// handling the logic form 5min before adhan -> the last of after salah azkar
class SalahWorkflowScreen extends ConsumerStatefulWidget {
  const SalahWorkflowScreen({
    Key? key,
    required this.onDone,
    required this.salahIndex,
  }) : super(key: key);

  final void Function() onDone;
  final int salahIndex;

  @override
  ConsumerState<SalahWorkflowScreen> createState() => _SalahWorkflowScreenState();
}

class _SalahWorkflowScreenState extends ConsumerState<SalahWorkflowScreen> {
  late final MosqueManager _mosqueManager;

  /// Latched once the stream takes over this prayer. Keeps the regular items
  /// disabled even if the stream drops mid-prayer — otherwise a rebuild would
  /// re-enable them and replay dua/iqama/azkar after the stream item ends.
  bool _streamTookOver = false;

  @override
  void initState() {
    super.initState();
    _mosqueManager = context.read<MosqueManager>();
  }

  @override
  void dispose() {
    _mosqueManager.showFlashAgain();
    super.dispose();
  }

  void _onWorkflowComplete() {
    widget.onDone();
  }

  Widget _buildPrayerStreamView({required VoidCallback onDone}) {
    final notifier = ref.read(liveStreamProvider.notifier);
    // ref.read is reactive enough here: build() watches liveStreamProvider, so
    // any status change rebuilds the workflow and re-invokes this builder.
    final streamState = ref.read(liveStreamProvider).valueOrNull;

    // Stream dropped mid-prayer: show the normal in-prayer screen until the
    // notifier's reconnect logic flips the status back to active.
    if (streamState == null || streamState.streamStatus != LiveStreamStatus.active) {
      return _mosqueManager.mosqueConfig?.blackScreenWhenPraying == true
          ? Container(color: Colors.black)
          : NormalHomeSubScreen();
    }

    if (streamState.streamType == LiveStreamType.rtsp && notifier.videoController != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Video(controller: notifier.videoController!),
          ),
        ),
      );
    }

    if (streamState.streamType == LiveStreamType.youtubeLive && notifier.youtubeController != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: YoutubePlayer(
              controller: notifier.youtubeController!,
              onEnded: (_) => onDone(),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget beforeSalahTime(
    MosqueManager mosqueManger,
    int currentSalah,
    MawaqitHijriCalendar hijri,
  ) {
    final currentSalahTime = mosqueManger.actualTimes()[currentSalah];
    return RepeatingWorkFlowWidget(
      child: NormalHomeSubScreen(),
      items: [
        RepeatingWorkflowItem(
          builder: (context, next) => DuaaEftarScreen(),
          duration: 60.seconds,
          dateTime: currentSalahTime.add(-2.minutes),
          showInitial: () => mosqueManger.nextSalahAfter() < 2.minutes,
          disabled: currentSalah != 3 || hijri.islamicMonth != 8,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mosqueManger = context.watch<MosqueManager>();
    final mosqueConfig = mosqueManger.mosqueConfig!;
    final userPrefs = context.watch<UserPreferencesManager>();

    final hijri = mosqueManger.mosqueHijriDate(userPrefs.hijriAdjustments);
    final currentSalah = widget.salahIndex;
    final now = mosqueManger.mosqueDate();
    final currentSalahTime = mosqueManger.actualTimes()[currentSalah];
    final currentIqamaTime = mosqueManger.actualIqamaTimes()[currentSalah];
    final isFajrPray = currentSalah == 0;
    final isAsrPray = currentSalah == 2;
    final iqamaEndTime = currentIqamaTime.add(Duration(minutes: 1));
    final salahTime = mosqueConfig.duaAfterPrayerShowTimes[currentSalah];
    final salahEndTime = iqamaEndTime.add(
      Duration(minutes: int.tryParse(salahTime) ?? 0),
    );

    final streamState = ref.watch(liveStreamProvider);
    final isStreamActive = streamState.valueOrNull?.streamStatus == LiveStreamStatus.active;
    final streamMode = userPrefs.streamTriggerMode;
    final streamAllowed = !mosqueManger.typeIsMosque || userPrefs.isSecondaryScreen;

    // Stream covers from end-of-adhan through end-of-azkar — mirror the items
    // the regular workflow would have run if the stream weren't replacing it.
    // Salah window only counts if iqama is enabled (otherwise the iqama / salah
    // / azkar items are all disabled). Azkar only counts if dua-after-prayer is
    // enabled (AfterSalahAzkar exits early otherwise). Fajr/Asr show a second
    // azkar item, which we approximate with another kAzkarDuration.
    final iqamaEnabled = mosqueConfig.iqamaEnabled != false;
    final azkarEnabled = iqamaEnabled && mosqueConfig.duaAfterPrayerEnabled != false;
    final extendedAzkarShown = azkarEnabled && (isFajrPray || isAsrPray);

    final salahWindow = iqamaEnabled ? salahEndTime.difference(now) : Duration.zero;
    final azkarPart =
        (azkarEnabled ? kAzkarDuration : Duration.zero) + (extendedAzkarShown ? kAzkarDuration : Duration.zero);
    final streamDuration = (salahWindow.isNegative ? Duration.zero : salahWindow) + azkarPart;

    if (streamMode == StreamTriggerMode.jumuaAndPrayers && streamAllowed && isStreamActive) {
      _streamTookOver = true;
    }
    final streamCoversRemainder = _streamTookOver;

    final workFlowItems = [
      WorkFlowItem(
        duration: mosqueManger.nextSalahAfter(),
        skip: mosqueManger.nextSalahAfter() > Duration(minutes: 6),
        builder: (context, next) => beforeSalahTime(mosqueManger, currentSalah, hijri),
      ),
      ...adhanAndDuaaSegment(
        mosque: mosqueManger,
        ref: ref,
        adhanTime: currentSalahTime,
        now: now,
        duaaDisabled: streamCoversRemainder,
      ),

      // Stream for jumuaAndPrayers: starts right after adhan (the segment's
      // duaa is disabled above when the stream takes over), covers the full
      // remaining prayer duration (dua + iqama + salah + azkar).
      // Disabled must mirror [streamCoversRemainder] exactly: mid-workflow
      // transitions only honor `disabled` (skip is initial-position only), so
      // an inactive stream must disable this item or the screen stays blank
      // for the whole prayer window.
      WorkFlowItem(
        builder: (context, next) => _buildPrayerStreamView(onDone: next),
        duration: streamDuration,
        disabled: !streamCoversRemainder,
        skip: !isStreamActive,
      ),
      WorkFlowItem(
        builder: (context, next) => DuaaBetweenAdhanAndIqamaaScreen(
          onDone: next,
        ),
        disabled: mosqueConfig.duaAfterAzanEnabled == false || streamCoversRemainder,
        skip: true,
      ),
      WorkFlowItem(
        builder: (context, next) =>
            IqamaaCountDownSubScreen(onDone: next, currentSalahIndex: currentSalah, iqamaTime: currentIqamaTime),
        skip: now.isAfter(currentIqamaTime),
        disabled: mosqueManger.mosqueConfig?.iqamaEnabled == false || streamCoversRemainder,
      ),
      WorkFlowItem(
        builder: (context, next) => IqamaSubScreen(),
        duration: Duration(seconds: mosqueConfig.iqamaDisplayTime ?? 30),
        skip: now.isAfter(iqamaEndTime),
        disabled: mosqueManger.mosqueConfig?.iqamaEnabled == false || streamCoversRemainder,
      ),
      WorkFlowItem(
        builder: (context, next) =>
            mosqueConfig.blackScreenWhenPraying == true ? Container(color: Colors.black) : NormalHomeSubScreen(),
        skip: now.isAfter(salahEndTime),
        duration: mosqueManger.currentSalahDuration,
        disabled: mosqueConfig.iqamaEnabled == false || streamCoversRemainder,
      ),
      WorkFlowItem(
        builder: (context, next) => AfterSalahAzkar(
          key: const ValueKey('regular_azkar'),
          onDone: next,
        ),
        disabled:
            mosqueConfig.iqamaEnabled == false || mosqueConfig.duaAfterPrayerEnabled == false || streamCoversRemainder,
      ),
      WorkFlowItem(
        builder: (context, next) => AfterSalahAzkar(
          key: const ValueKey('asr_fajr_azkar'),
          onDone: next,
          isAfterAsrOrFajr: true,
          isAfterAsr: isAsrPray,
          azkarTitle: isFajrPray ? AzkarConstant.kAzkarSabahAfterPrayer : AzkarConstant.kAzkarAsrAfterPrayer,
        ),
        disabled: mosqueConfig.iqamaEnabled == false ||
            (!isFajrPray && !isAsrPray) ||
            mosqueConfig.duaAfterPrayerEnabled == false ||
            streamCoversRemainder,
      ),
    ];

    return ContinuesWorkFlowWidget(
      onDone: _onWorkflowComplete,
      workFlowItems: workFlowItems,
    );
  }
}
