import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/helpers/connectivity_provider.dart';
import 'package:mawaqit/src/models/address_model.dart';
import 'package:mawaqit/src/pages/home/widgets/schedule_audio_indicator.dart';
import 'package:mawaqit/src/state_management/quran/recite/quran_audio_player_notifier.dart';
import 'package:mawaqit/src/state_management/quran/recite/quran_audio_player_state.dart';
import 'package:mawaqit/src/state_management/quran/schedule_listening/audio_control_notifier.dart';
import 'package:mawaqit/src/state_management/quran/schedule_listening/audio_control_state.dart';
import 'package:mawaqit/src/state_management/quran/schedule_listening/schedule_listening_notifier.dart';

sealed class AudioController {
  void tap(WidgetRef ref);

  void longPress(WidgetRef ref);
}

class ListeningController extends AudioController {
  @override
  void tap(WidgetRef ref) {
    final isPlaying = ref.read(quranPlayerNotifierProvider).value?.playerState == AudioPlayerState.playing;
    if (isPlaying) {
      Fluttertoast.showToast(
        msg: S.current.holdOkToStop,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
      );
      ref.read(quranPlayerNotifierProvider.notifier).pause();
    } else {
      ref.read(quranPlayerNotifierProvider.notifier).play();
    }
  }

  @override
  void longPress(WidgetRef ref) => ref.read(quranPlayerNotifierProvider.notifier).saveAndStop();
}

class ScheduleController extends AudioController {
  @override
  void tap(WidgetRef ref) {
    final isPlaying = ref.read(audioControlProvider).value?.status == AudioStatus.playing;
    if (isPlaying) {
      Fluttertoast.showToast(
        msg: S.current.holdOkToStop,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
      );
      ref.read(audioControlProvider.notifier).pausePlayback();
    } else {
      ref.read(audioControlProvider.notifier).resumePlayback();
    }
  }

  @override
  void longPress(WidgetRef ref) => ref.read(audioControlProvider.notifier).stopPlayback();
}

/// Returns the controller for whichever audio source is currently taking priority.
/// Order: playing listening > schedule > paused listening.
/// A paused listening session ranks below schedule so it doesn't trap the remote
/// when schedule audio is audible — fixing the "paused traps the remote" bug.
final activeAudioControllerProvider = Provider<AudioController?>((ref) {
  final playerAsync = ref.watch(quranPlayerNotifierProvider);
  final playerState = playerAsync.value?.playerState;

  if (playerState == AudioPlayerState.playing) {
    return ListeningController();
  }

  final connectivity = ref.watch(connectivityProvider);
  final hasInternet = connectivity.hasValue && connectivity.value == ConnectivityStatus.connected;
  final audioAsync = ref.watch(audioControlProvider);
  final scheduleAsync = ref.watch(scheduleProvider);
  final scheduleActive = hasInternet &&
      audioAsync.hasValue &&
      scheduleAsync.hasValue &&
      scheduleAsync.value!.isScheduleEnabled &&
      !(audioAsync.value!.isStopped) &&
      isInScheduleWindow(scheduleAsync.value!.startTime, scheduleAsync.value!.endTime);

  if (scheduleActive) {
    return ScheduleController();
  }

  if (playerState == AudioPlayerState.paused) {
    return ListeningController();
  }

  return null;
});
