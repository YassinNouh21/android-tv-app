import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mawaqit/src/const/constants.dart';
import 'package:mawaqit/src/helpers/AppDate.dart';
import 'package:mawaqit/src/helpers/RelativeSizes.dart';
import 'package:mawaqit/src/state_management/quran/schedule_listening/audio_control_notifier.dart';
import 'package:mawaqit/src/state_management/quran/schedule_listening/audio_control_state.dart';
import 'package:mawaqit/src/state_management/quran/schedule_listening/schedule_listening_notifier.dart';
import 'package:mawaqit/src/state_management/quran/quran/quran_notifier.dart';
import 'package:mawaqit/src/helpers/connectivity_provider.dart';
import 'package:mawaqit/src/models/address_model.dart';
import 'package:mawaqit/src/themes/UIShadows.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mawaqit/i18n/l10n.dart';

/// Checks whether the current time falls within the given schedule window.
/// Handles overnight windows (start > end) correctly.
bool isInScheduleWindow(TimeOfDay startTime, TimeOfDay endTime) {
  final mosqueNow = AppDateTime.now();
  final cur = mosqueNow.hour * 60 + mosqueNow.minute;
  final start = startTime.hour * 60 + startTime.minute;
  final end = endTime.hour * 60 + endTime.minute;
  return (start <= end)
      ? (cur >= start && cur < end)
      : (cur >= start || cur < end);
}

/// Returns true if scheduled Quran listening should be active right now.
/// Shared between the indicator widget and key handler.
bool isScheduleAudioActive(WidgetRef ref) {
  final connectivity = ref.read(connectivityProvider);
  final hasInternet =
      connectivity.hasValue && connectivity.value == ConnectivityStatus.connected;
  if (!hasInternet) return false;

  final audio = ref.read(audioControlProvider);
  if (!audio.hasValue) return false;

  final schedule = ref.read(scheduleProvider);
  if (!schedule.hasValue) return false;

  final s = schedule.value!;
  if (!s.isScheduleEnabled) return false;

  return isInScheduleWindow(s.startTime, s.endTime);
}

/// Audio indicator that replaces the countdown (SalahInWidget) in HomeTimeWidget.
/// Shows: [animated bars] surah name - qari name [pause/play] [stop]
class ScheduleAudioIndicator extends ConsumerStatefulWidget {
  const ScheduleAudioIndicator({super.key});

  @override
  ConsumerState<ScheduleAudioIndicator> createState() => _ScheduleAudioIndicatorState();
}

class _ScheduleAudioIndicatorState extends ConsumerState<ScheduleAudioIndicator> {
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _prefs = p);
    });
  }

  /// Persists the surah name for fallback on next restart.
  void _cacheSurahName(String surahName) {
    _prefs?.setString(BackgroundScheduleAudioServiceConstant.kSelectedSurahName, surahName);
  }

  String _resolveSurahName(BuildContext context, dynamic schedule, AsyncValue<dynamic> quranAsync) {
    if (schedule.isRandomEnabled) {
      return S.of(context).randomSurahSelection;
    }
    if (schedule.selectedSurahId != null && quranAsync.hasValue) {
      final suwar = quranAsync.value!.suwar;
      final match = suwar.where((s) => s.id == schedule.selectedSurahId).toList();
      if (match.isNotEmpty) {
        final name = match.first.name;
        _cacheSurahName(name);
        return name;
      }
    }
    return _prefs?.getString(BackgroundScheduleAudioServiceConstant.kSelectedSurahName) ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityProvider);
    final audioAsync = ref.watch(audioControlProvider);
    final scheduleAsync = ref.watch(scheduleProvider);
    final quranAsync = ref.watch(quranNotifierProvider);

    if (!audioAsync.hasValue || !scheduleAsync.hasValue) {
      return const SizedBox.shrink();
    }

    final hasInternet =
        connectivity.hasValue && connectivity.value == ConnectivityStatus.connected;
    final schedule = scheduleAsync.value!;
    final audioState = audioAsync.value!;

    if (!schedule.isScheduleEnabled || !hasInternet || audioState.isStopped) {
      return const SizedBox.shrink();
    }

    if (!isInScheduleWindow(schedule.startTime, schedule.endTime)) {
      return const SizedBox.shrink();
    }

    final isPlaying = audioState.status == AudioStatus.playing;
    final surahName = _resolveSurahName(context, schedule, quranAsync);

    final qariName = schedule.selectedReciter?.name ??
        _prefs?.getString(BackgroundScheduleAudioServiceConstant.kSelectedReciter) ??
        '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isPlaying)
          _AnimatedBars()
        else
          Icon(
            Icons.music_off_rounded,
            color: Colors.white70,
            size: 2.8.vwr,
          ),
        SizedBox(width: 1.vwr),
        Flexible(
          child: _ScrollingText(
            text: qariName.isNotEmpty ? '$surahName - $qariName' : surahName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 2.4.vwr,
              color: Colors.white,
              shadows: kHomeTextShadow,
            ),
          ),
        ),
        SizedBox(width: 1.5.vwr),
        // Pause/Play button
        GestureDetector(
          onTap: () => ref.read(audioControlProvider.notifier).togglePlayback(),
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
          onTap: () => ref.read(audioControlProvider.notifier).stopPlayback(),
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

/// Animated equalizer bars that pulse when audio is playing.
class _AnimatedBars extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        return Container(
          width: 0.35.vwr,
          margin: EdgeInsets.symmetric(horizontal: 0.07.vwr),
          child: _SingleBar(delay: i * 150),
        );
      }),
    );
  }
}

class _SingleBar extends StatefulWidget {
  final int delay;
  const _SingleBar({required this.delay});

  @override
  State<_SingleBar> createState() => _SingleBarState();
}

class _SingleBarState extends State<_SingleBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: 2.5.vwr * _animation.value,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }
}

/// Text that scrolls left then right when it overflows, stays static otherwise.
class _ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _ScrollingText({required this.text, required this.style});

  @override
  State<_ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<_ScrollingText>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _animController;
  bool _needsScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animController = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  @override
  void didUpdateWidget(_ScrollingText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _animController.stop();
      _needsScroll = false;
      _scrollController.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
    }
  }

  void _checkOverflow() {
    if (!mounted) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    _needsScroll = maxScroll > 0;
    if (_needsScroll) _runLoop(maxScroll);
  }

  Future<void> _runLoop(double maxScroll) async {
    while (mounted && _needsScroll) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_needsScroll) return;

      // Scroll to end
      final ms = (maxScroll / 30 * 1000).toInt();
      _animController.duration = Duration(milliseconds: ms);
      _animController.addListener(_onTick);
      await _animController.forward(from: 0);
      _animController.removeListener(_onTick);
      if (!mounted || !_needsScroll) return;

      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_needsScroll) return;

      // Scroll back
      _animController.addListener(_onTick);
      await _animController.reverse(from: 1);
      _animController.removeListener(_onTick);
      if (!mounted || !_needsScroll) return;
    }
  }

  void _onTick() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(
        _animController.value * _scrollController.position.maxScrollExtent,
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, style: widget.style, maxLines: 1),
    );
  }
}
