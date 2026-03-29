import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:mawaqit/src/helpers/connectivity_provider.dart';
import 'package:mawaqit/src/models/address_model.dart';
import 'package:mawaqit/src/pages/home/widgets/SalahInWidget.dart';
import 'package:mawaqit/src/pages/home/widgets/schedule_audio_indicator.dart';
import 'package:mawaqit/src/state_management/quran/schedule_listening/audio_control_notifier.dart';
import 'package:mawaqit/src/state_management/quran/schedule_listening/schedule_listening_notifier.dart';

/// Switches between the countdown (SalahInWidget) and the audio indicator
/// depending on whether scheduled Quran audio is actively playing/paused.
/// Re-evaluates the schedule window every 30 seconds so the indicator
/// auto-hides when the window ends.
class CountdownOrAudioWidget extends ConsumerStatefulWidget {
  const CountdownOrAudioWidget({super.key});

  @override
  ConsumerState<CountdownOrAudioWidget> createState() => _CountdownOrAudioWidgetState();
}

class _CountdownOrAudioWidgetState extends ConsumerState<CountdownOrAudioWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityProvider);
    final audioAsync = ref.watch(audioControlProvider);
    final scheduleAsync = ref.watch(scheduleProvider);

    final hasInternet =
        connectivity.hasValue && connectivity.value == ConnectivityStatus.connected;

    if (hasInternet &&
        audioAsync.hasValue &&
        scheduleAsync.hasValue &&
        scheduleAsync.value!.isScheduleEnabled &&
        !audioAsync.value!.isStopped &&
        isInScheduleWindow(scheduleAsync.value!.startTime, scheduleAsync.value!.endTime)) {
      return const ScheduleAudioIndicator();
    }

    return const SalahInWidget();
  }
}
