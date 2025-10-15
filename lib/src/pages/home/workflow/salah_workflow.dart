import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mawaqit/src/const/constants.dart';
import 'package:mawaqit/src/models/calendar/MawaqitHijriCalendar.dart';
import 'package:mawaqit/src/pages/home/sub_screens/AfterAdhanHadithSubScreen.dart';
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
import 'package:mawaqit/src/state_management/prayer_audio/prayer_audio_notifier.dart';
import 'package:provider/provider.dart';

import '../sub_screens/AdhanSubScreen.dart';
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
  List<WorkFlowItem>? _workFlowItems;

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
          duration: 90.seconds,
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

    if (_workFlowItems == null) {
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

      _workFlowItems = [
        WorkFlowItem(
          duration: mosqueManger.nextSalahAfter(),
          skip: mosqueManger.nextSalahAfter() > Duration(minutes: 6),
          builder: (context, next) => beforeSalahTime(mosqueManger, currentSalah, hijri),
        ),
        WorkFlowItem(
          builder: (context, next) => AdhanSubScreen(onDone: next),
          skip: () {
            final audioState = ref.read(prayerAudioProvider);
            final adhanDuration = audioState.duration ?? Duration(seconds: 150);
            return now.isAfter(currentSalahTime.add(adhanDuration));
          }(),
        ),
        WorkFlowItem(
          builder: (context, next) => AfterAdhanSubScreen(onDone: next),
          disabled: mosqueConfig.duaAfterAzanEnabled == false,
        ),
        WorkFlowItem(
          builder: (context, next) => DuaaBetweenAdhanAndIqamaaScreen(
            onDone: next,
          ),
          disabled: mosqueConfig.duaAfterAzanEnabled == false,
          skip: true,
        ),
        WorkFlowItem(
          builder: (context, next) =>
              IqamaaCountDownSubScreen(onDone: next, currentSalahIndex: currentSalah, iqamaTime: currentIqamaTime),
          skip: now.isAfter(currentIqamaTime),
          disabled: mosqueManger.mosqueConfig?.iqamaEnabled == false,
        ),
        WorkFlowItem(
          builder: (context, next) => IqamaSubScreen(),
          duration: Duration(seconds: mosqueConfig.iqamaDisplayTime ?? 30),
          skip: now.isAfter(iqamaEndTime),
          disabled: mosqueManger.mosqueConfig?.iqamaEnabled == false,
        ),
        WorkFlowItem(
          builder: (context, next) =>
              mosqueConfig.blackScreenWhenPraying == true ? Container(color: Colors.black) : NormalHomeSubScreen(),
          skip: now.isAfter(salahEndTime),
          duration: mosqueManger.currentSalahDuration,
          disabled: mosqueConfig.iqamaEnabled == false,
        ),
        WorkFlowItem(
          builder: (context, next) => AfterSalahAzkar(onDone: next),
          disabled: mosqueConfig.iqamaEnabled == false,
        ),
        WorkFlowItem(
          duration: kAzkarDuration,
          builder: (context, next) => AfterSalahAzkar(
            isAfterAsrOrFajr: true,
            isAfterAsr: isAsrPray,
            azkarTitle: isFajrPray ? AzkarConstant.kAzkarSabahAfterPrayer : AzkarConstant.kAzkarAsrAfterPrayer,
          ),
          disabled: mosqueConfig.iqamaEnabled == false || (!isFajrPray && !isAsrPray),
        ),
      ];
    }

    return ContinuesWorkFlowWidget(
      onDone: widget.onDone,
      workFlowItems: _workFlowItems!,
    );
  }
}
