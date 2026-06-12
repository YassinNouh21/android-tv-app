import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mawaqit/src/models/address_model.dart';
import 'package:mawaqit/src/pages/home/widgets/AboveSalahBar.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:mawaqit/src/state_management/livestream_viewer/live_stream_notifier.dart';
import 'package:mawaqit/src/state_management/livestream_viewer/live_stream_state.dart';
import 'package:mawaqit/src/state_management/quran/quran/quran_notifier.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'package:mawaqit/src/helpers/AppDate.dart';
import 'package:mawaqit/src/helpers/RelativeSizes.dart';
import 'package:mawaqit/src/helpers/connectivity_provider.dart';
import 'package:mawaqit/src/pages/home/sub_screens/JumuaHadithSubScreen.dart';
import 'package:mawaqit/src/services/user_preferences_manager.dart';
import 'package:mawaqit/src/widgets/time_widget.dart';

class JummuaLive extends ConsumerStatefulWidget {
  const JummuaLive({
    Key? key,
    this.onDone,
  }) : super(key: key);

  final VoidCallback? onDone;

  @override
  ConsumerState createState() => _JummuaLiveState();
}

class _JummuaLiveState extends ConsumerState<JummuaLive> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(quranNotifierProvider.notifier).exitQuranMode();
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final mosqueManager = context.read<MosqueManager>();
    final userPrefs = context.watch<UserPreferencesManager>();
    final connectivity = ref.watch(connectivityProvider);
    final streamStateAsync = ref.watch(liveStreamProvider);

    final jumuaaDisableInMosque = !userPrefs.isSecondaryScreen && mosqueManager.typeIsMosque;

    return connectivity.when(
      data: (value) => streamStateAsync.when(
        data: (streamState) {
          return _switchStreamWidget(
            value,
            mosqueManager,
            jumuaaDisableInMosque,
            streamState,
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
        error: (error, stack) => _switchStreamWidget(
          value,
          mosqueManager,
          jumuaaDisableInMosque,
          LiveStreamViewerState(),
        ),
      ),
      loading: () => const CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
      ),
      error: (_, __) => _switchStreamWidget(
        ConnectivityStatus.disconnected,
        mosqueManager,
        jumuaaDisableInMosque,
        LiveStreamViewerState(),
      ),
    );
  }

  /// Returns fallback widget based on priority:
  /// 1. Hadith reminder if enabled
  /// 2. Black screen if enabled
  /// 3. Exit to prayer times screen
  Widget _buildFallbackWidget(MosqueManager mosqueManager) {
    // Priority 1: Hadith reminder if enabled
    if (mosqueManager.mosqueConfig!.jumuaDhikrReminderEnabled == true) {
      return JumuaHadithSubScreen(onDone: widget.onDone);
    }

    // Priority 2: Black screen if enabled
    if (mosqueManager.mosqueConfig!.jumuaBlackScreenEnabled == true) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: JumuaCenteredClock(),
      );
    }

    // Priority 3: Exit to prayer times screen
    widget.onDone?.call();
    return const SizedBox.shrink();
  }

  Widget _switchStreamWidget(
    ConnectivityStatus connectivityStatus,
    MosqueManager mosqueManager,
    bool jumuaaDisableInMosque,
    LiveStreamViewerState streamState,
  ) {
    final streamTriggerMode = context.read<UserPreferencesManager>().streamTriggerMode;

    // Disabled mode: never show stream regardless of other conditions
    if (streamTriggerMode == StreamTriggerMode.disabled) {
      return _buildFallbackWidget(mosqueManager);
    }

    // If jumuaa is disabled in mosque, check for dhikr/black screen
    if (jumuaaDisableInMosque) {
      return _buildFallbackWidget(mosqueManager);
    }

    // If disconnected, go to fallback priority
    if (connectivityStatus == ConnectivityStatus.disconnected) {
      return _buildFallbackWidget(mosqueManager);
    }

    // For connected state with jumuaa enabled, check unified stream:
    // The streamState now automatically prioritizes backoffice URL > user-configured URL

    // Check if stream is enabled and active
    final isStreamActive = streamState.isEnabled &&
        streamState.streamStatus == LiveStreamStatus.active &&
        connectivityStatus != ConnectivityStatus.disconnected;

    // Get notifier to access controllers
    final notifier = ref.read(liveStreamProvider.notifier);

    // Priority 1: RTSP Stream if working
    if (isStreamActive && streamState.streamType == LiveStreamType.rtsp && notifier.videoController != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Video(
                  controller: notifier.videoController!,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: AboveSalahBar(),
            ),
          ],
        ),
      );
    }

    // Priority 2: YouTube Stream if working (from backoffice or settings)
    if (isStreamActive && streamState.streamType == LiveStreamType.youtubeLive && notifier.youtubeController != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: YoutubePlayer(
                  controller: notifier.youtubeController!,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: AboveSalahBar(),
            ),
          ],
        ),
      );
    }

    // No stream available, use fallback priority
    return _buildFallbackWidget(mosqueManager);
  }
}

class JumuaCenteredClock extends StatelessWidget {
  const JumuaCenteredClock();

  @override
  Widget build(BuildContext context) {
    final mosqueManager = context.watch<MosqueManager>();
    final is12Hours = mosqueManager.mosqueConfig?.timeDisplayFormat == '12';

    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, _) {
        final now = AppDateTime.now();
        return Center(
          child: TimeWidget.fromDate(
            dateTime: now,
            show24hFormat: !is12Hours,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20.vw,
              height: 1,
            ),
          ),
        );
      },
    );
  }
}
