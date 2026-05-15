import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mawaqit/src/helpers/time_utils.dart';
import 'package:mawaqit/src/pages/home/sub_screens/AfterSalahAzkarScreen.dart';
import 'package:mawaqit/src/pages/home/sub_screens/JummuaLive.dart';
import 'package:mawaqit/src/pages/home/workflow/normal_workflow.dart';
import 'package:mawaqit/src/pages/home/widgets/workflows/WorkFlowWidget.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// show the back screen during the jumuaa
class JumuaaWorkflowScreen extends StatelessWidget {
  const JumuaaWorkflowScreen({Key? key, this.onDone, this.jumuaaTime}) : super(key: key);
  final VoidCallback? onDone;

  /// The specific Jumua session time to use for this workflow.
  /// If null, falls back to the first configured Jumua time.
  final DateTime? jumuaaTime;

  @override
  Widget build(BuildContext context) {
    final mosqueManager = context.read<MosqueManager>();
    final now = mosqueManager.mosqueDate();

    final config = mosqueManager.mosqueConfig;
    final jumuaaTimeout = config?.jumuaTimeout ?? 30;

    final salahTimeRaw = config?.duaAfterPrayerShowTimes.elementAtOrNull(1);
    final salahTime = int.tryParse(salahTimeRaw ?? '') ?? 0;
    if (salahTimeRaw != null && int.tryParse(salahTimeRaw) == null) {
      Sentry.captureMessage(
        'Failed to parse duaAfterPrayerShowTimes[1]: "$salahTimeRaw"',
        level: SentryLevel.warning,
        withScope: (scope) {
          scope.setTag('mosque_uuid', mosqueManager.mosque?.uuid ?? 'unknown');
          scope.setContexts('config', {
            'duaAfterPrayerShowTimes': config?.duaAfterPrayerShowTimes,
          });
        },
      );
    }

    final activeJumuaaTime = jumuaaTime ?? mosqueManager.activeJumuaaDate();
    final jumuaaEndTime = activeJumuaaTime.add(Duration(minutes: jumuaaTimeout));

    return ContinuesWorkFlowWidget(
      debug: true,
      workFlowItems: [
        /// 5m before the jumuaa start time
        /// Use NormalWorkflowScreen with interruptions disabled to prevent announcements
        WorkFlowItem(
          builder: (context, next) => NormalWorkflowScreen(disableInterruptions: true),
          duration: activeJumuaaTime.difference(now),
          skip: now.isAfter(activeJumuaaTime),
        ),

        WorkFlowItem(
          builder: (context, next) => JummuaLive(onDone: next),
          skip: now.isAfter(jumuaaEndTime),

          /// handle if user open screen during the jumuaa
          duration: now.isBefore(activeJumuaaTime) ? Duration(minutes: jumuaaTimeout) : jumuaaEndTime.difference(now),
        ),

        // salah time after jumuaa
        // Use NormalWorkflowScreen with interruptions disabled
        WorkFlowItem(
          builder: (context, next) => NormalWorkflowScreen(disableInterruptions: true),
          duration: salahTime.minutes,
          skip: now.isAfter(jumuaaEndTime.add(salahTime.minutes)),
        ),

        // azkar after salah
        WorkFlowItem(
          builder: (context, next) => AfterSalahAzkar(onDone: onDone),
          debugDuration: 2.minutes,
          skip: now.isAfter(jumuaaEndTime.add((salahTime + 2).minutes)),
        ),
      ],
    );
  }
}
