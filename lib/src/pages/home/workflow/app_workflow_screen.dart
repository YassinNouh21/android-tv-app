import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mawaqit/src/pages/home/sub_screens/DuhaTimeSubScreen.dart';
import 'package:mawaqit/src/pages/home/workflow/jumua_workflow_screen.dart';
import 'package:mawaqit/src/pages/home/workflow/normal_workflow.dart';
import 'package:mawaqit/src/pages/home/workflow/salah_workflow.dart';
import 'package:mawaqit/src/services/mixins/mosque_helpers_mixins.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:mawaqit/src/services/user_preferences_manager.dart';
import 'package:provider/provider.dart';

import '../../../helpers/AppDate.dart';
import '../../../helpers/TimeShiftManager.dart';
import '../../../services/FeatureManager.dart';
import '../widgets/workflows/repeating_workflow_widget.dart';

/// this is the main workflow of the app
/// which is responsible for showing the correct workflow [NormalWorkflowScreen] or [JumuaaWorkflowScreen] or [SalahWorkflowScreen]
class AppWorkflowScreen extends StatelessWidget {
  const AppWorkflowScreen({super.key});
  static final GlobalKey _workflowKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final mosqueManager = context.watch<MosqueManager>();
    final now = AppDateTime.now();
    final TimeShiftManager timeManager = TimeShiftManager();
    final featureManager = Provider.of<FeatureManager>(context);
    final userPrefs = context.watch<UserPreferencesManager>();

    Key? workflowKey = _workflowKey;

    if (featureManager.isFeatureEnabled("timezone_shift") &&
        timeManager.deviceModel == "MAWABOX" &&
        timeManager.isLauncherInstalled) {
      workflowKey = ValueKey('workflow_${timeManager.shift}_${timeManager.shiftInMinutes}');
    }
    final times =
        mosqueManager.useTomorrowTimes ? mosqueManager.actualTimes(now.add(1.days)) : mosqueManager.actualTimes(now);

    final iqama = mosqueManager.useTomorrowTimes
        ? mosqueManager.actualIqamaTimes(now.add(1.days))
        : mosqueManager.actualIqamaTimes(now);

    final hijri = mosqueManager.mosqueHijriDate(userPrefs.hijriAdjustments);
    final shuruqTime = mosqueManager.times?.shuruq(now);

    return RepeatingWorkFlowWidget(
      key: workflowKey,
      debugName: "App workflow",
      child: NormalWorkflowScreen(),
      items: [
        ...times.mapIndexed(
          (index, elem) => RepeatingWorkflowItem(
            debugName: 'SalahWorkflowScreen $index',
            builder: (context, next) => SalahWorkflowScreen(salahIndex: index, onDone: next),
            repeatingDuration: 1.days,
            dateTime: hijri.islamicMonth == 8 ? elem.add(-2.minutes) : elem,

            /// auto start Workflow if user starts the app during the Salah time
            /// give 4 minute for the salah and 2 for azkar
            showInitial: () =>
                now.isAfter(hijri.islamicMonth == 8 ? elem.add(-2.minutes) : elem) &&
                now.isBefore(iqama[index].add(6.minutes)),

            // disable Duhr if it's Friday
            disabled: index == 1 && now.weekday == DateTime.friday,
          ),
        ),

        // Duha Workflow — 30s announcement triggered after 25-min countdown
        // (countdown is now shown inline in SalahInWidget under the clock)
        RepeatingWorkflowItem(
          debugName: 'DuhaWorkflowScreen',
          builder: (context, next) => DuhaTimeSubScreen(onDone: next),
          repeatingDuration: 1.days,
          dateTime: shuruqTime?.add(kDuhaDurationAfterShuruq),
          disabled: shuruqTime == null,
          showInitial: () {
            if (shuruqTime == null) return false;
            final currentTime = mosqueManager.mosqueDate();
            final duhaAnnouncementStart = shuruqTime.add(kDuhaDurationAfterShuruq);
            final duhaAnnouncementEnd = duhaAnnouncementStart.add(const Duration(seconds: 30));
            return currentTime.isAfter(duhaAnnouncementStart) && currentTime.isBefore(duhaAnnouncementEnd);
          },
        ),

        // Jumuaa Workflow — one item per Jumua session (mosques may have up to 3)
        ...mosqueManager.allJumuaaDates().mapIndexed(
          (index, jumuaaDate) => RepeatingWorkflowItem(
            debugName: 'JumuaaWorkflowScreen ${index + 1}',
            builder: (context, next) => JumuaaWorkflowScreen(onDone: next, jumuaaTime: jumuaaDate),
            repeatingDuration: 7.days,
            dateTime: jumuaaDate,
            showInitial: () {
              if (now.isBefore(jumuaaDate)) return false;
              final timeout = mosqueManager.mosqueConfig?.jumuaTimeout ?? 30;
              return now.isBefore(jumuaaDate.add(Duration(minutes: timeout)));
            },
          ),
        ),
      ],
    );
  }
}
