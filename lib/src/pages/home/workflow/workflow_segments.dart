import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mawaqit/src/pages/home/sub_screens/AdhanSubScreen.dart';
import 'package:mawaqit/src/pages/home/sub_screens/AfterAdhanHadithSubScreen.dart';
import 'package:mawaqit/src/pages/home/widgets/workflows/WorkFlowWidget.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:mawaqit/src/state_management/prayer_audio/prayer_audio_notifier.dart';

/// Shared adhan + duaa-after-adhan workflow segment.
///
/// Used by both `SalahWorkflowScreen` and `JumuaaWorkflowScreen` so the two
/// workflows can't drift — any tweak to adhan/duaa progression lands here once.
///
/// - [adhanTime] is when the adhan starts (the prayer time, or the jumuaa time).
/// - The adhan item self-terminates after [adhanTime] + its duration:
///   [MosqueConfig.adhanDuration] for mosque accounts when set, otherwise the
///   loaded adhan audio duration, falling back to 150s.
/// - The duaa item self-terminates via its sub-screen's `onDone`; it has no
///   `skip`, so progression is driven by the sub-screen rather than a
///   hardcoded cutoff.
List<WorkFlowItem> adhanAndDuaaSegment({
  required MosqueManager mosque,
  required WidgetRef ref,
  required DateTime adhanTime,
  required DateTime now,
}) {
  final mosqueConfig = mosque.mosqueConfig!;
  return [
    WorkFlowItem(
      builder: (context, next) => AdhanSubScreen(onDone: next),
      skip: () {
        final adhanDuration = mosque.typeIsMosque && mosqueConfig.adhanDuration != null
            ? Duration(seconds: mosqueConfig.adhanDuration!)
            : ref.read(prayerAudioProvider).duration ?? const Duration(seconds: 150);
        return now.isAfter(adhanTime.add(adhanDuration));
      }(),
    ),
    WorkFlowItem(
      builder: (context, next) => AfterAdhanSubScreen(onDone: next),
      disabled: mosqueConfig.duaAfterAzanEnabled == false,
    ),
  ];
}
