import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/helpers/RelativeSizes.dart';
import 'package:mawaqit/src/pages/home/widgets/schedule_audio_indicator.dart';
import 'package:mawaqit/src/state_management/quran/recite/quran_audio_player_notifier.dart';
import 'package:mawaqit/src/state_management/quran/recite/quran_audio_player_state.dart';
import 'package:mawaqit/src/state_management/quran/recite/recite_notifier.dart';
import 'package:mawaqit/src/themes/UIShadows.dart';

/// Returns true if the user-initiated Quran listening session is currently
/// playing or paused (i.e. audio that should keep going while the user
/// browses the home screen).
bool isListeningAudioActive(WidgetRef ref) {
  final player = ref.read(quranPlayerNotifierProvider);
  if (!player.hasValue) return false;
  final s = player.value!.playerState;
  return s == AudioPlayerState.playing || s == AudioPlayerState.paused;
}

/// Indicator shown on the home screen when the user has started a Quran
/// listening session and exited the player screen. Mirrors
/// [ScheduleAudioIndicator] but is driven by [quranPlayerNotifierProvider].
class ListeningAudioIndicator extends ConsumerWidget {
  const ListeningAudioIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(quranPlayerNotifierProvider);

    if (!playerAsync.hasValue) return const SizedBox.shrink();
    final state = playerAsync.value!;

    if (state.playerState != AudioPlayerState.playing && state.playerState != AudioPlayerState.paused) {
      return const SizedBox.shrink();
    }

    final isPlaying = state.playerState == AudioPlayerState.playing;
    final surahName = state.surahName;
    // state.reciterName is actually the moshaf/riwaya (e.g. "Hafs"). The
    // reciter (qari) himself lives on reciteNotifier as selectedReciter.
    final qariName = ref.watch(reciteNotifierProvider).maybeWhen(
          data: (s) => s.selectedReciter.fold(() => '', (r) => r.name),
          orElse: () => '',
        );
    final label = qariName.isNotEmpty ? '$surahName - $qariName' : surahName;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isPlaying)
          AnimatedBars()
        else
          Icon(
            Icons.music_off_rounded,
            color: Colors.white70,
            size: 2.8.vwr,
          ),
        SizedBox(width: 1.vwr),
        Flexible(
          child: ScrollingText(
            text: label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 2.4.vwr,
              color: Colors.white,
              shadows: kHomeTextShadow,
            ),
          ),
        ),
        SizedBox(width: 1.5.vwr),
        // Pause/Play button (long-press to stop, matching the schedule indicator)
        GestureDetector(
          onTap: () {
            if (isPlaying) {
              Fluttertoast.showToast(
                msg: S.of(context).holdOkToStop,
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
                backgroundColor: Colors.black54,
                textColor: Colors.white,
              );
              ref.read(quranPlayerNotifierProvider.notifier).pause();
            } else {
              ref.read(quranPlayerNotifierProvider.notifier).play();
            }
          },
          onLongPress: () => ref.read(quranPlayerNotifierProvider.notifier).saveAndStop(),
          child: Icon(
            isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: Colors.white,
            size: 3.2.vwr,
            shadows: kHomeTextShadow,
          ),
        ),
        SizedBox(width: 1.vwr),
        // Stop button
        GestureDetector(
          onTap: () => ref.read(quranPlayerNotifierProvider.notifier).saveAndStop(),
          child: Icon(
            Icons.stop_circle,
            color: Colors.white70,
            size: 3.2.vwr,
            shadows: kHomeTextShadow,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}
