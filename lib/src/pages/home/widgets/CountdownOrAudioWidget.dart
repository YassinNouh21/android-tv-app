import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:mawaqit/src/pages/home/widgets/SalahInWidget.dart';
import 'package:mawaqit/src/pages/home/widgets/audio_controller.dart';
import 'package:mawaqit/src/pages/home/widgets/listening_audio_indicator.dart';
import 'package:mawaqit/src/pages/home/widgets/schedule_audio_indicator.dart';

/// Switches between the countdown (SalahInWidget), the listening-mode audio
/// indicator, and the scheduled-audio indicator depending on which audio
/// session is active. Re-evaluates the schedule window every 30 seconds so the
/// schedule indicator auto-hides when its window ends.
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
    final controller = ref.watch(activeAudioControllerProvider);

    if (controller is ListeningController) {
      return const ListeningAudioIndicator();
    }
    if (controller is ScheduleController) {
      return ScheduleAudioIndicator();
    }
    return SalahInWidget();
  }
}
